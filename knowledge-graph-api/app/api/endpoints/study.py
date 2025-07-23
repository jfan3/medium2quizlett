from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from datetime import datetime

from app.models.document import StudyCard
from app.services.database_service import DatabaseService
from app.services.study_card_generator import StudyCardGenerator

router = APIRouter()

def get_services():
    try:
        from app.services.database_service import DatabaseService
        db_service = DatabaseService()
    except Exception as e:
        if not hasattr(get_services, '_mock_logged'):
            get_services._mock_logged = True
        from app.services.mock_database_service import MockDatabaseService
        db_service = MockDatabaseService()
    
    return {
        'db_service': db_service,
        'study_generator': StudyCardGenerator()
    }

# Dependency to get user ID (simplified - in production use proper auth)
async def get_current_user_id() -> str:
    return "user_123"

class StudyCardResponse(BaseModel):
    id: str
    concept_id: str
    concept_title: str
    card_type: str
    front_content: str
    back_content: Optional[str] = None
    difficulty: int
    image_url: Optional[str] = None
    tags: List[str] = []
    metadata: Dict[str, Any] = {}

class StudySessionRequest(BaseModel):
    document_id: Optional[str] = None
    concept_ids: Optional[List[str]] = None
    session_type: str = "review"  # review, learn, test, browse
    max_cards: int = 20

class StudySessionResponse(BaseModel):
    session_id: str
    cards: List[StudyCardResponse]
    session_metadata: Dict[str, Any]

class StudyProgressRequest(BaseModel):
    concept_id: str
    mastery_level: float
    times_studied: int
    times_correct: int
    session_duration_minutes: int

