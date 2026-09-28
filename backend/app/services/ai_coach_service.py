import uuid
from datetime import datetime, timezone
from typing import AsyncGenerator, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.ai_coach import CoachMessage, CoachInsight, Conversation
from app.services.ai.conversation_manager import conversation_manager, ConversationManager
from app.models.subject import Subject
from app.models.topic import Topic
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
from app.services.ai.coach_identity import (
    MENTRA_COACH_IDENTITY,
    INTENT_GUIDANCE_RULES,
)
from app.services.ai.context_builder import CoachContextBuilder, ContextBuilder
from app.services.ai.decision_engine import CoachingDecisionEngine
from app.services.ai.document_service import document_service
from app.services.ai.prompts import (
    COACH_SYSTEM_PROMPT,
    TOPIC_EXPLANATION_PROMPT,
    INTERVENTION_PROMPT,
    POST_SESSION_PROMPT,
    STUDY_PLAN_PROMPT,
    build_coaching_system_prompt,
)
from app.schemas.ai_coach import LocalLLMStatusResponse
from app.services.ai.local_llm import (
    local_llm_engine,
    LocalLLM,
    MENTRA_SYSTEM_PROMPT,
)
from app.services.ai.providers import (
    AiProviderFactory,
    BaseAiProvider,
)


