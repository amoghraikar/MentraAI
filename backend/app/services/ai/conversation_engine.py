"""
ConversationEngine — Multi-turn conversation and context management for Mentra AI.

Features:
- Conversation memory tracking (Subject, Topic, Learning Objective)
- Pronoun and implicit reference resolution ("them", "it", "that")
- Dynamic topic continuity and topic switching
- Adaptive learner level detection (Beginner, Intermediate, Advanced)
- Rolling conversation summarization for long context
- Strict context priority enforcement
"""

from dataclasses import dataclass, field
from enum import Enum
import re
from typing import Any, Dict, List, Optional, Tuple
from app.services.ai.mentra_context import MentraContext
from app.services.ai.prompts import MENTRA_SYSTEM_PROMPT


class IntentType(str, Enum):
    EXPLAIN = "EXPLAIN"
    TEACH = "TEACH"
    PRACTICE = "PRACTICE"
    QUIZ = "QUIZ"
    HINT = "HINT"
    REVIEW_MISTAKE = "REVIEW_MISTAKE"
    MOTIVATE = "MOTIVATE"
    SESSION_HELP = "SESSION_HELP"
    PROGRESS_QUESTION = "PROGRESS_QUESTION"
    GENERAL_CHAT = "GENERAL_CHAT"


@dataclass
class MentraIntent:
    type: IntentType
    confidence: float = 1.0
    parameters: Dict[str, Any] = field(default_factory=dict)


