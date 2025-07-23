from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List, Dict, Any, Optional
from pydantic import BaseModel

from app.models.document import ConceptNode, ConceptRelationship
from app.services.database_service import DatabaseService

router = APIRouter()

def get_db_service():
    try:
        from app.services.database_service import DatabaseService
        return DatabaseService()
    except Exception as e:
        if not hasattr(get_db_service, '_mock_logged'):
            get_db_service._mock_logged = True
        from app.services.mock_database_service import MockDatabaseService
        return MockDatabaseService()

# Dependency to get user ID (simplified - in production use proper auth)
async def get_current_user_id() -> str:
    return "user_123"

class ConceptResponse(BaseModel):
    id: str
    title: str
    content: str
    concept_type: str
    importance_score: float
    difficulty_level: int
    document_id: str
    section_title: Optional[str] = None
    tags: List[str] = []
    metadata: Dict[str, Any] = {}

class RelationshipResponse(BaseModel):
    id: str
    source_concept_id: str
    target_concept_id: str
    relationship_type: str
    strength: float
    source_concept_title: Optional[str] = None
    target_concept_title: Optional[str] = None

class KnowledgeGraphResponse(BaseModel):
    concepts: List[ConceptResponse]
    relationships: List[RelationshipResponse]
    stats: Dict[str, Any]

@router.get("/documents/{document_id}/concepts", response_model=List[ConceptResponse])
async def get_document_concepts(
    document_id: str,
    concept_type: Optional[str] = Query(None, description="Filter by concept type"),
    min_importance: Optional[float] = Query(None, description="Minimum importance score"),
    user_id: str = Depends(get_current_user_id)
):
    """Get all concepts for a document"""
    
    try:
        db_service = get_db_service()
        concepts = await db_service.get_document_concepts(document_id, user_id)
        
        # Apply filters
        if concept_type:
            concepts = [c for c in concepts if c["concept_type"] == concept_type]
        
        if min_importance is not None:
            concepts = [c for c in concepts if c["importance_score"] >= min_importance]
        
        return [
            ConceptResponse(
                id=concept["id"],
                title=concept["title"],
                content=concept["content"],
                concept_type=concept["concept_type"],
                importance_score=concept["importance_score"],
                difficulty_level=concept["difficulty_level"],
                document_id=concept["document_id"],
                section_title=concept.get("section_title"),
                tags=concept.get("tags", []),
                metadata=concept.get("metadata", {})
            )
            for concept in concepts
        ]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve concepts: {str(e)}")

@router.get("/concepts/{concept_id}/related", response_model=List[ConceptResponse])
async def get_related_concepts(
    concept_id: str,
    relationship_types: Optional[List[str]] = Query(None, description="Filter by relationship types"),
    max_results: int = Query(10, description="Maximum number of results"),
    user_id: str = Depends(get_current_user_id)
):
    """Get concepts related to a specific concept"""
    
    try:
        db_service = get_db_service()
        related_concepts = await db_service.get_related_concepts(concept_id, relationship_types)
        
        # Limit results
        limited_concepts = related_concepts[:max_results]
        
        return [
            ConceptResponse(
                id=concept["id"],
                title=concept["title"],
                content=concept["content"],
                concept_type=concept["concept_type"],
                importance_score=0.5,  # Default since not in related query
                difficulty_level=3,    # Default since not in related query
                document_id="",        # Would need to be joined
                tags=[]
            )
            for concept in limited_concepts
        ]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve related concepts: {str(e)}")

@router.get("/search", response_model=List[ConceptResponse])
async def search_concepts(
    q: str = Query(..., description="Search query"),
    limit: int = Query(20, description="Maximum number of results"),
    user_id: str = Depends(get_current_user_id)
):
    """Search concepts across all user documents"""
    
    try:
        db_service = get_db_service()
        search_results = await db_service.search_concepts(user_id, q, limit)
        
        return [
            ConceptResponse(
                id=result["id"],
                title=result["title"],
                content=result["content"],
                concept_type=result["concept_type"],
                importance_score=result["importance_score"],
                difficulty_level=3,  # Default - would need to be in search query
                document_id="",      # Would need to be joined
                tags=[]
            )
            for result in search_results
        ]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/documents/{document_id}/graph", response_model=KnowledgeGraphResponse)
