import uuid
from datetime import datetime, timezone
from typing import AsyncGenerator, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.ai_coach import CoachMessage, CoachInsight
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
from app.services.ai.mentra_context import MentraContext
from app.services.ai.conversation_engine import ConversationEngine
from app.services.ai.decision_engine import CoachingDecisionEngine
from app.services.ai.document_service import document_service
from app.services.ai.prompts import (
    COACH_SYSTEM_PROMPT,
    TOPIC_EXPLANATION_PROMPT,
    INTERVENTION_PROMPT,
    POST_SESSION_PROMPT,
    STUDY_PLAN_PROMPT,
    build_coaching_system_prompt,
    MEXTRA_SYSTEM_PROMPT_LAYER,
)
from app.schemas.ai_coach import LocalLLMStatusResponse
from app.services.ai.local_llm import (
    local_llm_engine,
    ModelState,
    LocalLLMError,
    LocalLLM,
    MENTRA_SYSTEM_PROMPT,
)
from app.services.ai.providers import (
    AiProviderFactory,
    BaseAiProvider,
    LocalLLMProvider,
    DynamicCognitiveAiProvider,
)


class AiCoachService:
    def __init__(self, provider: Optional[BaseAiProvider] = None, local_llm: Optional[LocalLLM] = None):
        self.local_llm = local_llm or local_llm_engine
        self.provider = provider or LocalLLMProvider()

    def get_config(self) -> AiCoachConfigResponse:
        return AiCoachConfigResponse(
            active_provider="LocalLLM",
            is_cloud_connected=False,
            supported_providers=["LocalLLM"],
            model=getattr(self.local_llm, "model", "qwen2.5:0.5b"),
            custom_system_prompt=MENTRA_SYSTEM_PROMPT,
        )

    async def get_model_status(self) -> LocalLLMStatusResponse:
        state = self.local_llm.get_state()
        if state == ModelState.UNINITIALIZED:
            try:
                await self.local_llm.initialize()
                state = self.local_llm.get_state()
            except Exception:
                state = self.local_llm.get_state()

        status_msg = "Mentra AI ready" if state == ModelState.READY else (
            "Loading Mentra AI..." if state == ModelState.LOADING else (
                "Mentra AI couldn't start. Retry" if state == ModelState.ERROR else str(state.value)
            )
        )
        return LocalLLMStatusResponse(
            state=state.value,
            model=getattr(self.local_llm, "model", "qwen2.5:0.5b"),
            status_message=status_msg,
            is_ready=self.local_llm.is_ready(),
            last_error=self.local_llm.get_last_error(),
        )

    async def cancel_chat(self) -> None:
        await self.local_llm.cancel()

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
        # 1. Select provider (custom or default)
        active_provider = self.provider
        if request.provider or request.api_key or request.model or request.custom_endpoint_url:
            active_provider = AiProviderFactory.get_provider(
                provider_name=request.provider,
                api_key=request.api_key,
                model=request.model,
                base_url=request.custom_endpoint_url,
            )

        # 2. Ingest attached material if provided directly in the request
        if request.attached_material_text and request.attached_material_text.strip():
            document_service.ingest_material(
                title="Attached Study Note",
                content=request.attached_material_text.strip(),
            )

        # 3. Retrieve relevant study material context
        retrieved_material = document_service.retrieve_relevant_context(request.message) if request.attached_material_text else ""

        # 4. Build verified study context and synthesize prompt via ConversationEngine
        mentra_context = MentraContext.create_from_db_and_session(
            db=db,
            user_id=user_id,
            subject_id=request.subject_id,
            topic_id=request.topic_id,
            active_session_id=request.active_session_id,
            history=[{"role": item.role, "content": item.content} for item in request.history],
            current_message=request.message,
        )

        system_prompt, chat_messages = ConversationEngine.prepare_llm_payload(
            current_message=request.message,
            history=[{"role": item.role, "content": item.content} for item in request.history],
            context=mentra_context,
            custom_system_prompt=request.custom_system_prompt,
        )

        if retrieved_material:
            system_prompt = (
                f"{system_prompt}\n\n"
                f"===================================================\n"
                f"[GROUNDING STUDY MATERIAL & SOURCE TEXT EXCERPTS]:\n"
                f"{retrieved_material}\n"
                f"===================================================\n"
                f"CRITICAL INSTRUCTION: Synthesize your answer accurately using the study material excerpts above."
            )

        # 5. Analyze interaction with Coaching Decision Layer
        intent, mode, action, suggested_steps = CoachingDecisionEngine.analyze_interaction(
            message=request.message,
            history=chat_messages,
            context=mentra_context.__dict__,
        )

        # 9. Persist user message
        user_msg = CoachMessage(
            id=str(uuid.uuid4()),
            user_id=user_id,
            sender="user",
            message=request.message,
            mode="chat",
        )
        db.add(user_msg)

        # 10. Generate response from the selected LLM provider with safe diagnostic logging
        import time
        import logging
        ai_logger = logging.getLogger("mentra.ai")

        provider_name = type(active_provider).__name__.replace("Provider", "")
        model_name = getattr(active_provider, "model", "qwen2.5:0.5b")

        ai_logger.info(f"[MENTRA AI] request started")
        ai_logger.info(f"[MENTRA AI] provider = {provider_name}")
        ai_logger.info(f"[MENTRA AI] model = {model_name}")
        ai_logger.info(f"[MENTRA AI] request sent")

        start_time = time.time()
        try:
            response_text = await active_provider.generate_chat(
                messages=chat_messages,
                system_prompt=system_prompt,
                temperature=0.7,
            )
            latency_ms = int((time.time() - start_time) * 1000)
            ai_logger.info(f"[MENTRA AI] response received")
            ai_logger.info(f"[MENTRA AI] status = 200 OK")
            ai_logger.info(f"[MENTRA AI] latency = {latency_ms}ms")
        except Exception as e:
            latency_ms = int((time.time() - start_time) * 1000)
            ai_logger.error(f"[MENTRA AI] provider failed after {latency_ms}ms: {e}")
            from fastapi import HTTPException
            raise HTTPException(
                status_code=503,
                detail="Mentra couldn't generate a response. Try again.",
            )

        # 11. Persist coach response
        coach_msg_id = str(uuid.uuid4())
        coach_msg = CoachMessage(
            id=coach_msg_id,
            user_id=user_id,
            sender="coach",
            message=response_text,
            mode="chat",
        )
        db.add(coach_msg)
        db.commit()

        action_suggestion = action.get("type") if action else ("Start Active Practice" if mode == "QUIZ" else None)

        return AiCoachChatResponse(
            id=coach_msg_id,
            sender="coach",
            message=response_text,
            intent=intent,
            mode=mode,
            action=action,
            action_suggestion=action_suggestion,
            suggested_next_steps=suggested_steps,
            timestamp=datetime.now(timezone.utc),
        )

    async def stream_chat(
        self,
        db: Session,
        user_id: str,
        request: AiCoachChatRequest,
    ) -> AsyncGenerator[str, None]:
        import json

        mentra_context = MentraContext.create_from_db_and_session(
            db=db,
            user_id=user_id,
            subject_id=request.subject_id,
            topic_id=request.topic_id,
            active_session_id=request.active_session_id,
            history=[{"role": item.role, "content": item.content} for item in request.history],
            current_message=request.message,
        )

        system_prompt, chat_messages = ConversationEngine.prepare_llm_payload(
            current_message=request.message,
            history=[{"role": item.role, "content": item.content} for item in request.history],
            context=mentra_context,
            custom_system_prompt=request.custom_system_prompt,
        )

        user_msg = CoachMessage(
            id=str(uuid.uuid4()),
            user_id=user_id,
            sender="user",
            message=request.message,
            mode="chat",
        )
        db.add(user_msg)
        db.commit()

        coach_msg_id = str(uuid.uuid4())
        tokens: List[str] = []

        try:
            async for chunk in self.local_llm.stream(
                messages=chat_messages,
                system_prompt=system_prompt,
                temperature=0.7,
            ):
                tokens.append(chunk)
                yield f"data: {json.dumps({'chunk': chunk, 'done': False})}\n\n"

            complete_text = "".join(tokens).strip()
            coach_msg = CoachMessage(
                id=coach_msg_id,
                user_id=user_id,
                sender="coach",
                message=complete_text,
                mode="chat",
            )
            db.add(coach_msg)
            db.commit()

            yield f"data: {json.dumps({'chunk': '', 'done': True, 'id': coach_msg_id, 'message': complete_text})}\n\n"
        except Exception:
            err_json = json.dumps({"error": "Mentra couldn't generate a response. Try again.", "done": True})
            yield f"data: {err_json}\n\n"

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
    ) -> List[AiCoachChatResponse]:
        messages = (
            db.query(CoachMessage)
            .filter(CoachMessage.user_id == user_id)
            .order_by(CoachMessage.created_at)
            .limit(20)
            .all()
        )

        if messages:
            return [
                AiCoachChatResponse(
                    id=m.id,
                    sender=m.sender,
                    message=m.message,
                    timestamp=m.created_at,
                )
                for m in messages
            ]

        return [
            AiCoachChatResponse(
                id="msg_init",
                sender="coach",
                message="Hello! I'm Mentra, your AI Study Coach. How can I help you optimize your study session or break down a difficult concept today?",
                timestamp=datetime.utcnow(),
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

