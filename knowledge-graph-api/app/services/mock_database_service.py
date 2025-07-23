"""
Mock database service for development/testing when Supabase is not available
"""
from typing import List, Dict, Any, Optional
from uuid import uuid4
from datetime import datetime

class MockDatabaseService:
    """Mock database service that returns dummy data"""
    
    # Class-level storage to persist across instances
    _documents = []
    _concepts = []
    _relationships = []
    _study_cards = []
    _user_progress = []
    _study_sessions = []
    
    def __init__(self):
        # Use class-level storage for persistence
        self.documents = MockDatabaseService._documents
        self.concepts = MockDatabaseService._concepts
        self.relationships = MockDatabaseService._relationships
        self.study_cards = MockDatabaseService._study_cards
        self.user_progress = MockDatabaseService._user_progress
        self.study_sessions = MockDatabaseService._study_sessions
    
    async def create_document(self, user_id: str, document_data: Dict[str, Any]) -> Dict[str, Any]:
        document = {
            "id": str(uuid4()),
            "user_id": user_id,
            "title": document_data.get("title", "Test Document"),
            "original_filename": document_data.get("original_filename", "test.pdf"),
            "file_path": document_data.get("file_path", "/tmp/test.pdf"),
            "file_size": document_data.get("file_size", 1000),
            "content_type": document_data.get("content_type", "application/pdf"),
            "document_type": document_data.get("document_type", "unknown"),
            "processing_status": "processing",
            "word_count": document_data.get("word_count", 100),
            "page_count": document_data.get("page_count", 1),
            "metadata": document_data.get("metadata", {}),
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        self.documents.append(document)
        return document
    
    async def update_document_processing_status(self, document_id: str, status: str, metadata: Optional[Dict] = None):
        for doc in self.documents:
            if doc["id"] == document_id:
                doc["processing_status"] = status
                doc["updated_at"] = datetime.utcnow().isoformat()
                if metadata:
                    doc["metadata"].update(metadata)
                break
    
    async def store_document_content(self, document_id: str, content_data: Dict[str, Any]):
        return {"id": str(uuid4()), "document_id": document_id}
    
    async def get_user_documents(self, user_id: str) -> List[Dict[str, Any]]:
        return [doc for doc in self.documents if doc["user_id"] == user_id]
    
    async def get_document_by_id(self, document_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        for doc in self.documents:
            if doc["id"] == document_id and doc["user_id"] == user_id:
                return doc
        return None
    
    async def create_concepts(self, document_id: str, concepts_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        created_concepts = []
        for concept in concepts_data:
            concept_record = {
                "id": str(uuid4()),
                "document_id": document_id,
                "title": concept["title"],
                "content": concept["content"],
                "concept_type": concept.get("concept_type", "general"),
                "importance_score": concept.get("importance_score", 0.5),
                "difficulty_level": concept.get("difficulty_level", 3),
                "created_at": datetime.utcnow().isoformat()
            }
            self.concepts.append(concept_record)
            created_concepts.append(concept_record)
        return created_concepts
    
    async def create_concept_relationships(self, relationships_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        created_relationships = []
        for rel in relationships_data:
            rel_record = {
                "id": str(uuid4()),
                "source_concept_id": rel["source_concept_id"],
                "target_concept_id": rel["target_concept_id"],
                "relationship_type": rel["relationship_type"],
                "strength": rel.get("strength", 0.5),
                "created_at": datetime.utcnow().isoformat()
            }
            self.relationships.append(rel_record)
            created_relationships.append(rel_record)
        return created_relationships
    
    async def get_document_concepts(self, document_id: str, user_id: str) -> List[Dict[str, Any]]:
        return [c for c in self.concepts if c["document_id"] == document_id]
    
    async def get_related_concepts(self, concept_id: str, relationship_types: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        return []
    
    async def search_concepts(self, user_id: str, search_query: str, limit: int = 20) -> List[Dict[str, Any]]:
        return []
    
    async def store_visual_elements(self, document_id: str, visual_elements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return []
    
    async def get_document_visual_elements(self, document_id: str, user_id: str) -> List[Dict[str, Any]]:
        return []
    
    async def create_study_cards(self, user_id: str, cards_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return []
    
    async def get_user_study_cards(self, user_id: str, concept_ids: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        return []
    
    async def update_user_progress(self, user_id: str, concept_id: str, progress_data: Dict[str, Any]):
        return {}
    
    async def get_user_progress(self, user_id: str, concept_ids: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        return []
    
    async def create_study_session(self, user_id: str, session_data: Dict[str, Any]) -> Dict[str, Any]:
        session = {
            "id": str(uuid4()),
            "user_id": user_id,
            "started_at": datetime.utcnow().isoformat(),
            **session_data
        }
        self.study_sessions.append(session)
        return session
    
    async def get_user_study_sessions(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        return []
    
    async def get_document_stats(self, document_id: str, user_id: str) -> Dict[str, Any]:
        return {
            "concept_count": 0,
            "relationship_count": 0,
            "visual_elements_count": 0
        }
    
    async def get_user_knowledge_graph_stats(self, user_id: str) -> Dict[str, Any]:
        return {
            "total_documents": len([d for d in self.documents if d["user_id"] == user_id]),
            "total_concepts": len(self.concepts),
            "average_mastery": 0.0,
            "concepts_studied": 0
        }