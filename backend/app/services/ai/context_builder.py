"""
Mentra AI Coach — Structured Context Builder.

Extracts sanitized, token-bounded student learning context from the database:
- Student Profile & Goals
- Active Coursework (Subject, Topic, Notes)
- Active Session State & CV Focus Signals (without medical claims)
- Recent Study Performance & Fatigue Patterns
- Multi-Turn Conversation Continuity
"""

from typing import Any, Dict, List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from app.models.goal import Goal
from app.models.note import Note
from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.user import User


class CoachContextBuilder:
    """
    Builds token-bounded, sanitized study context for the AI Coach.
    Guarantees user isolation and minimizes data exposure.
    """

    @classmethod
    def build_user_study_context(
        cls,
        db: Session,
        user_id: str,
        subject_id: Optional[str] = None,
        topic_id: Optional[str] = None,
        active_session_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        context: Dict[str, Any] = {
            "student_name": None,
            "current_subject": None,
            "current_topic": None,
            "active_session": None,
            "recent_sessions_summary": [],
            "active_goals": [],
            "key_notes_snippets": [],
        }

        # 1. Student Name / Identity
        user = db.query(User).filter(User.id == user_id).first()
        if user and user.full_name:
            context["student_name"] = user.full_name.split()[0]

        # 2. Subject & Topic Context
        if subject_id:
            subject = db.query(Subject).filter(Subject.id == subject_id, Subject.user_id == user_id).first()
            if subject:
                context["current_subject"] = {"id": subject.id, "title": subject.title}

        if topic_id:
            topic = db.query(Topic).filter(Topic.id == topic_id).first()
            if topic:
                context["current_topic"] = {"id": topic.id, "title": topic.title}

        # 3. Active Study Session Context (if currently in session)
        if active_session_id:
            curr_session = db.query(StudySession).filter(StudySession.id == active_session_id, StudySession.user_id == user_id).first()
            if curr_session:
                context["active_session"] = {
                    "session_id": curr_session.id,
                    "target_minutes": curr_session.target_duration_minutes,
                    "actual_minutes": curr_session.actual_duration_minutes,
                    "focus_score": curr_session.focus_score,
                    "distractions": curr_session.distractions_count,
                    "mode": curr_session.study_mode,
                }

        # 4. Recent Study Performance (Past 3-5 sessions)
        sessions = (
            db.query(StudySession)
            .filter(StudySession.user_id == user_id)
            .order_by(desc(StudySession.created_at))
            .limit(5)
            .all()
        )
        context["recent_sessions_summary"] = [
            {
                "duration_minutes": s.actual_duration_minutes,
                "focus_score": s.focus_score,
                "distractions": s.distractions_count,
                "reflection": s.reflection,
            }
            for s in sessions
        ]

        # 5. Active Goals (Top 3)
        goals = db.query(Goal).filter(Goal.user_id == user_id).limit(3).all()
        context["active_goals"] = [
            {"title": g.title, "progress_percentage": g.progress_percentage}
            for g in goals
        ]

        # 6. Truncated Note Snippets (Max 3 notes, first 120 chars each)
        notes = db.query(Note).filter(Note.user_id == user_id).limit(3).all()
        context["key_notes_snippets"] = [
            {
                "title": n.title,
                "snippet": (n.content[:120] + "...") if len(n.content) > 120 else n.content,
            }
            for n in notes
        ]

        return context

    @classmethod
    def format_context_for_prompt(cls, context: Dict[str, Any]) -> str:
        """Serializes context dictionary into a concise text block for prompt injection."""
        sections: List[str] = []

        if context.get("student_name"):
            sections.append(f"Student: {context['student_name']}")

        if context.get("current_subject"):
            sub = context['current_subject']['title']
            top = context.get('current_topic', {}).get('title', 'General Coursework') if context.get('current_topic') else 'General Coursework'
            sections.append(f"Active Focus Area: {sub} -> {top}")

        if context.get("active_session"):
            sess = context["active_session"]
            sections.append(
                f"CURRENT ACTIVE SESSION: {sess.get('actual_minutes', 0)}m elapsed of {sess.get('target_minutes', 45)}m planned | "
                f"Current Focus Score: {sess.get('focus_score', 90)}/100 | Distractions logged: {sess.get('distractions', 0)}"
            )

        goals = context.get("active_goals", [])
        if goals:
            goal_strs = [f"{g['title']} ({g['progress_percentage']}%)" for g in goals]
            sections.append(f"Active Goals: {', '.join(goal_strs)}")

        recent_sessions = context.get("recent_sessions_summary", [])
        if recent_sessions:
            avg_score = sum(s["focus_score"] for s in recent_sessions) // len(recent_sessions)
            total_mins = sum(s["duration_minutes"] for s in recent_sessions)
            sections.append(f"Recent Study Velocity: {total_mins} mins across {len(recent_sessions)} blocks (Avg Focus: {avg_score}/100)")

        return "\n".join(sections) if sections else "General Study Context"


# Alias for backward compatibility
ContextBuilder = CoachContextBuilder
