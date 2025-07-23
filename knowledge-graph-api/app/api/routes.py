from fastapi import APIRouter
from app.api.endpoints import documents, knowledge_graph, study

router = APIRouter()

# Include endpoint routers
router.include_router(documents.router, prefix="/documents", tags=["documents"])
router.include_router(knowledge_graph.router, prefix="/knowledge-graph", tags=["knowledge-graph"])
router.include_router(study.router, prefix="/study", tags=["study"])

@router.get("/")
async def api_root():
    return {"message": "Knowledge Graph API v1"}