class ConversationEngine:
    """
    Coordinates multi-turn memory, context synthesis, sanitization,
    and rolling summarization for the local LLM.
    """

    MAX_RAW_TURNS = 8  # Maximum recent turns passed verbatim to local LLM

    @classmethod
    def detect_intent(cls, message: str, context: Optional[MentraContext] = None) -> MentraIntent:
        """
        Lightweight intent recognition to classify user request into a MentraIntent.
        Does not create separate agents; handled uniformly by the single Mentra model.
        """
        lower = message.strip().lower()

        # Check for mistake review
        if any(w in lower for w in ("why was i wrong", "explain my mistake", "why is that wrong", "where did i go wrong", "why incorrect")):
            return MentraIntent(type=IntentType.REVIEW_MISTAKE, confidence=0.95)

        # Check for hints
        if any(w in lower for w in ("give me a hint", "hint please", "need a hint", "can i get a hint")):
            return MentraIntent(type=IntentType.HINT, confidence=0.95)

        # Check for quiz / practice
        if any(w in lower for w in ("give me a question", "test me", "quiz me", "give me a problem", "practice question", "another question", "harder question")):
            return MentraIntent(type=IntentType.PRACTICE if "practice" in lower else IntentType.QUIZ, confidence=0.9)

        # Check for session timing / help
        if any(w in lower for w in ("how long have i been studying", "how much longer", "study time", "session time", "timer")):
            return MentraIntent(type=IntentType.SESSION_HELP, confidence=0.95)

        # Check for progress / stats questions
        if any(w in lower for w in ("how am i doing", "what are my weak areas", "my progress", "my stats", "my performance", "what am i studying")):
            return MentraIntent(type=IntentType.PROGRESS_QUESTION, confidence=0.9)

        # Check for motivation / distraction / fatigue
        if any(w in lower for w in ("i'm tired", "im tired", "i am tired", "distracted", "getting distracted", "lost focus", "can't focus", "cant focus", "motivate me")):
            return MentraIntent(type=IntentType.MOTIVATE, confidence=0.9)

        # Check for explanation
        if any(w in lower for w in ("explain", "what is", "how does", "what are", "why does", "define", "break down", "teach me")):
            return MentraIntent(type=IntentType.EXPLAIN, confidence=0.85)

        return MentraIntent(type=IntentType.GENERAL_CHAT, confidence=0.7)

    @classmethod
    def sanitize_history(cls, raw_history: List[Any]) -> List[Dict[str, str]]:
        """Cleans and validates the incoming message history list."""
        sanitized: List[Dict[str, str]] = []
        for item in raw_history:
            if isinstance(item, dict):
                role = str(item.get("role", "user")).strip()
                content = str(item.get("content", "")).strip()
            elif hasattr(item, "role") and hasattr(item, "content"):
                role = str(getattr(item, "role", "user")).strip()
                content = str(getattr(item, "content", "")).strip()
            elif hasattr(item, "sender") and hasattr(item, "text"):
                role = "assistant" if getattr(item, "sender") in ("coach", "assistant") else "user"
                content = str(getattr(item, "text", "")).strip()
            else:
                continue

            # Standardize role names for chat models
            if role in ("coach", "model", "bot"):
                role = "assistant"
            elif role not in ("user", "assistant", "system"):
                role = "user"

            if content:
                sanitized.append({"role": role, "content": content})
        return sanitized

    @classmethod
    def generate_rolling_summary(cls, older_turns: List[Dict[str, str]]) -> str:
        """
        Creates a compact rolling summary of earlier conversation turns
        so older context is preserved without inflating the context window.
        """
        if not older_turns:
            return ""

        topics_discussed = []
        preferences = []

        for turn in older_turns:
            text = turn["content"].lower()
            if "dsa" in text:
                topics_discussed.append("DSA")
            if "array" in text:
                topics_discussed.append("Arrays")
            if "recursion" in text:
                topics_discussed.append("Recursion")
            if "dbms" in text:
                topics_discussed.append("DBMS")
            if "normalization" in text:
                topics_discussed.append("Normalization")
            if any(b in text for b in ("beginner", "simple", "simpler", "like i'm 10")):
                preferences.append("beginner-friendly explanations")

        summary_parts = []
        if topics_discussed:
            unique_topics = list(dict.fromkeys(topics_discussed))
            summary_parts.append(f"Earlier discussion covered: {', '.join(unique_topics)}.")
        if preferences:
            summary_parts.append("Student requested simplified, intuitive explanations.")

        return " ".join(summary_parts) if summary_parts else "Student engaged in introductory concept review."

    @classmethod
    def prepare_llm_payload(
        cls,
        current_message: str,
        history: List[Dict[str, str]],
        context: MentraContext,
        custom_system_prompt: Optional[str] = None,
    ) -> Tuple[str, List[Dict[str, str]]]:
        """
        Prepares the finalized system prompt and bounded chat messages
        for the local LLM, adhering to context priority and memory constraints.
        """
        sanitized_history = cls.sanitize_history(history)

        # 1. Update Context from History and Message
        context.update_from_conversation(sanitized_history, current_message)

        # 2. Long Context Handling: Bounded window with rolling summary
        rolling_summary = ""
        if len(sanitized_history) > cls.MAX_RAW_TURNS:
            older_turns = sanitized_history[:-cls.MAX_RAW_TURNS]
            recent_turns = sanitized_history[-cls.MAX_RAW_TURNS:]
            rolling_summary = cls.generate_rolling_summary(older_turns)
            active_turns = recent_turns
        else:
            active_turns = list(sanitized_history)

        # 3. Assemble System Prompt
        base_prompt = custom_system_prompt or MENTRA_SYSTEM_PROMPT
        prompt_sections = [base_prompt]

        if rolling_summary:
            prompt_sections.append(f"[CONVERSATION BACKGROUND SUMMARY]: {rolling_summary}")

        formatted_context = context.format_for_prompt(current_message)
        if formatted_context:
            prompt_sections.append(f"### CURRENT VERIFIED STUDY CONTEXT:\n{formatted_context}")

        full_system_prompt = "\n\n".join(prompt_sections)

        # 4. Construct Final Messages
        chat_messages = list(active_turns)
        chat_messages.append({"role": "user", "content": current_message})

        return full_system_prompt, chat_messages
