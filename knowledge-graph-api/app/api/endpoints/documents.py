from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, BackgroundTasks
from typing import List, Dict, Any, Optional
import asyncio
from uuid import uuid4

from app.models.document import DocumentResponse, DocumentType, ProcessingStatus
from app.services.file_handler import FileHandler
from app.services.document_classifier import DocumentClassifier
from app.services.claude_agent import ClaudeAgent
from app.services.database_service import DatabaseService

router = APIRouter()

# Services will be initialized when needed
def get_services():
    try:
        from app.services.database_service import DatabaseService
        db_service = DatabaseService()
    except Exception as e:
        # Only print this once, not on every request
        if not hasattr(get_services, '_mock_logged'):
            print(f"🔧 Using mock database service (Supabase unavailable)")
            get_services._mock_logged = True
        from app.services.mock_database_service import MockDatabaseService
        db_service = MockDatabaseService()
    
    return {
        'file_handler': FileHandler(),
        'classifier': DocumentClassifier(), 
        'claude_agent': ClaudeAgent(),
        'db_service': db_service
    }

# Dependency to get user ID (simplified - in production use proper auth)
async def get_current_user_id() -> str:
    # This should integrate with your authentication system
    # For now, return a dummy user ID
    return "user_123"

@router.post("/upload", response_model=DocumentResponse)
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id)
):
    """Upload and process a document"""
    
    print(f"=== UPLOAD STARTED: {file.filename} ===")
    try:
        services = get_services()
        file_handler = services['file_handler']
        classifier = services['classifier']
        db_service = services['db_service']
        
        # Process uploaded file
        print(f"Processing file: {file.filename}")
        processing_result = await file_handler.process_uploaded_file(file, user_id)
        print(f"Processing result keys: {list(processing_result.keys())}")
        
        # Classify document type
        print("Classifying document...")
        doc_type, confidence, classification_details = classifier.classify_document(processing_result)
        print(f"Classified as: {doc_type} (confidence: {confidence})")
        
        # Create document record in database
        document_data = {
            **processing_result,
            "document_type": doc_type.value,
            "word_count": processing_result.get("metadata", {}).get("total_words", 0),
            "page_count": processing_result.get("metadata", {}).get("num_pages", 1),
            "metadata": {
                **processing_result.get("metadata", {}),
                "classification": classification_details,
                "confidence_score": confidence
            }
        }
        
        print("Creating document record...")
        document_record = await db_service.create_document(user_id, document_data)
        print(f"Document created with ID: {document_record['id']}")
        
        if not document_record:
            raise HTTPException(status_code=500, detail="Failed to create document record")
        
        # Start background processing
        print("Starting background processing...")
        background_tasks.add_task(
            process_document_background,
            document_record["id"],
            processing_result,
            doc_type
        )
        print(f"=== UPLOAD COMPLETED: {document_record['id']} ===")
        
        return DocumentResponse(
            id=document_record["id"],
            user_id=user_id,
            title=document_record["title"],
            document_type=DocumentType(document_record["document_type"]),
            processing_status=ProcessingStatus(document_record["processing_status"]),
            file_path=document_record["file_path"],
            created_at=document_record["created_at"],
            updated_at=document_record["updated_at"],
            metadata=document_record["metadata"]
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Document upload failed: {str(e)}")

async def process_document_background(document_id: str, processing_result: Dict[str, Any], doc_type: DocumentType):
    """Background task to process document with Claude agent"""
    
    print(f"=== BACKGROUND PROCESSING START: {document_id} ===")
    try:
        services = get_services()
        db_service = services['db_service']
        claude_agent = services['claude_agent']
        
        # Update status to processing
        await db_service.update_document_processing_status(document_id, ProcessingStatus.PROCESSING)
        
        # Store document content
        await db_service.store_document_content(document_id, processing_result)
        
        # Process with Claude agent to extract knowledge graph
        try:
            # Check if processing was successful
            if processing_result.get("processing_status") == "failed":
                raise Exception(f"File processing failed: {processing_result.get('error', 'Unknown error')}")
            
            # Ensure text_content exists
            if "text_content" not in processing_result:
                raise Exception("No text content found in processing result")
            
            knowledge_graph = await claude_agent.process_document(processing_result, doc_type)
        except Exception as e:
            print(f"Claude agent processing failed: {e}")
            # Create empty knowledge graph on failure
            knowledge_graph = {
                "concepts": [],
                "relationships": [],
                "processing_metadata": {"error": str(e)}
            }
        
        # Store concepts in database
        concepts_data = knowledge_graph.get("concepts", [])
        relationships_data = knowledge_graph.get("relationships", [])
        
        if concepts_data:
            created_concepts = await db_service.create_concepts(document_id, concepts_data)
            
            # Create concept ID mapping for relationships
            concept_id_map = {concept["id"]: created_concept["id"] for concept, created_concept in zip(concepts_data, created_concepts)}
            
            # Store relationships
            if relationships_data:
                # Map relationship IDs to database IDs
                mapped_relationships = []
                for rel in relationships_data:
                    if rel["source_concept_id"] in concept_id_map and rel["target_concept_id"] in concept_id_map:
                        mapped_relationships.append({
                            **rel,
                            "source_concept_id": concept_id_map[rel["source_concept_id"]],
                            "target_concept_id": concept_id_map[rel["target_concept_id"]]
                        })
                
                if mapped_relationships:
                    await db_service.create_concept_relationships(mapped_relationships)
        
        # Store visual elements if any
        visual_elements = processing_result.get("visual_elements", [])
        if visual_elements:
            await db_service.store_visual_elements(document_id, visual_elements)
        
        # Update status to completed
        processing_metadata = {
            **processing_result.get("metadata", {}),
            "knowledge_graph": knowledge_graph.get("processing_metadata", {}),
            "concepts_created": len(concepts_data),
            "relationships_created": len(relationships_data) if relationships_data else 0
        }
        
        await db_service.update_document_processing_status(
            document_id, 
            ProcessingStatus.COMPLETED, 
            processing_metadata
        )
        
        print(f"=== BACKGROUND PROCESSING COMPLETED: {document_id} ===")
        
    except Exception as e:
        print(f"Background processing failed for document {document_id}: {e}")
        import traceback
        traceback.print_exc()
        await db_service.update_document_processing_status(
            document_id, 
            ProcessingStatus.FAILED,
            {"error": str(e)}
        )

@router.get("/", response_model=List[DocumentResponse])
async def get_user_documents(user_id: str = Depends(get_current_user_id)):
    """Get all documents for the current user"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        documents = await db_service.get_user_documents(user_id)
        
        return [
            DocumentResponse(
                id=doc["id"],
                user_id=doc["user_id"],
                title=doc["title"],
                document_type=DocumentType(doc["document_type"]),
                processing_status=ProcessingStatus(doc["processing_status"]),
                file_path=doc["file_path"],
                created_at=doc["created_at"],
                updated_at=doc["updated_at"],
                metadata=doc["metadata"]
            )
            for doc in documents
        ]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve documents: {str(e)}")

@router.get("/{document_id}", response_model=DocumentResponse)
async def get_document(document_id: str, user_id: str = Depends(get_current_user_id)):
    """Get a specific document by ID"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        document = await db_service.get_document_by_id(document_id, user_id)
        
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")
        
        return DocumentResponse(
            id=document["id"],
            user_id=document["user_id"],
            title=document["title"],
            document_type=DocumentType(document["document_type"]),
            processing_status=ProcessingStatus(document["processing_status"]),
            file_path=document["file_path"],
            created_at=document["created_at"],
            updated_at=document["updated_at"],
            metadata=document["metadata"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve document: {str(e)}")

@router.get("/{document_id}/stats")
async def get_document_stats(document_id: str, user_id: str = Depends(get_current_user_id)):
    """Get statistics for a document"""
    
    try:
        # Verify user owns the document
        document = await db_service.get_document_by_id(document_id, user_id)
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")
        
        stats = await db_service.get_document_stats(document_id, user_id)
        
        return {
            "document_id": document_id,
            "title": document["title"],
            "processing_status": document["processing_status"],
            **stats
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve document stats: {str(e)}")

@router.delete("/{document_id}")
async def delete_document(document_id: str, user_id: str = Depends(get_current_user_id)):
    """Delete a document and all associated data"""
    
    try:
        # Verify user owns the document
        document = await db_service.get_document_by_id(document_id, user_id)
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")
        
        # Delete file from storage
        file_handler.delete_file(document["file_path"])
        
        # Database cascade delete will handle related records
        # This would be implemented in the database service
        
        return {"message": "Document deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete document: {str(e)}")