async def get_document_knowledge_graph(
    document_id: str,
    include_relationships: bool = Query(True, description="Include concept relationships"),
    min_importance: Optional[float] = Query(None, description="Minimum concept importance"),
    user_id: str = Depends(get_current_user_id)
):
    """Get the complete knowledge graph for a document"""
    
    try:
        db_service = get_db_service()
        # Get concepts
        concepts = await db_service.get_document_concepts(document_id, user_id)
        
        # Apply importance filter
        if min_importance is not None:
            concepts = [c for c in concepts if c["importance_score"] >= min_importance]
        
        concept_responses = [
            ConceptResponse(
                id=concept["id"],
                title=concept["title"],
                content=concept["content"],
                concept_type=concept["concept_type"],
                importance_score=concept["importance_score"],
                difficulty_level=concept["difficulty_level"],
                document_id=concept["document_id"],
                section_title=concept.get("section_title"),
                tags=concept.get("tags", []),
                metadata=concept.get("metadata", {})
            )
            for concept in concepts
        ]
        
        relationships = []
        if include_relationships and concepts:
            # Get relationships between concepts
            concept_ids = [c["id"] for c in concepts]
            
            # This would require a more complex query to get relationships
            # between concepts in the current document
            # For now, return empty relationships
            relationships = []
        
        # Calculate stats
        stats = {
            "total_concepts": len(concepts),
            "concept_types": len(set(c["concept_type"] for c in concepts)),
            "avg_importance": sum(c["importance_score"] for c in concepts) / max(len(concepts), 1),
            "difficulty_distribution": {
                str(i): len([c for c in concepts if c["difficulty_level"] == i])
                for i in range(1, 6)
            }
        }
        
        return KnowledgeGraphResponse(
            concepts=concept_responses,
            relationships=relationships,
            stats=stats
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve knowledge graph: {str(e)}")

@router.get("/concepts/{concept_id}")
async def get_concept_details(
    concept_id: str,
    include_related: bool = Query(False, description="Include related concepts"),
    user_id: str = Depends(get_current_user_id)
):
    """Get detailed information about a specific concept"""
    
    try:
        # This would require a service method to get single concept
        # For now, implement basic version
        
        related_concepts = []
        if include_related:
            db_service = get_db_service()
            related_concepts = await db_service.get_related_concepts(concept_id)
        
        return {
            "concept_id": concept_id,
            "related_concepts": related_concepts[:5],  # Limit to 5
            "message": "Concept details endpoint - to be implemented"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve concept details: {str(e)}")

@router.get("/stats")
async def get_user_knowledge_graph_stats(user_id: str = Depends(get_current_user_id)):
    """Get overall knowledge graph statistics for the user"""
    
    try:
        db_service = get_db_service()
        stats = await db_service.get_user_knowledge_graph_stats(user_id)
        
        return {
            "user_id": user_id,
            **stats
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve stats: {str(e)}")

@router.get("/concepts/by-type/{concept_type}")
async def get_concepts_by_type(
    concept_type: str,
    limit: int = Query(50, description="Maximum number of results"),
    user_id: str = Depends(get_current_user_id)
):
    """Get all concepts of a specific type across user's documents"""
    
    try:
        # This would require a database service method
        # For now return placeholder
        
        return {
            "concept_type": concept_type,
            "concepts": [],
            "message": "Concepts by type endpoint - to be implemented"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve concepts by type: {str(e)}")

@router.get("/explore")
async def explore_knowledge_graph(
    start_concept_id: Optional[str] = Query(None, description="Starting concept for exploration"),
    max_depth: int = Query(2, description="Maximum relationship depth"),
    user_id: str = Depends(get_current_user_id)
):
    """Explore the knowledge graph starting from a concept or randomly"""
    
    try:
        if start_concept_id:
            # Start exploration from specific concept
            exploration_result = {
                "start_concept_id": start_concept_id,
                "max_depth": max_depth,
                "exploration_path": [],
                "message": "Knowledge graph exploration - to be implemented"
            }
        else:
            # Random exploration
            exploration_result = {
                "random_exploration": True,
                "suggested_concepts": [],
                "message": "Random knowledge graph exploration - to be implemented"
            }
        
        return exploration_result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Knowledge graph exploration failed: {str(e)}")