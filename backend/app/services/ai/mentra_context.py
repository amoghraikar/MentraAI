"""
MentraContext — Dedicated Study Context Engine for Mentra AI.

Maintains verified student and session context:
- current_subject
- current_topic
- current_goal
- difficulty_level
- current_study_session
- recent_performance
- recent_mistakes
- relevant_notes
- session_duration
- preparation for future CV signals (focus_state, distraction_events, drowsiness_events, phone_detected, session_interruptions)

Strict Context Priority:
1. Current user message
2. Immediate conversation history
3. Current study topic
4. Active study session
5. Relevant student information
6. Older conversation context
"""

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.goal import Goal
from app.models.note import Note
from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.user import User


@dataclass
class MentraContext:
    current_subject: Optional[str] = None
    current_topic: Optional[str] = None
    current_goal: Optional[str] = None
    difficulty_level: str = "INTERMEDIATE"  # BEGINNER, INTERMEDIATE, ADVANCED
    is_session_active: bool = False
    session_elapsed_minutes: Optional[int] = None
    session_target_minutes: Optional[int] = None
    current_study_session: Optional[Dict[str, Any]] = None
    recent_performance: Optional[Dict[str, Any]] = None
    recent_mistakes: List[str] = field(default_factory=list)
    relevant_notes: List[str] = field(default_factory=list)
    session_duration: Optional[int] = None

    # Future CV signals preparation (None unless explicitly provided, never fabricated)
    focus_state: Optional[str] = None
    distraction_events: Optional[int] = None
    drowsiness_events: Optional[int] = None
    phone_detected: Optional[bool] = None
    session_interruptions: Optional[int] = None

    # Context tracking metadata
    active_conversation_id: Optional[str] = None
    learning_objective: Optional[str] = None
    conversation_summary: Optional[str] = None
    detected_intent: str = "GENERAL"
    is_confused: bool = False
    needs_hint: bool = False
    hint_level: int = 0
    is_practice_mode: bool = False

    @property
    def subject_title(self) -> Optional[str]:
        return self.current_subject

    @property
    def topic_title(self) -> Optional[str]:
        return self.current_topic

    @property
    def study_goal(self) -> Optional[str]:
        return self.current_goal

    @property
    def elapsed_minutes(self) -> Optional[int]:
        return self.session_elapsed_minutes

    @property
    def target_duration_minutes(self) -> Optional[int]:
        return self.session_target_minutes

    @property
    def focus_score(self) -> Optional[int]:
        if self.current_study_session and "focus_score" in self.current_study_session:
            return self.current_study_session["focus_score"]
        return None

    @property
    def total_sessions_completed(self) -> int:
        return self.recent_performance.get("sessions_count", 0) if self.recent_performance else 0

    @property
    def total_study_minutes(self) -> int:
        return self.recent_performance.get("total_minutes", 0) if self.recent_performance else 0

    @property
    def average_focus_score(self) -> Optional[float]:
        return self.recent_performance.get("avg_focus_score") if self.recent_performance else None

    @classmethod
    def create_from_db_and_session(
        cls,
        db: Optional[Session],
        user_id: Optional[str],
        subject_id: Optional[str] = None,
        topic_id: Optional[str] = None,
        active_session_id: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
        current_message: str = "",
        subject_title: Optional[str] = None,
        topic_title: Optional[str] = None,
        study_goal: Optional[str] = None,
        elapsed_minutes: Optional[int] = None,
        target_duration_minutes: Optional[int] = None,
        is_session_active: Optional[bool] = None,
        focus_score: Optional[int] = None,
    ) -> "MentraContext":
        """
        Constructs a MentraContext instance with real student data from DB and active app state,
        strictly avoiding any fabricated values.
        """
        context = cls()
        context.update_from_conversation(history or [], current_message)

        # 1. Directly apply active study state from app if supplied
        if is_session_active is not None:
            context.is_session_active = is_session_active
        elif active_session_id is not None:
            context.is_session_active = True

        if subject_title:
            context.current_subject = subject_title
        if topic_title:
            context.current_topic = topic_title
        if study_goal:
            context.current_goal = study_goal
        if elapsed_minutes is not None:
            context.session_elapsed_minutes = elapsed_minutes
            context.session_duration = elapsed_minutes
        if target_duration_minutes is not None:
            context.session_target_minutes = target_duration_minutes
        if focus_score is not None:
            if context.current_study_session is None:
                context.current_study_session = {}
            context.current_study_session["focus_score"] = focus_score

        if not db or not user_id:
            return context

        try:
            # 2. Subject & Topic from DB if not already set
            if subject_id and not context.current_subject:
                sub = db.query(Subject).filter(Subject.id == subject_id, Subject.user_id == user_id).first()
                if sub:
                    context.current_subject = sub.title

            if topic_id and not context.current_topic:
                top = db.query(Topic).filter(Topic.id == topic_id).first()
                if top:
                    context.current_topic = top.title

            # 3. Active Session from DB if active_session_id provided
            if active_session_id:
                sess = db.query(StudySession).filter(
                    StudySession.id == active_session_id,
                    StudySession.user_id == user_id,
                ).first()
                if sess:
                    context.is_session_active = True
                    context.current_study_session = {
                        "session_id": sess.id,
                        "target_minutes": sess.target_duration_minutes,
                        "actual_minutes": sess.actual_duration_minutes,
                        "focus_score": sess.focus_score,
                        "distractions_count": sess.distractions_count,
                        "study_mode": sess.study_mode,
                    }
                    if context.session_elapsed_minutes is None:
                        context.session_elapsed_minutes = sess.actual_duration_minutes
                        context.session_duration = sess.actual_duration_minutes
                    if context.session_target_minutes is None:
                        context.session_target_minutes = sess.target_duration_minutes
                    if not context.current_subject and sess.subject:
                        context.current_subject = sess.subject.title
                    if not context.current_topic and sess.topic:
                        context.current_topic = sess.topic.title

            # 4. Active Goals from DB
            active_goals = db.query(Goal).filter(Goal.user_id == user_id).limit(3).all()
            if active_goals and not context.current_goal:
                top_goal = active_goals[0]
                context.current_goal = f"{top_goal.title} ({top_goal.progress_percentage}% completed)"

            # 5. Real Recent Performance from DB
            past_sessions = (
                db.query(StudySession)
                .filter(StudySession.user_id == user_id)
                .order_by(desc(StudySession.created_at))
                .limit(5)
                .all()
            )
            if past_sessions:
                avg_score = sum(s.focus_score for s in past_sessions) // len(past_sessions)
                total_mins = sum(s.actual_duration_minutes for s in past_sessions)
                context.recent_performance = {
                    "sessions_count": len(past_sessions),
                    "total_minutes": total_mins,
                    "avg_focus_score": avg_score,
                    "latest_reflection": past_sessions[0].reflection if past_sessions else "good",
                }
            else:
                context.recent_performance = None

            # 6. Relevant Notes (max 2 snippets)
            notes = db.query(Note).filter(Note.user_id == user_id).limit(2).all()
            if notes:
                context.relevant_notes = [
                    f"{n.title}: {n.content[:100]}..." if len(n.content) > 100 else f"{n.title}: {n.content}"
                    for n in notes
                ]
        except Exception:
            pass

        return context

    def update_from_conversation(
        self,
        history: List[Dict[str, str]],
        current_message: str,
    ) -> None:
        """
        Infers conversational subject/topic, student level, confusion,
        and practice/hint state from conversation history and user input.
        """
        msg_clean = current_message.strip()
        msg_lower = msg_clean.lower()

        # 1. Level Detection
        beginner_triggers = (
            "beginner", "like i'm 10", "like im 10", "like i'm 5", "like im 5",
            "from scratch", "basics", "simple", "simpler", "fundamentals",
            "complete beginner", "never coded", "brand new"
        )
        advanced_triggers = (
            "advanced", "deep dive", "under the hood", "internals", "time complexity",
            "derivation", "proof", "asymptotics", "in-depth", "expert"
        )
        if any(b in msg_lower for b in beginner_triggers):
            self.difficulty_level = "BEGINNER"
        elif any(a in msg_lower for a in advanced_triggers):
            self.difficulty_level = "ADVANCED"

        confusion_triggers = (
            "i don't get it", "i dont get it", "i'm lost", "im lost", "completely lost",
            "i don't understand", "i dont understand", "what?", "why?", "lost",
            "this makes no sense", "makes no sense", "bro i don't understand",
            "bro i dont understand", "can you explain that again", "still confused",
            "i'm confused", "im confused", "lost me", "not getting it", "too hard"
        )
        if any(c in msg_lower for c in confusion_triggers):
            self.is_confused = True
            self.detected_intent = "CONFUSION"

        # 3. Practice Request Detection
        practice_triggers = (
            "quiz me", "give me a question", "test me", "practice",
            "ask me a question", "give me a problem", "challenge me",
            "give me another one", "another question"
        )
        if any(p in msg_lower for p in practice_triggers):
            self.is_practice_mode = True
            self.detected_intent = "PRACTICE_REQUEST"

        # 4. Hint Request Detection
        hint_triggers = ("i don't know", "i dont know", "hint", "give me a hint", "not sure", "no idea", "stuck")
        if any(h in msg_lower for h in hint_triggers):
            self.needs_hint = True
            self.hint_level += 1
            self.detected_intent = "HINT_REQUEST"

        # 5. Topic Continuity & Domain Inference
        subject_patterns = {
            "DSA": [r"\bdsa\b", r"data structures", r"algorithms"],
            "DBMS": [r"\bdbms\b", r"database", r"sql\b", r"normalization"],
            "Operating Systems": [r"\bos\b", r"operating system", r"threads", r"deadlock"],
            "Machine Learning": [r"\bml\b", r"machine learning", r"neural network", r"deep learning"],
            "Python": [r"\bpython\b"],
        }
        for subj, patterns in subject_patterns.items():
            if any(re.search(pat, msg_lower) for pat in patterns):
                self.current_subject = subj
                break

        # Check history for subject if not mentioned in current message
        if not self.current_subject:
            for item in reversed(history):
                content = item.get("content", "").lower()
                for subj, patterns in subject_patterns.items():
                    if any(re.search(pat, content) for pat in patterns):
                        self.current_subject = subj
                        break
                if self.current_subject:
                    break

        # Canonical Topic Map
        topic_keywords = {
            "arrays": "Arrays",
            "array": "Arrays",
            "linked list": "Linked Lists",
            "linked lists": "Linked Lists",
            "stack": "Stack",
            "queue": "Queue",
            "trees": "Trees",
            "tree": "Trees",
            "binary tree": "Binary Tree",
            "graph": "Graph",
            "graphs": "Graph",
            "recursion": "Recursion",
            "dynamic programming": "Dynamic Programming",
            "sorting": "Sorting",
            "quicksort": "Quicksort",
            "mergesort": "Mergesort",
            "binary search": "Binary Search",
            "normalization": "Normalization",
            "indexing": "Indexing",
            "joins": "Joins",
            "transactions": "Transactions",
            "acid": "ACID",
            "pointers": "Pointers",
            "memory allocation": "Memory Allocation",
            "functions": "Functions",
            "oop": "OOP",
            "classes": "Classes",
        }
        for top_term, top_name in topic_keywords.items():
            if re.search(r"\b" + re.escape(top_term) + r"\b", msg_lower):
                self.current_topic = top_name
                break

        # Check for pronoun resolution ("them", "it", "they", "this") based on previous turns
        if (any(pronoun in msg_lower.split() for pronoun in ("them", "it", "they", "this")) or not self.current_topic):
            for item in reversed(history):
                content = item.get("content", "").lower()
                for top_term, top_name in topic_keywords.items():
                    if re.search(r"\b" + re.escape(top_term) + r"\b", content):
                        if not self.current_topic or any(pronoun in msg_lower.split() for pronoun in ("them", "it", "they", "this")):
                            self.current_topic = top_name
                        break
                if self.current_topic:
                    break

    def format_for_prompt(self, current_user_message: str = "") -> str:
        """
        Formats context applying the strict Context Priority rules:
        1. Current user message (highest priority)
        2. Immediate conversation history
        3. Current study topic
        4. Active study session
        5. Relevant student information
        6. Older conversation context
        """
        sections: List[str] = []

        # 1. Active Focus & Topic Context
        topic_info = []
        if self.current_subject:
            topic_info.append(f"Subject: {self.current_subject}")
        if self.current_topic:
            topic_info.append(f"Current Topic: {self.current_topic}")
        if self.difficulty_level:
            topic_info.append(f"Inferred Learner Level: {self.difficulty_level}")

        if topic_info:
            sections.append(f"[STUDY TOPIC FOCUS]: {' | '.join(topic_info)}")

        # 2. Pedagogical Directives based on State
        directives = []
        if self.is_confused:
            directives.append(
                "STUDENT CONFUSION DETECTED: Do NOT repeat the previous explanation. "
                "Break down the topic using a simple real-world analogy, eliminate jargon, "
                "and explain from first principles."
            )
        if self.is_practice_mode:
            directives.append(
                f"PRACTICE MODE ACTIVE: Present ONE targeted practice question on {self.current_topic or 'the current concept'}. "
                "Keep it clear and approachable. Wait for the student's answer."
            )
        if self.needs_hint:
            directives.append(
                f"HINT REQUEST (Level {self.hint_level}): Do NOT reveal the full answer immediately. "
                "Provide a gentle, progressive guiding clue or hint to help them reason it out."
            )
        if directives:
            sections.append("[ACTIVE INTERACTION DIRECTIVE]:\n" + "\n".join(directives))

        # 3. Active Study Session (if active)
        if self.is_session_active or self.current_study_session:
            elapsed = self.session_elapsed_minutes if self.session_elapsed_minutes is not None else (self.current_study_session.get('actual_minutes', 0) if self.current_study_session else 0)
            target = self.session_target_minutes if self.session_target_minutes is not None else (self.current_study_session.get('target_minutes', 45) if self.current_study_session else 45)
            session_lines = [
                f"Status: Actively Studying",
                f"Active Subject: {self.current_subject or 'General Studies'}",
                f"Active Topic: {self.current_topic or 'Core Concepts'}",
                f"Session Timer: {elapsed} minutes elapsed (Target: {target} minutes)",
            ]
            if self.current_goal:
                session_lines.append(f"Active Goal: {self.current_goal}")
            sections.append("[ACTIVE STUDY SESSION]:\n" + "\n".join(session_lines))

        # 4. Relevant Student Performance & Goals (if real data exists)
        if self.recent_performance:
            p = self.recent_performance
            sections.append(
                f"[STUDY HISTORY & PERFORMANCE]: {p.get('sessions_count', 0)} completed sessions on record | "
                f"{p.get('total_minutes', 0)} total study minutes | {p.get('avg_focus_score', 0)}% average focus score"
            )
        else:
            sections.append("[STUDY HISTORY]: No previous recorded sessions. If asked, acknowledge you don't have past study data yet.")

        if self.current_goal and not (self.is_session_active or self.current_study_session):
            sections.append(f"[STUDY GOAL]: {self.current_goal}")

        if self.relevant_notes:
            sections.append("[RELEVANT STUDENT NOTES]:\n" + "\n".join(self.relevant_notes))

        # 5. Priority override rule
        sections.append(
            "[CONTEXT PRIORITY RULE]: The student's current message always takes priority. "
            "If the student shifts to a new question or topic, answer the new request directly without forcing prior context."
        )

        return "\n\n".join(sections)
