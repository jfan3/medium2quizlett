from enum import Enum
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from datetime import datetime

class DocumentType(str, Enum):
    TEXTBOOK = "textbook"
    PAPER = "paper"
    SHORT_TEXT = "short_text"
    TECH_BLOG = "tech_blog"
    AI_GENERATED_REPORT = "ai_generated_report"
    UNKNOWN = "unknown"

class ProcessingStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class DocumentUpload(BaseModel):
    file_name: str
    content_type: str
    size: int

class DocumentResponse(BaseModel):
    id: str
    user_id: str
    title: str
    document_type: DocumentType
    processing_status: ProcessingStatus
    file_path: str
    created_at: datetime
    updated_at: datetime
    metadata: Optional[Dict[str, Any]] = None

class ConceptNode(BaseModel):
    id: str
    title: str
    content: str
    document_id: str
    concept_type: str  # definition, example, theorem, etc.
    importance_score: float
    position_in_doc: Optional[int] = None
    page_number: Optional[int] = None
    image_url: Optional[str] = None

class ConceptRelationship(BaseModel):
    source_concept_id: str
    target_concept_id: str
    relationship_type: str  # prerequisite, related, example_of, etc.
    strength: float

class KnowledgeGraph(BaseModel):
    document_id: str
    concepts: List[ConceptNode]
    relationships: List[ConceptRelationship]

class StudyCard(BaseModel):
    id: str
    concept_id: str
    content: str
    card_type: str  # concept, definition, example
    difficulty: int  # 1-5
    image_url: Optional[str] = None