@router.post("/sessions", response_model=StudySessionResponse)
async def create_study_session(
    session_request: StudySessionRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Create a new study session with generated cards"""
    
    try:
        services = get_services()
        study_generator = services['study_generator']
        db_service = services['db_service']
        
        # Generate study cards based on request
        if session_request.document_id:
            # Study cards for specific document
            cards = await study_generator.generate_document_study_cards(
                session_request.document_id,
                user_id,
                session_request.max_cards,
                session_request.session_type
            )
        elif session_request.concept_ids:
            # Study cards for specific concepts
            cards = await study_generator.generate_concept_study_cards(
                session_request.concept_ids,
                user_id,
                session_request.session_type
            )
        else:
            # General review session
            cards = await study_generator.generate_review_session(
                user_id,
                session_request.max_cards
            )
        
        # Create study session record
        session_data = {
            "document_id": session_request.document_id,
            "session_type": session_request.session_type,
            "concepts_studied": [card["concept_id"] for card in cards],
            "cards_completed": 0,
            "session_data": {
                "max_cards": session_request.max_cards,
                "card_types": [card["card_type"] for card in cards]
            }
        }
        
        session_record = await db_service.create_study_session(user_id, session_data)
        
        # Convert to response format
        card_responses = [
            StudyCardResponse(
                id=card.get("id", ""),
                concept_id=card["concept_id"],
                concept_title=card.get("concept_title", ""),
                card_type=card["card_type"],
                front_content=card["front_content"],
                back_content=card.get("back_content"),
                difficulty=card.get("difficulty", 3),
                image_url=card.get("image_url"),
                tags=card.get("tags", []),
                metadata=card.get("metadata", {})
            )
            for card in cards
        ]
        
        return StudySessionResponse(
            session_id=session_record["id"],
            cards=card_responses,
            session_metadata={
                "session_type": session_request.session_type,
                "total_cards": len(cards),
                "estimated_duration_minutes": len(cards) * 2,  # 2 minutes per card
                "created_at": session_record["started_at"]
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create study session: {str(e)}")

@router.get("/cards")
async def get_study_cards(
    document_id: Optional[str] = Query(None, description="Filter by document"),
    concept_ids: Optional[List[str]] = Query(None, description="Filter by concept IDs"),
    card_type: Optional[str] = Query(None, description="Filter by card type"),
    limit: int = Query(50, description="Maximum number of cards"),
    user_id: str = Depends(get_current_user_id)
):
    """Get study cards for the user"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        cards = await db_service.get_user_study_cards(user_id, concept_ids)
        
        # Apply filters
        if document_id:
            # Would need to join with concepts table to filter by document
            pass
        
        if card_type:
            cards = [c for c in cards if c["card_type"] == card_type]
        
        # Limit results
        cards = cards[:limit]
        
        return [
            StudyCardResponse(
                id=card["id"],
                concept_id=card["concept_id"],
                concept_title=card.get("concepts", {}).get("title", ""),
                card_type=card["card_type"],
                front_content=card["front_content"],
                back_content=card["back_content"],
                difficulty=card["difficulty"],
                image_url=card["image_url"],
                tags=card["tags"],
                metadata=card["metadata"]
            )
            for card in cards
        ]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve study cards: {str(e)}")

@router.post("/progress")
async def update_study_progress(
    progress_request: StudyProgressRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Update user's study progress for a concept"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        progress_data = {
            "mastery_level": min(1.0, max(0.0, progress_request.mastery_level)),
            "times_studied": progress_request.times_studied,
            "times_correct": progress_request.times_correct,
            "last_studied_at": datetime.utcnow().isoformat(),
            "metadata": {
                "session_duration_minutes": progress_request.session_duration_minutes,
                "accuracy_rate": progress_request.times_correct / max(progress_request.times_studied, 1)
            }
        }
        
        updated_progress = await db_service.update_user_progress(
            user_id,
            progress_request.concept_id,
            progress_data
        )
        
        return {
            "concept_id": progress_request.concept_id,
            "updated_progress": updated_progress,
            "message": "Progress updated successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update progress: {str(e)}")

@router.get("/progress")
async def get_study_progress(
    concept_ids: Optional[List[str]] = Query(None, description="Filter by concept IDs"),
    user_id: str = Depends(get_current_user_id)
):
    """Get user's study progress"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        progress_data = await db_service.get_user_progress(user_id, concept_ids)
        
        return {
            "user_id": user_id,
            "progress": progress_data,
            "stats": {
                "total_concepts_studied": len(progress_data),
                "average_mastery": sum(p["mastery_level"] for p in progress_data) / max(len(progress_data), 1),
                "concepts_mastered": len([p for p in progress_data if p["mastery_level"] >= 0.8]),
                "recent_activity": len([p for p in progress_data if p.get("last_studied_at")])
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve progress: {str(e)}")

@router.get("/sessions")
async def get_study_sessions(
    limit: int = Query(20, description="Maximum number of sessions"),
    user_id: str = Depends(get_current_user_id)
):
    """Get user's recent study sessions"""
    
    try:
        services = get_services()
        db_service = services['db_service']
        sessions = await db_service.get_user_study_sessions(user_id, limit)
        
        return {
            "user_id": user_id,
            "sessions": sessions,
            "stats": {
                "total_sessions": len(sessions),
                "total_study_time": sum(s.get("duration_minutes", 0) for s in sessions),
                "total_cards_completed": sum(s.get("cards_completed", 0) for s in sessions)
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve study sessions: {str(e)}")

@router.get("/recommendations")
async def get_study_recommendations(
    document_id: Optional[str] = Query(None, description="Get recommendations for specific document"),
    max_recommendations: int = Query(10, description="Maximum number of recommendations"),
    user_id: str = Depends(get_current_user_id)
):
    """Get personalized study recommendations"""
    
    try:
        # This would implement intelligent recommendation logic
        # For now, return a placeholder structure
        
        recommendations = {
            "user_id": user_id,
            "recommendations": [
                {
                    "type": "review_weak_concepts",
                    "description": "Review concepts with low mastery scores",
                    "concept_ids": [],
                    "priority": "high"
                },
                {
                    "type": "learn_prerequisites",
                    "description": "Study prerequisite concepts for better understanding",
                    "concept_ids": [],
                    "priority": "medium"
                },
                {
                    "type": "explore_related",
                    "description": "Explore concepts related to your interests", 
                    "concept_ids": [],
                    "priority": "low"
                }
            ],
            "message": "Study recommendations - to be implemented with ML/analytics"
        }
        
        return recommendations
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get recommendations: {str(e)}")

@router.post("/cards/generate")
async def generate_study_cards(
    concept_ids: List[str],
    card_types: Optional[List[str]] = Query(None, description="Types of cards to generate"),
    user_id: str = Depends(get_current_user_id)
):
    """Generate new study cards for specific concepts"""
    
    try:
        services = get_services()
        study_generator = services['study_generator']
        db_service = services['db_service']
        # Generate cards using the study card generator
        generated_cards = await study_generator.generate_concept_study_cards(
            concept_ids,
            user_id,
            "learn",
            card_types
        )
        
        # Store the generated cards
        if generated_cards:
            stored_cards = await db_service.create_study_cards(user_id, generated_cards)
            
            return {
                "generated_cards": len(generated_cards),
                "stored_cards": len(stored_cards),
                "cards": [
                    StudyCardResponse(
                        id=card["id"],
                        concept_id=card["concept_id"],
                        concept_title="",  # Would need to be populated
                        card_type=card["card_type"],
                        front_content=card["front_content"],
                        back_content=card.get("back_content"),
                        difficulty=card["difficulty"],
                        image_url=card.get("image_url"),
                        tags=card.get("tags", []),
                        metadata=card.get("metadata", {})
                    )
                    for card in stored_cards
                ]
            }
        else:
            return {"message": "No cards could be generated for the specified concepts"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate study cards: {str(e)}")