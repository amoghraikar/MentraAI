"""Canonical Conversation Manager for Mentra AI.

Orchestrates multi-turn conversation persistence, context assembly, deterministic titling,
and streaming/synchronous text generation via LocalLLM on-device.
"""

from datetime import datetime, timezone
from enum import Enum
import json
import logging
import re
from typing import Any, AsyncGenerator, Dict, List, Optional, Tuple
import uuid

from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.models.ai_coach import Conversation, CoachMessage
from app.services.ai.context_builder import ContextBuilder
from app.services.ai.local_llm import LocalLLM, local_llm_engine, LocalLLMError, LocalLLMErrorCode, ModelState
from app.services.ai.prompts import MENTRA_SYSTEM_PROMPT

logger = logging.getLogger("mentra.ai.conversation_manager")


class ConversationState(str, Enum):
    IDLE = "IDLE"
    GENERATING = "GENERATING"
    CANCELLING = "CANCELLING"
    ERROR = "ERROR"


class ConversationManagerError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(f"[{code}] {message}")
        self.code = code
        self.message = message
class GenerationResult(tuple):
    """3-tuple compatible with legacy (text, conv, asst_msg), but carries sources, rag_status, and focus_context."""
    def __new__(
        cls,
        text: str,
        conv: Conversation,
        asst_msg: CoachMessage,
        sources: Optional[List[Dict[str, Any]]] = None,
        rag_status: str = "NO_RAG",
    ):
        return super().__new__(cls, (text, conv, asst_msg))

    def __init__(
        self,
        text: str,
        conv: Conversation,
        asst_msg: CoachMessage,
        sources: Optional[List[Dict[str, Any]]] = None,
        rag_status: str = "NO_RAG",
    ):
        self.text = text
        self.conversation = conv
        self.message = asst_msg
        self.sources = sources or []
        self.rag_status = rag_status


