"""
Coaching Decision Layer: Identifies student intent, conversational emotion,
and determines the optimal pedagogical response mode and actions.
"""

import re
from typing import Any, Dict, List, Optional, Tuple


class CoachingIntent:
    GREETING = "GREETING"
    CASUAL_CHAT = "CASUAL_CHAT"
    FRUSTRATION = "FRUSTRATION"
    CONCEPT_QUESTION = "CONCEPT_QUESTION"
    TEACH_REQUEST = "TEACH_REQUEST"
    QUIZ_REQUEST = "QUIZ_REQUEST"
    PRACTICE_ANSWER = "PRACTICE_ANSWER"
    PROCRASTINATION = "PROCRASTINATION"
    PROGRESS_CHECK = "PROGRESS_CHECK"
    STUDY_PLANNING = "STUDY_PLANNING"
    SESSION_GUIDANCE = "SESSION_GUIDANCE"
    GRATITUDE = "GRATITUDE"
    GENERAL_QUERY = "GENERAL_QUERY"


class CoachingMode:
    ANSWER = "ANSWER"
    EXPLAIN = "EXPLAIN"
    ASK = "ASK"
    QUIZ = "QUIZ"
    CHALLENGE = "CHALLENGE"
    ENCOURAGE = "ENCOURAGE"
    REDIRECT = "REDIRECT"
    SUGGEST_ACTION = "SUGGEST_ACTION"


class CoachingDecisionEngine:
    """
    Lightweight decision engine that inspects the current message,
    conversation history, and active student state.
    """

    @classmethod
    def analyze_interaction(
        cls,
        message: str,
        history: Optional[List[Dict[str, str]]] = None,
        context: Optional[Dict[str, Any]] = None,
    ) -> Tuple[str, str, Optional[Dict[str, Any]], List[str]]:
        """
        Returns (intent, mode, optional_action, suggested_next_steps).
        """
        msg_clean = message.strip()
        msg_lower = msg_clean.lower()
        history = history or []
        last_coach_msg = ""
        for h in reversed(history):
            if h.get("role") in ("assistant", "coach"):
                last_coach_msg = h.get("content", "").lower()
                break

        # 1. Gratitude / Farewell
        gratitude_phrases = ("thanks", "thank you", "thx", "appreciate it", "got it", "understood", "cool", "nice", "ok", "okay", "bye", "goodbye", "perfect", "awesome")
        if msg_lower in gratitude_phrases or any(msg_lower.startswith(g) for g in ("thanks", "thank you", "thx", "got it", "appreciated")):
            return (
                CoachingIntent.GRATITUDE,
                CoachingMode.ENCOURAGE,
                None,
                ["Quiz me on this topic", "Start a 25-minute study block", "Explain next concept"],
            )

        # 2. Greetings
        greetings = ("hey", "hello", "hi", "hey there", "good morning", "good evening", "good afternoon", "yo", "sup", "what's up", "who are you", "what can you do")
        if msg_lower in greetings or any(msg_lower.startswith(g + " ") for g in ("hey", "hello", "hi", "good morning", "good evening")):
            return (
                CoachingIntent.GREETING,
                CoachingMode.ASK,
                None,
                ["Explain a challenging concept", "Quiz my understanding", "Review my focus telemetry"],
            )

        # 3. Frustration / Fatigue
        frustration_triggers = (
            "i'm tired", "im tired", "tired", "i'm cooked", "im cooked", "cooked", "exhausted",
            "sleepy", "drowsy", "this is impossible", "i can't do this", "i cant do this",
            "hate this", "giving up", "too hard", "studied this", "still don't understand",
            "still dont understand", "makes no sense", "wtf is", "wtf", "stuck on this"
        )
        if any(f in msg_lower for f in frustration_triggers):
            return (
                CoachingIntent.FRUSTRATION,
                CoachingMode.ENCOURAGE,
                {"type": "SUGGEST_BREAK", "duration_minutes": 5},
                ["Take a 5-minute breather", "Try an intuitive simple analogy", "Switch to an easier subtopic"],
            )

        # 4. Procrastination / Can't start
        procrastination_triggers = (
            "make me study", "don't want to study", "dont want to study", "procrastinating",
            "can't focus", "cant focus", "distracted", "how to start", "help me start",
            "lazy", "bored"
        )
        if any(p in msg_lower for p in procrastination_triggers):
            return (
                CoachingIntent.PROCRASTINATION,
                CoachingMode.SUGGEST_ACTION,
                {"type": "START_PRACTICE", "duration_minutes": 10},
                ["Start a 10-minute micro-sprint", "Pick one easy concept", "Eliminate phone distractions"],
            )

        # 5. Quiz request
        quiz_triggers = ("quiz me", "test me", "active recall", "practice questions", "give me a quiz", "test my knowledge", "ask me a question")
        if any(q in msg_lower for q in quiz_triggers):
            return (
                CoachingIntent.QUIZ_REQUEST,
                CoachingMode.QUIZ,
                {"type": "START_PRACTICE", "mode": "active_recall"},
                ["Answer the quiz question", "Give me a harder question", "Explain the concept first"],
            )

        # 6. Practice answer evaluation (if the previous coach message asked a question)
        if last_coach_msg and ("?" in last_coach_msg or "quiz" in last_coach_msg or "what is" in last_coach_msg or "which" in last_coach_msg):
            # If the user's message is a short answer or statement
            if len(msg_clean.split()) < 30 and not any(msg_lower.startswith(w) for w in ("what", "how", "why", "teach", "explain")):
                return (
                    CoachingIntent.PRACTICE_ANSWER,
                    CoachingMode.CHALLENGE,
                    None,
                    ["Next question", "Why does that work?", "Explain the edge case"],
                )

        # 7. Teach / Explanation request
        teach_triggers = ("teach me", "explain", "how does", "what is", "why is", "walk me through", "break down", "help me understand")
        if any(msg_lower.startswith(t) or f" {t} " in msg_lower for t in teach_triggers):
            return (
                CoachingIntent.TEACH_REQUEST,
                CoachingMode.EXPLAIN,
                None,
                ["Quiz me on this", "Give me a concrete example", "Explain in simpler terms"],
            )

        # 8. Progress / Stats
        progress_triggers = ("how am i doing", "how is my progress", "my performance", "my stats", "my focus score", "analyze my", "am i improving")
        if any(p in msg_lower for p in progress_triggers):
            return (
                CoachingIntent.PROGRESS_CHECK,
                CoachingMode.ANSWER,
                None,
                ["Plan my next study block", "Target areas with low focus", "Start active practice"],
            )

        # 9. Planning / Schedule
        planning_triggers = ("schedule", "timetable", "routine", "how many hours", "plan my day", "study plan", "roadmap")
        if any(p in msg_lower for p in planning_triggers):
            return (
                CoachingIntent.STUDY_PLANNING,
                CoachingMode.SUGGEST_ACTION,
                {"type": "START_STUDY_BLOCK", "duration_minutes": 45},
                ["Start 45m deep focus block", "Break down weekly roadmap", "Review course topics"],
            )

        # 10. Default General Concept or Query
        return (
            CoachingIntent.CONCEPT_QUESTION,
            CoachingMode.ANSWER,
            None,
            ["Quiz me on this", "Give me a real-world example", "Explain another topic"],
        )
