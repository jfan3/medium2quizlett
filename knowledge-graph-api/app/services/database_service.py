from typing import List, Dict, Any, Optional, Tuple
from uuid import UUID, uuid4
from datetime import datetime
from app.services.supabase_client import get_supabase_admin_client, get_supabase_client
from app.models.document import DocumentType, ProcessingStatus

class DatabaseService:
    """Service for database operations with the knowledge graph schema"""
    
    def __init__(self):
        self.admin_client = get_supabase_admin_client()
        self.client = get_supabase_client()
    
    # Document operations
    async def create_document(self, user_id: str, document_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new document record"""
        document_record = {
            "user_id": user_id,
            "title": document_data.get("title", document_data.get("original_filename", "Untitled")),
            "original_filename": document_data["original_filename"],
            "file_path": document_data["file_path"],
            "file_size": document_data["file_size"],
            "content_type": document_data["content_type"],
            "document_type": document_data.get("document_type", "unknown"),
            "processing_status": "processing",
            "word_count": document_data.get("word_count", 0),
            "page_count": document_data.get("page_count", 1),
            "metadata": document_data.get("metadata", {})
        }
        
        result = self.admin_client.table("documents").insert(document_record).execute()
        return result.data[0] if result.data else None
    
    async def update_document_processing_status(self, document_id: str, status: ProcessingStatus, metadata: Optional[Dict] = None):
        """Update document processing status"""
        update_data = {"processing_status": status, "updated_at": datetime.utcnow().isoformat()}
        if metadata:
            update_data["metadata"] = metadata
        
        self.admin_client.table("documents").update(update_data).eq("id", document_id).execute()
    
    async def store_document_content(self, document_id: str, content_data: Dict[str, Any]):
        """Store document content and processing details"""
        content_record = {
            "document_id": document_id,
            "full_text": content_data["text_content"],
            "pages": content_data.get("pages", []),
            "processing_details": content_data.get("classification_details", {})
        }
        
        result = self.admin_client.table("document_content").insert(content_record).execute()
        return result.data[0] if result.data else None
    
    async def get_user_documents(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all documents for a user"""
        result = self.client.table("documents").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
        return result.data
    
    async def get_document_by_id(self, document_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific document by ID"""
        result = self.client.table("documents").select("*").eq("id", document_id).eq("user_id", user_id).execute()
        return result.data[0] if result.data else None
    
    # Concept operations
    async def create_concepts(self, document_id: str, concepts_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create multiple concepts for a document"""
        concept_records = []
        for concept in concepts_data:
            concept_record = {
                "document_id": document_id,
                "title": concept["title"],
                "content": concept["content"],
                "concept_type": concept.get("concept_type", "general"),
                "importance_score": concept.get("importance_score", 0.5),
                "difficulty_level": concept.get("difficulty_level", 3),
                "position_in_doc": concept.get("position_in_doc"),
                "page_number": concept.get("page_number"),
                "section_title": concept.get("section_title"),
                "tags": concept.get("tags", []),
                "metadata": concept.get("metadata", {})
            }
            concept_records.append(concept_record)
        
        result = self.admin_client.table("concepts").insert(concept_records).execute()
        return result.data
    
    async def create_concept_relationships(self, relationships_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create relationships between concepts"""
        relationship_records = []
        for rel in relationships_data:
            relationship_record = {
                "source_concept_id": rel["source_concept_id"],
                "target_concept_id": rel["target_concept_id"],
                "relationship_type": rel["relationship_type"],
                "strength": rel.get("strength", 0.5),
                "bidirectional": rel.get("bidirectional", False),
                "metadata": rel.get("metadata", {})
            }
            relationship_records.append(relationship_record)
        
        # Use upsert to handle duplicates
        result = self.admin_client.table("concept_relationships").upsert(
            relationship_records, 
            on_conflict="source_concept_id,target_concept_id,relationship_type"
        ).execute()
        return result.data
    
    async def get_document_concepts(self, document_id: str, user_id: str) -> List[Dict[str, Any]]:
        """Get all concepts for a document"""
        # Use a join to ensure user has access to the document
        result = self.client.table("concepts").select(
            "*, documents!inner(user_id)"
        ).eq("document_id", document_id).eq("documents.user_id", user_id).execute()
        return result.data
    
    async def get_related_concepts(self, concept_id: str, relationship_types: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get concepts related to a given concept"""
        # This would use the database function we created
        params = {"concept_uuid": concept_id}
        if relationship_types:
            params["relationship_types"] = relationship_types
        
        result = self.client.rpc("get_related_concepts", params).execute()
        return result.data
    
    async def search_concepts(self, user_id: str, search_query: str, limit: int = 20) -> List[Dict[str, Any]]:
        """Search concepts for a user"""
        result = self.client.rpc("search_concepts", {
            "search_query": search_query,
            "user_uuid": user_id,
            "limit_count": limit
        }).execute()
        return result.data
    
    # Visual elements operations
    async def store_visual_elements(self, document_id: str, visual_elements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Store visual elements extracted from document"""
        visual_records = []
        for element in visual_elements:
            visual_record = {
                "document_id": document_id,
                "element_type": element.get("element_type", "image"),
                "page_number": element["page_number"],
                "image_base64": element.get("image_base64"),
                "description": element.get("description"),
                "importance_score": element.get("importance_score", 0.5),
                "metadata": element.get("metadata", {})
            }
            visual_records.append(visual_record)
        
        result = self.admin_client.table("visual_elements").insert(visual_records).execute()
        return result.data
    
    async def get_document_visual_elements(self, document_id: str, user_id: str) -> List[Dict[str, Any]]:
        """Get visual elements for a document"""
        result = self.client.table("visual_elements").select(
            "*, documents!inner(user_id)"
        ).eq("document_id", document_id).eq("documents.user_id", user_id).execute()
        return result.data
    
    # Study cards operations
    async def create_study_cards(self, user_id: str, cards_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create study cards for concepts"""
        card_records = []
        for card in cards_data:
            card_record = {
                "concept_id": card["concept_id"],
                "user_id": user_id,
                "card_type": card.get("card_type", "flashcard"),
                "front_content": card["front_content"],
                "back_content": card.get("back_content", ""),
                "difficulty": card.get("difficulty", 3),
                "image_url": card.get("image_url"),
                "tags": card.get("tags", []),
                "metadata": card.get("metadata", {})
            }
            card_records.append(card_record)
        
        result = self.admin_client.table("study_cards").insert(card_records).execute()
        return result.data
    
    async def get_user_study_cards(self, user_id: str, concept_ids: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get study cards for a user, optionally filtered by concept IDs"""
        query = self.client.table("study_cards").select("*, concepts(title, concept_type)").eq("user_id", user_id)
        
        if concept_ids:
            query = query.in_("concept_id", concept_ids)
        
        result = query.execute()
        return result.data
    
    # User progress operations
    async def update_user_progress(self, user_id: str, concept_id: str, progress_data: Dict[str, Any]):
        """Update or create user progress for a concept"""
        progress_record = {
            "user_id": user_id,
            "concept_id": concept_id,
            "mastery_level": progress_data.get("mastery_level", 0),
            "times_studied": progress_data.get("times_studied", 0),
            "times_correct": progress_data.get("times_correct", 0),
            "last_studied_at": progress_data.get("last_studied_at", datetime.utcnow().isoformat()),
            "next_review_at": progress_data.get("next_review_at"),
            "study_streak": progress_data.get("study_streak", 0),
            "metadata": progress_data.get("metadata", {}),
            "updated_at": datetime.utcnow().isoformat()
        }
        
        # Upsert to handle existing progress
        result = self.admin_client.table("user_progress").upsert(
            progress_record, 
            on_conflict="user_id,concept_id"
        ).execute()
        return result.data[0] if result.data else None
    
    async def get_user_progress(self, user_id: str, concept_ids: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get user progress, optionally filtered by concept IDs"""
        query = self.client.table("user_progress").select("*, concepts(title, concept_type)").eq("user_id", user_id)
        
        if concept_ids:
            query = query.in_("concept_id", concept_ids)
        
        result = query.execute()
        return result.data
    
    # Study session operations
    async def create_study_session(self, user_id: str, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new study session"""
        session_record = {
            "user_id": user_id,
            "document_id": session_data.get("document_id"),
            "session_type": session_data.get("session_type", "review"),
            "concepts_studied": session_data.get("concepts_studied", []),
            "duration_minutes": session_data.get("duration_minutes", 0),
            "cards_completed": session_data.get("cards_completed", 0),
            "accuracy_rate": session_data.get("accuracy_rate", 0),
            "session_data": session_data.get("session_data", {}),
            "started_at": session_data.get("started_at", datetime.utcnow().isoformat()),
            "ended_at": session_data.get("ended_at")
        }
        
        result = self.admin_client.table("study_sessions").insert(session_record).execute()
        return result.data[0] if result.data else None
    
    async def get_user_study_sessions(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent study sessions for a user"""
        result = self.client.table("study_sessions").select("*").eq("user_id", user_id).order("started_at", desc=True).limit(limit).execute()
        return result.data
    
    # Analytics and stats
    async def get_document_stats(self, document_id: str, user_id: str) -> Dict[str, Any]:
        """Get statistics for a document"""
        # Get concept count
        concept_result = self.client.table("concepts").select("id", count="exact").eq("document_id", document_id).execute()
        concept_count = concept_result.count or 0
        
        # Get relationship count
        relationship_result = self.client.table("concept_relationships").select(
            "id", count="exact"
        ).in_("source_concept_id", 
            [c["id"] for c in (self.client.table("concepts").select("id").eq("document_id", document_id).execute().data or [])]
        ).execute()
        relationship_count = relationship_result.count or 0
        
        # Get visual elements count
        visual_result = self.client.table("visual_elements").select("id", count="exact").eq("document_id", document_id).execute()
        visual_count = visual_result.count or 0
        
        return {
            "concept_count": concept_count,
            "relationship_count": relationship_count,
            "visual_elements_count": visual_count
        }
    
    async def get_user_knowledge_graph_stats(self, user_id: str) -> Dict[str, Any]:
        """Get overall knowledge graph statistics for a user"""
        # Get total documents
        doc_result = self.client.table("documents").select("id", count="exact").eq("user_id", user_id).execute()
        document_count = doc_result.count or 0
        
        # Get total concepts across all user documents
        concept_result = self.client.table("concepts").select(
            "id", count="exact"
        ).in_("document_id", 
            [d["id"] for d in (self.client.table("documents").select("id").eq("user_id", user_id).execute().data or [])]
        ).execute()
        total_concepts = concept_result.count or 0
        
        # Get study progress
        progress_result = self.client.table("user_progress").select("mastery_level").eq("user_id", user_id).execute()
        progress_data = progress_result.data or []
        
        avg_mastery = sum(p["mastery_level"] for p in progress_data) / max(len(progress_data), 1)
        
        return {
            "total_documents": document_count,
            "total_concepts": total_concepts,
            "average_mastery": avg_mastery,
            "concepts_studied": len(progress_data)
        }