class AiCoachService:
    def __init__(
        self,
        provider: Optional[BaseAiProvider] = None,
        local_llm: Optional[LocalLLM] = None,
        conv_manager: Optional[ConversationManager] = None,
    ):
        self.local_llm = local_llm or local_llm_engine
        self.provider = provider or AiProviderFactory.get_provider()
        self.conv_manager = conv_manager or conversation_manager

    def get_config(self) -> AiCoachConfigResponse:
        return AiCoachConfigResponse(
            active_provider="LocalLLM",
            is_cloud_connected=False,
            supported_providers=["LocalLLM"],
            model=getattr(self.local_llm, "model", "qwen2.5:1.5b"),
            custom_system_prompt=MENTRA_SYSTEM_PROMPT,
        )

    async def get_model_status(self) -> LocalLLMStatusResponse:
        info = await self.local_llm.get_model_info()
        is_ready = info.get("is_ready", False)
        state_str = "READY" if is_ready else (info.get("state") or "ERROR")
        last_err = info.get("last_error")
        msg = f"Local LLM Ready ({info.get('name')}, {info.get('parameters')})" if is_ready else (last_err or "Local LLM Not Ready")

        return LocalLLMStatusResponse(
            state=state_str,
            model=info.get("name", "qwen2.5:1.5b"),
            status_message=msg,
            is_ready=is_ready,
            last_error=last_err,
        )

    async def cancel_chat(self) -> None:
        await self.conv_manager.cancel_generation()

    def create_conversation(self, db: Session, user_id: str, title: Optional[str] = None) -> Conversation:
        return self.conv_manager.create_conversation(db=db, user_id=user_id, title=title)

    def list_conversations(self, db: Session, user_id: str, limit: int = 50) -> List[Conversation]:
        return self.conv_manager.list_conversations(db=db, user_id=user_id, limit=limit)

    def get_conversation(self, db: Session, conversation_id: str, user_id: str) -> Optional[Conversation]:
        return self.conv_manager.load_conversation(db=db, conversation_id=conversation_id, user_id=user_id)

    def delete_conversation(self, db: Session, conversation_id: str, user_id: str) -> bool:
        return self.conv_manager.delete_conversation(db=db, conversation_id=conversation_id, user_id=user_id)

    def clear_conversation(self, db: Session, conversation_id: str, user_id: str) -> bool:
        return self.conv_manager.clear_conversation(db=db, conversation_id=conversation_id, user_id=user_id)

    def set_provider(self, provider: BaseAiProvider) -> None:
        self.provider = provider

    async def test_provider_key(
        self,
        provider_name: str,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> dict:
        provider = AiProviderFactory.get_provider(
            provider_name=provider_name,
            api_key=api_key,
            model=model,
            base_url=base_url,
        )
        return await provider.test_connection()

    def upload_study_material(self, title: str, content: str, filename: Optional[str] = None):
        return document_service.ingest_material(title=title, content=content, filename=filename)

    async def chat(
        self,
        db: Session,
        user_id: str,
        request: AiCoachChatRequest,
    ) -> AiCoachChatResponse:
        import time
        import logging
        ai_logger = logging.getLogger("mentra.ai")
        start_time = time.time()

        ai_logger.info(f"[MENTRA AI] request started for user={user_id} conv={request.conversation_id}")

        try:
            gen_result = await self.conv_manager.generate_response(
                db=db,
                user_id=user_id,
                current_message=request.message,
                conversation_id=request.conversation_id,
                system_prompt=request.custom_system_prompt,
                temperature=0.7,
                use_rag=getattr(request, "use_rag", True),
            )
            response_text, conv, asst_msg = gen_result[0], gen_result[1], gen_result[2]
            sources = getattr(gen_result, "sources", [])
            rag_status = getattr(gen_result, "rag_status", "NO_RAG")
            latency_ms = int((time.time() - start_time) * 1000)
            ai_logger.info(f"[MENTRA AI] response received, status=200 OK, latency={latency_ms}ms, conv={conv.id}, sources={len(sources)}")
        except Exception as e:
            latency_ms = int((time.time() - start_time) * 1000)
            ai_logger.error(f"[MENTRA AI] local model generation failed after {latency_ms}ms: {e}")
            raise

        # Pedagogical intent analysis for UI action suggestions
        intent, mode, action, suggested_steps = CoachingDecisionEngine.analyze_interaction(
            message=request.message,
            history=[{"role": "user", "content": request.message}],
            context={},
        )
        action_suggestion = action.get("type") if action else ("Start Active Practice" if mode == "QUIZ" else None)

        return AiCoachChatResponse(
            id=asst_msg.id,
            conversation_id=conv.id,
            sender="coach",
            role="assistant",
            message=response_text,
            intent=intent,
            mode=mode,
            action=action,
            action_suggestion=action_suggestion,
            suggested_next_steps=suggested_steps,
            sources=sources,
            rag_status=rag_status,
            timestamp=asst_msg.created_at or datetime.now(timezone.utc),
        )

    async def stream_chat(
        self,
        db: Session,
        user_id: str,
        request: AiCoachChatRequest,
    ) -> AsyncGenerator[str, None]:
        import json
        import logging
        ai_logger = logging.getLogger("mentra.ai")
        ai_logger.info(f"[MENTRA AI] stream request started for user={user_id} conv={request.conversation_id}")

        async for event in self.conv_manager.stream_response(
            db=db,
            user_id=user_id,
            current_message=request.message,
            conversation_id=request.conversation_id,
            system_prompt=request.custom_system_prompt,
            temperature=0.7,
            use_rag=getattr(request, "use_rag", True),
        ):
            yield f"data: {json.dumps(event)}\n\n"

    async def explain_concept(
        self,
        db: Session,
        user_id: str,
        request: AiCoachExplainRequest,
    ) -> AiCoachExplainResponse:
        subject_name = "General Subject"
        topic_name = "General Topic"

        if request.subject_id:
            sub = db.query(Subject).filter(Subject.id == request.subject_id).first()
            if sub:
                subject_name = sub.title

        if request.topic_id:
            top = db.query(Topic).filter(Topic.id == request.topic_id).first()
            if top:
                topic_name = top.title

        prompt = TOPIC_EXPLANATION_PROMPT.format(
            concept_name=request.concept_name,
            difficulty_level=request.difficulty_level,
            subject_name=subject_name,
            topic_name=topic_name,
            notes_context=f"Student Notes: {request.student_notes_context}" if request.student_notes_context else "",
        )

        return await self.provider.generate_structured(
            prompt=prompt,
            system_prompt=COACH_SYSTEM_PROMPT,
            response_model=AiCoachExplainResponse,
        )

    async def evaluate_intervention(
        self,
        db: Session,
        user_id: str,
        request: AiCoachInterventionRequest,
    ) -> AiCoachInterventionResponse:
        prompt = INTERVENTION_PROMPT.format(
            subject_title=request.subject_title,
            topic_title=request.topic_title,
            elapsed_minutes=request.elapsed_minutes,
            distractions_count=request.distractions_count,
            trigger_reason=request.trigger_reason,
        )

        return await self.provider.generate_structured(
            prompt=prompt,
            system_prompt=COACH_SYSTEM_PROMPT,
            response_model=AiCoachInterventionResponse,
        )

    async def analyze_session(
        self,
        db: Session,
        user_id: str,
        request: AiCoachSessionAnalysisRequest,
    ) -> AiCoachSessionAnalysisResponse:
        prompt = POST_SESSION_PROMPT.format(
            subject_title=request.subject_title,
            topic_title=request.topic_title,
            target_duration_minutes=request.target_duration_minutes,
            actual_duration_minutes=request.actual_duration_minutes,
            focus_score=request.focus_score,
            distractions_count=request.distractions_count,
            reflection=request.reflection,
        )

        analysis = await self.provider.generate_structured(
            prompt=prompt,
            system_prompt=COACH_SYSTEM_PROMPT,
            response_model=AiCoachSessionAnalysisResponse,
        )
        analysis.session_id = request.session_id
        return analysis

    async def generate_study_plan(
        self,
        db: Session,
        user_id: str,
        request: AiCoachStudyPlanRequest,
    ) -> AiCoachStudyPlanResponse:
        sub = db.query(Subject).filter(Subject.id == request.subject_id).first()
        subject_title = sub.title if sub else "Target Subject"

        topics = db.query(Topic).filter(Topic.subject_id == request.subject_id).all()
        topics_str = ", ".join([t.title for t in topics]) if topics else "Core Topics"

        prompt = STUDY_PLAN_PROMPT.format(
            goal_title=request.goal_title,
            subject_title=subject_title,
            available_daily_minutes=request.available_daily_minutes,
            target_completion_days=request.target_completion_days,
            topics_list=topics_str,
        )

        return await self.provider.generate_structured(
            prompt=prompt,
            system_prompt=COACH_SYSTEM_PROMPT,
            response_model=AiCoachStudyPlanResponse,
        )

    def get_insights(
        self,
        db: Session,
        user_id: str,
    ) -> List[CoachInsightResponse]:
        insights = (
            db.query(CoachInsight)
            .filter(CoachInsight.user_id == user_id, CoachInsight.is_active == True)
            .order_by(desc(CoachInsight.created_at))
            .all()
        )

        if insights:
            return [CoachInsightResponse.model_validate(i) for i in insights]

        return []

    def get_chat_history(
        self,
        db: Session,
        user_id: str,
        conversation_id: Optional[str] = None,
    ) -> List[AiCoachChatResponse]:
        query = db.query(CoachMessage).filter(CoachMessage.user_id == user_id)
        if conversation_id:
            query = query.filter(CoachMessage.conversation_id == conversation_id)
        messages = (
            query
            .order_by(CoachMessage.created_at)
            .limit(50)
            .all()
        )

        if messages:
            return [
                AiCoachChatResponse(
                    id=m.id,
                    conversation_id=m.conversation_id,
                    sender=m.sender or "coach",
                    role=m.role or ("assistant" if m.sender == "coach" else "user"),
                    message=m.message,
                    timestamp=m.created_at or datetime.now(timezone.utc),
                )
                for m in messages
            ]

        return [
            AiCoachChatResponse(
                id="msg_init",
                conversation_id=conversation_id,
                sender="coach",
                role="assistant",
                message="Hello! I'm Mentra, your AI Study Coach. How can I help you optimize your study session or break down a difficult concept today?",
                timestamp=datetime.now(timezone.utc),
            )
        ]

    def clear_chat_history(
        self,
        db: Session,
        user_id: str,
    ) -> bool:
        db.query(CoachMessage).filter(CoachMessage.user_id == user_id).delete()
        db.commit()
        return True

