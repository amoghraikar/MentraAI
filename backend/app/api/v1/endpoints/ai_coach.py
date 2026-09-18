from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
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
)
from app.services.ai.providers import AiProviderFactory
from app.services.ai_coach_service import AiCoachService

router = APIRouter()
ai_coach_service = AiCoachService()


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



@router.post("/chat", response_model=AiCoachChatResponse, status_code=status.HTTP_200_OK)
async def ask_coach(
    request: AiCoachChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AiCoachChatResponse:
    return await ai_coach_service.chat(db=db, user_id=current_user.id, request=request)


@router.get("/chat", response_model=List[AiCoachChatResponse], status_code=status.HTTP_200_OK)
def get_chat_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> List[AiCoachChatResponse]:
    return ai_coach_service.get_chat_history(db=db, user_id=current_user.id)


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