class ConversationManager:
    """Manages conversations, message histories, context building, and local inference execution."""

    def __init__(self, llm: Optional[LocalLLM] = None):
        self.llm = llm or local_llm_engine
        self._state: ConversationState = ConversationState.IDLE
        self._last_error: Optional[str] = None

    @property
    def state(self) -> ConversationState:
        return self._state

    def is_generating(self) -> bool:
        return self._state == ConversationState.GENERATING

    @staticmethod
    def generate_title_deterministic(initial_message: str) -> str:
        """Derives a clean, concise conversation title without secondary LLM invocations."""
        if not initial_message or not initial_message.strip():
            return "New Study Chat"

        cleaned = initial_message.strip()
        # Handle code snippets
        if any(kw in cleaned for kw in ("for(", "for (", "while(", "while (", "def ", "class ", "int ", "cout", "printf")):
            return "Code Explanation"

        lower = cleaned.lower()
        # Handle greetings
        if lower in ("hi", "hello", "hey", "sup", "yo", "good morning", "good evening"):
            return "Study Chat"
        if lower in ("bye", "goodbye", "cya", "see ya"):
            return "Wrap Up"

        # Strip common inquiry prefixes
        prefixes = [
            r"^teach\s+me\s+about\s+",
            r"^teach\s+me\s+",
            r"^explain\s+to\s+me\s+",
            r"^explain\s+",
            r"^what\s+is\s+a\s+",
            r"^what\s+is\s+an\s+",
            r"^what\s+is\s+",
            r"^what\s+are\s+",
            r"^how\s+does\s+",
            r"^how\s+do\s+i\s+",
            r"^how\s+to\s+",
            r"^can\s+you\s+help\s+me\s+with\s+",
            r"^can\s+you\s+explain\s+",
            r"^help\s+me\s+with\s+",
            r"^tell\s+me\s+about\s+",
            r"^give\s+me\s+a\s+",
            r"^give\s+me\s+",
        ]
        topic = cleaned
        for p in prefixes:
            topic = re.sub(p, "", topic, flags=re.IGNORECASE)

        topic = topic.strip().rstrip("?.!:")
        if not topic:
            return "Study Chat"

        # Capitalize words
        words = topic.split()
        if len(words) > 5:
            words = words[:5]
        
        capitalized = " ".join(w.capitalize() if not w.isupper() else w for w in words)
        return capitalized[:40].strip()

    def create_conversation(
        self,
        db: Session,
        user_id: str,
        title: Optional[str] = None,
    ) -> Conversation:
        """Creates a new isolated conversation container for a user."""
        conv = Conversation(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=title or "New Conversation",
        )
        db.add(conv)
        db.commit()
        db.refresh(conv)
        return conv

    def load_conversation(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
    ) -> Optional[Conversation]:
        """Loads a conversation guaranteeing user isolation."""
        return (
            db.query(Conversation)
            .filter(Conversation.id == conversation_id, Conversation.user_id == user_id)
            .first()
        )

    def list_conversations(
        self,
        db: Session,
        user_id: str,
        limit: int = 50,
    ) -> List[Conversation]:
        """Lists conversations for the user ordered by most recently updated."""
        return (
            db.query(Conversation)
            .filter(Conversation.user_id == user_id)
            .order_by(desc(Conversation.updated_at))
            .limit(limit)
            .all()
        )

    def delete_conversation(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
    ) -> bool:
        """Deletes a conversation and all its messages."""
        conv = self.load_conversation(db, conversation_id, user_id)
        if not conv:
            return False
        db.delete(conv)
        db.commit()
        return True

    def clear_conversation(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
    ) -> bool:
        """Deletes all messages inside a conversation while retaining the container."""
        conv = self.load_conversation(db, conversation_id, user_id)
        if not conv:
            return False
        db.query(CoachMessage).filter(CoachMessage.conversation_id == conversation_id).delete()
        conv.title = "New Conversation"
        conv.updated_at = datetime.now(timezone.utc)
        db.commit()
        return True

    def add_user_message(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
        content: str,
    ) -> CoachMessage:
        """Persists a user message inside the specified conversation."""
        msg = CoachMessage(
            id=str(uuid.uuid4()),
            conversation_id=conversation_id,
            user_id=user_id,
            role="user",
            sender="user",
            message=content.strip(),
            mode="chat",
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)
        return msg

    def add_assistant_message(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
        content: str,
    ) -> CoachMessage:
        """Persists an assistant message inside the specified conversation."""
        msg = CoachMessage(
            id=str(uuid.uuid4()),
            conversation_id=conversation_id,
            user_id=user_id,
            role="assistant",
            sender="coach",
            message=content.strip(),
            mode="chat",
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)
        return msg

    def get_messages(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
    ) -> List[CoachMessage]:
        """Fetches all messages for a conversation ordered chronologically."""
        conv = self.load_conversation(db, conversation_id, user_id)
        if not conv:
            return []
        return (
            db.query(CoachMessage)
            .filter(CoachMessage.conversation_id == conversation_id)
            .order_by(CoachMessage.created_at)
            .all()
        )

    def _retrieve_rag_context(
        self,
        current_message: str,
        rag_engine_override: Optional[Any] = None,
    ) -> Tuple[Optional[str], List[Dict[str, Any]], str]:
        """Safely executes local RAG retrieval with complete failure isolation."""
        try:
            from app.services.rag.rag_engine import rag_engine
            engine = rag_engine_override or rag_engine
            retrieval = engine.retrieve_context(current_message)
            if retrieval.status == "SUCCESS" and retrieval.formatted_context != "NO_RELEVANT_CONTEXT":
                logger.info("[RAG] retrieval completed: %d sources found for query", len(retrieval.sources))
                return retrieval.formatted_context, retrieval.sources, "SUCCESS"
            else:
                logger.info("[RAG] no relevant context found for query, proceeding without RAG")
                return None, [], "NO_RELEVANT_CONTEXT"
        except Exception as e:
            logger.warning("[RAG] retrieval failed, proceeding without RAG: %s", e)
            return None, [], "UNAVAILABLE"

    def build_model_context(
        self,
        db: Session,
        conversation_id: str,
        user_id: str,
        current_message: str,
        system_prompt: Optional[str] = None,
        rag_context: Optional[str] = None,
        rag_sources: Optional[List[Dict[str, Any]]] = None,
        focus_context: Optional[Dict[str, Any]] = None,
        study_context: Optional[Dict[str, Any]] = None,
    ) -> Tuple[str, List[Dict[str, str]]]:
        """Assembles bounded, role-preserving context for inference."""
        raw_msgs = self.get_messages(db, conversation_id, user_id)
        history = [
            {"role": m.role or ("assistant" if m.sender == "coach" else "user"), "content": m.message}
            for m in raw_msgs
        ]
        sys_prompt = (system_prompt or MENTRA_SYSTEM_PROMPT).strip()
        return ContextBuilder.build_payload(
            system_instruction=sys_prompt,
            conversation_history=history,
            current_user_message=current_message,
            rag_context=rag_context,
            rag_sources=rag_sources,
            focus_context=focus_context,
            study_context=study_context,
        )

    async def generate_response(
        self,
        db: Session,
        user_id: str,
        current_message: str,
        conversation_id: Optional[str] = None,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
        use_rag: bool = False,
        rag_engine: Optional[Any] = None,
        focus_context: Optional[Dict[str, Any]] = None,
        study_context: Optional[Dict[str, Any]] = None,
    ) -> GenerationResult:
        """Generates a complete response synchronously using the local LLM."""
        if not current_message or not current_message.strip():
            raise ConversationManagerError("INVALID_INPUT", "User message cannot be empty")

        # 1. Resolve or create conversation
        conv: Optional[Conversation] = None
        if conversation_id:
            conv = self.load_conversation(db, conversation_id, user_id)
        if not conv:
            conv = self.create_conversation(
                db=db,
                user_id=user_id,
                title=self.generate_title_deterministic(current_message),
            )
        elif conv.title == "New Conversation":
            conv.title = self.generate_title_deterministic(current_message)

        # 2. Optional RAG context retrieval
        rag_context = None
        rag_sources: List[Dict[str, Any]] = []
        rag_status = "NO_RAG"
        if use_rag:
            rag_context, rag_sources, rag_status = self._retrieve_rag_context(
                current_message=current_message,
                rag_engine_override=rag_engine,
            )

        # 3. Build model context BEFORE adding user message to DB (ContextBuilder appends current_message)
        sys_inst, chat_msgs = self.build_model_context(
            db=db,
            conversation_id=conv.id,
            user_id=user_id,
            current_message=current_message,
            system_prompt=system_prompt,
            rag_context=rag_context,
            rag_sources=rag_sources,
            focus_context=focus_context,
            study_context=study_context,
        )

        # 4. Add user message
        user_msg = self.add_user_message(
            db=db,
            conversation_id=conv.id,
            user_id=user_id,
            content=current_message,
        )

        # 5. Generate response from local LLM
        self._state = ConversationState.GENERATING
        self._last_error = None
        try:
            generated_text = await self.llm.generate(
                messages=chat_msgs,
                system_prompt=sys_inst,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            self._state = ConversationState.IDLE
        except LocalLLMError as e:
            self._state = ConversationState.ERROR
            self._last_error = e.message
            raise ConversationManagerError(e.code.value, e.message)
        except Exception as e:
            self._state = ConversationState.ERROR
            self._last_error = str(e)
            raise ConversationManagerError("GENERATION_FAILED", str(e))

        # 6. Persist assistant message
        asst_msg = self.add_assistant_message(
            db=db,
            conversation_id=conv.id,
            user_id=user_id,
            content=generated_text,
        )

        conv.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(conv)

        return GenerationResult(
            text=generated_text,
            conv=conv,
            asst_msg=asst_msg,
            sources=rag_sources,
            rag_status=rag_status,
        )

    async def stream_response(
        self,
        db: Session,
        user_id: str,
        current_message: str,
        conversation_id: Optional[str] = None,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
        use_rag: bool = False,
        rag_engine: Optional[Any] = None,
        focus_context: Optional[Dict[str, Any]] = None,
        study_context: Optional[Dict[str, Any]] = None,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Streams response tokens progressively from the local LLM."""
        if not current_message or not current_message.strip():
            yield {"error": "[INVALID_INPUT] User message cannot be empty", "error_code": "INVALID_INPUT", "done": True}
            return

        # 1. Resolve or create conversation
        conv: Optional[Conversation] = None
        if conversation_id:
            conv = self.load_conversation(db, conversation_id, user_id)
        if not conv:
            conv = self.create_conversation(
                db=db,
                user_id=user_id,
                title=self.generate_title_deterministic(current_message),
            )
        elif conv.title == "New Conversation":
            conv.title = self.generate_title_deterministic(current_message)

        # 2. Optional RAG context retrieval
        rag_context = None
        rag_sources: List[Dict[str, Any]] = []
        rag_status = "NO_RAG"
        if use_rag:
            rag_context, rag_sources, rag_status = self._retrieve_rag_context(
                current_message=current_message,
                rag_engine_override=rag_engine,
            )

        # 3. Build model context
        sys_inst, chat_msgs = self.build_model_context(
            db=db,
            conversation_id=conv.id,
            user_id=user_id,
            current_message=current_message,
            system_prompt=system_prompt,
            rag_context=rag_context,
            rag_sources=rag_sources,
            focus_context=focus_context,
            study_context=study_context,
        )

        # 4. Add user message
        self.add_user_message(
            db=db,
            conversation_id=conv.id,
            user_id=user_id,
            content=current_message,
        )

        # 5. Stream response
        self._state = ConversationState.GENERATING
        self._last_error = None
        chunks: List[str] = []

        try:
            async for chunk in self.llm.stream(
                messages=chat_msgs,
                system_prompt=sys_inst,
                temperature=temperature,
                max_tokens=max_tokens,
            ):
                chunks.append(chunk)
                yield {
                    "chunk": chunk,
                    "done": False,
                    "conversation_id": conv.id,
                    "sources": rag_sources,
                }

            complete_text = "".join(chunks).strip()
            if not complete_text:
                raise ConversationManagerError("GENERATION_FAILED", "Local model produced an empty stream")

            # 6. Save completed assistant message
            asst_msg = self.add_assistant_message(
                db=db,
                conversation_id=conv.id,
                user_id=user_id,
                content=complete_text,
            )

            conv.updated_at = datetime.now(timezone.utc)
            db.commit()

            self._state = ConversationState.IDLE
            yield {
                "chunk": "",
                "done": True,
                "conversation_id": conv.id,
                "message_id": asst_msg.id,
                "message": complete_text,
                "title": conv.title,
                "sources": rag_sources,
                "rag_status": rag_status,
            }

        except LocalLLMError as e:
            self._state = ConversationState.ERROR
            self._last_error = e.message
            yield {
                "error": f"[{e.code.value}] {e.message}",
                "error_code": e.code.value,
                "done": True,
                "conversation_id": conv.id,
            }
        except Exception as e:
            self._state = ConversationState.ERROR
            self._last_error = str(e)
            yield {
                "error": f"[GENERATION_FAILED] {e}",
                "error_code": "GENERATION_FAILED",
                "done": True,
                "conversation_id": conv.id,
            }

    async def cancel_generation(self, force: bool = False) -> None:
        """Stops ongoing local generation and returns state to IDLE."""
        if self._state == ConversationState.GENERATING or force:
            self._state = ConversationState.CANCELLING
            await self.llm.cancel()
            self._state = ConversationState.IDLE
            logger.info("ConversationManager: generation cancelled successfully.")


# Canonical singleton manager instance
conversation_manager = ConversationManager()
