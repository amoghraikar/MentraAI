import uuid
from datetime import datetime
from typing import List, Optional
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
from app.services.ai.context_builder import ContextBuilder
from app.services.ai.prompts import (
    COACH_SYSTEM_PROMPT,
    TOPIC_EXPLANATION_PROMPT,
    INTERVENTION_PROMPT,
    POST_SESSION_PROMPT,
    STUDY_PLAN_PROMPT,
)
from app.services.ai.providers import AiProviderFactory, BaseAiProvider


class AiCoachService:
    def __init__(self, provider: Optional[BaseAiProvider] = None):
        self.provider = provider or AiProviderFactory.get_provider()

    def get_config(self) -> AiCoachConfigResponse:
        active_name = type(self.provider).__name__.replace("Provider", "").replace("Ai", "")
        return AiCoachConfigResponse(
            active_provider=active_name,
            is_cloud_connected=active_name in ("Gemini", "OpenAi", "Groq", "OpenRouter"),
            supported_providers=["Gemini", "OpenAI", "Groq", "OpenRouter", "Ollama", "Dynamic Cognitive AI"],
            model=getattr(self.provider, "model", "cognitive-engine-v2"),
        )

    def set_provider(self, provider: BaseAiProvider) -> None:
        self.provider = provider

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

        # 2. Build system context
        context_str = ""
        if request.include_study_context:
            context = ContextBuilder.build_user_study_context(
                db, user_id, request.subject_id, request.topic_id
            )
            context_str = ContextBuilder.format_context_for_prompt(context)

        system_prompt = request.custom_system_prompt or COACH_SYSTEM_PROMPT
        if context_str and context_str != "General Study Context":
            system_prompt = f"{system_prompt}\n\n[Active Student Telemetry]:\n{context_str}"

        # 3. Build multi-turn chat messages
        chat_messages = []
        for item in request.history:
            chat_messages.append({"role": item.role, "content": item.content})
        chat_messages.append({"role": "user", "content": request.message})

        # 4. Persist user message
        user_msg = CoachMessage(
            id=str(uuid.uuid4()),
            user_id=user_id,
            sender="user",
            message=request.message,
            mode="chat",
        )
        db.add(user_msg)

        # 5. Generate response
        response_text = await active_provider.generate_chat(
            messages=chat_messages,
            system_prompt=system_prompt,
            temperature=0.7,
        )

        # 6. Persist coach response
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

        return AiCoachChatResponse(
            id=coach_msg_id,
            sender="coach",
            message=response_text,
            action_suggestion="Review key concepts and test recall",
            suggested_next_steps=["Complete active practice block", "Review study analytics"],
            timestamp=datetime.utcnow(),
        )

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

        # Return default synthesized behavioral insights
        return [
            CoachInsightResponse(
                id="ins_1",
                title="Optimal Focus Interval: 45 Minutes",
                category="Focus Habit",
                summary="Your session data shows 91% focus retention during 45-minute morning blocks.",
                action_recommendation="Schedule high-difficulty analytical topics between 9:00 AM and 11:30 AM.",
                impact_metric="+18% Retention",
            ),
            CoachInsightResponse(
                id="ins_2",
                title="Active Recall Reinforcement",
                category="Retention",
                summary="Topics reviewed with end-of-session self-quizzing show 2.4x higher comprehension stability.",
                action_recommendation="Dedicate the last 5 minutes of each session to write 3 summary questions without notes.",
                impact_metric="+24% Mastery",
            ),
            CoachInsightResponse(
                id="ins_3",
                title="Micro-Rest Interleaving",
                category="Energy Management",
                summary="A 5-minute physical movement break prevents cognitive fatigue accumulation across double blocks.",
                action_recommendation="Step away from the screen for 5 minutes after every 45-minute study block.",
                impact_metric="-35% Distraction",
            ),
        ]

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
