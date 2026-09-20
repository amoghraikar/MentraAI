from typing import List
from fastapi import APIRouter, Depends, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_current_user_or_local, get_db
from app.models.user import User
from app.schemas.ai_coach import (
    AiCoachChatRequest,
    AiCoachChatResponse,
    AiCoachConfigRequest,
    AiCoachConfigResponse,
    AiCoachExplainRequest,
    AiCoachExplainResponse,
    AiCoachInterventionRequest,
    AiCoachInterventionResponse,
    AiCoachSessionAnalysisRequest,
    AiCoachSessionAnalysisResponse,
    AiCoachStudyPlanRequest,
    AiCoachStudyPlanResponse,
    CoachInsightResponse,
    LocalLLMStatusResponse,
    StudyMaterialUploadRequest,
    StudyMaterialUploadResponse,
    TestKeyRequest,
    TestKeyResponse,
)
from app.services.ai.document_service import document_service
from app.services.ai.providers import AiProviderFactory
from app.services.ai_coach_service import AiCoachService

router = APIRouter()
ai_coach_service = AiCoachService()


@router.get("/status", response_model=LocalLLMStatusResponse, status_code=status.HTTP_200_OK)
async def get_model_status() -> LocalLLMStatusResponse:
    return await ai_coach_service.get_model_status()


@router.post("/cancel", status_code=status.HTTP_200_OK)
async def cancel_ai_generation() -> dict:
    await ai_coach_service.cancel_chat()
    return {"message": "Generation cancellation requested", "status": "STOPPING"}


@router.post("/stream")
async def stream_coach_answer(
    request: AiCoachChatRequest,
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
):
    return StreamingResponse(
        ai_coach_service.stream_chat(db=db, user_id=current_user.id, request=request),
        media_type="text/event-stream",
    )


@router.get("/config", response_model=AiCoachConfigResponse, status_code=status.HTTP_200_OK)
def get_ai_config(
    current_user: User = Depends(get_current_user),
) -> AiCoachConfigResponse:
    return ai_coach_service.get_config()


@router.post("/config", response_model=AiCoachConfigResponse, status_code=status.HTTP_200_OK)
def update_ai_config(
    request: AiCoachConfigRequest,
    current_user: User = Depends(get_current_user),
) -> AiCoachConfigResponse:
    provider = AiProviderFactory.get_provider(
        provider_name=request.provider,
        api_key=request.api_key,
        model=request.model,
    )
    ai_coach_service.set_provider(provider)
    return ai_coach_service.get_config()


@router.post("/test-key", response_model=TestKeyResponse, status_code=status.HTTP_200_OK)
async def test_ai_key(
    request: TestKeyRequest,
    current_user: User = Depends(get_current_user),
) -> TestKeyResponse:
    result = await ai_coach_service.test_provider_key(
        provider_name=request.provider,
        api_key=request.api_key,
        model=request.model,
        base_url=request.custom_endpoint_url,
    )
    return TestKeyResponse(
        success=result.get("success", False),
        latency_ms=result.get("latency_ms", 0),
        message=result.get("message", "Tested"),
        provider=result.get("provider", request.provider),
        model=result.get("model", request.model or "default"),
    )


@router.post("/upload-material", response_model=StudyMaterialUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_study_material(
    request: StudyMaterialUploadRequest,
    current_user: User = Depends(get_current_user),
) -> StudyMaterialUploadResponse:
    doc = ai_coach_service.upload_study_material(
        title=request.title,
        content=request.content,
        filename=request.filename,
    )
    return StudyMaterialUploadResponse(
        doc_id=doc.doc_id,
        title=doc.title,
        filename=doc.filename,
        char_count=doc.char_count,
        chunks_count=doc.chunks_count,
        summary_preview=doc.summary_preview,
    )


@router.get("/materials", response_model=List[StudyMaterialUploadResponse], status_code=status.HTTP_200_OK)
def list_study_materials(
    current_user: User = Depends(get_current_user),
) -> List[StudyMaterialUploadResponse]:
    docs = document_service.list_documents()
    return [
        StudyMaterialUploadResponse(
            doc_id=d.doc_id,
            title=d.title,
            filename=d.filename,
            char_count=d.char_count,
            chunks_count=d.chunks_count,
            summary_preview=d.summary_preview,
        )
        for d in docs
    ]



@router.post("/chat", response_model=AiCoachChatResponse, status_code=status.HTTP_200_OK)
async def ask_coach(
    request: AiCoachChatRequest,
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> AiCoachChatResponse:
    return await ai_coach_service.chat(db=db, user_id=current_user.id, request=request)


@router.get("/chat", response_model=List[AiCoachChatResponse], status_code=status.HTTP_200_OK)
def get_chat_history(
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> List[AiCoachChatResponse]:
    return ai_coach_service.get_chat_history(db=db, user_id=current_user.id)


@router.delete("/chat", status_code=status.HTTP_200_OK)
def clear_chat_history(
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> dict:
    ai_coach_service.clear_chat_history(db=db, user_id=current_user.id)
    return {"message": "Chat history cleared successfully"}


@router.post("/explain", response_model=AiCoachExplainResponse, status_code=status.HTTP_200_OK)
async def explain_concept(
    request: AiCoachExplainRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AiCoachExplainResponse:
    return await ai_coach_service.explain_concept(db=db, user_id=current_user.id, request=request)


@router.post("/intervention", response_model=AiCoachInterventionResponse, status_code=status.HTTP_200_OK)
async def evaluate_intervention(
    request: AiCoachInterventionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AiCoachInterventionResponse:
    return await ai_coach_service.evaluate_intervention(db=db, user_id=current_user.id, request=request)


@router.post("/session-analysis", response_model=AiCoachSessionAnalysisResponse, status_code=status.HTTP_200_OK)
async def analyze_session(
    request: AiCoachSessionAnalysisRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AiCoachSessionAnalysisResponse:
    return await ai_coach_service.analyze_session(db=db, user_id=current_user.id, request=request)


@router.post("/study-plan", response_model=AiCoachStudyPlanResponse, status_code=status.HTTP_200_OK)
async def generate_study_plan(
    request: AiCoachStudyPlanRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AiCoachStudyPlanResponse:
    return await ai_coach_service.generate_study_plan(db=db, user_id=current_user.id, request=request)


@router.get("/insights", response_model=List[CoachInsightResponse], status_code=status.HTTP_200_OK)
def get_insights(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> List[CoachInsightResponse]:
    return ai_coach_service.get_insights(db=db, user_id=current_user.id)
