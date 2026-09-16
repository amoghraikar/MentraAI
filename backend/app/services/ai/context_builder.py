from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.goal import Goal
from app.models.note import Note
from app.models.study_session import StudySession


class ContextBuilder:
    """
    Builds token-bounded, sanitized study context for the AI Coach.
    Guarantees user isolation and minimizes data exposure.
    """

    @staticmethod
    def build_user_study_context(
        db: Session,
        user_id: str,
        subject_id: Optional[str] = None,
        topic_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        context: Dict[str, Any] = {
            "current_subject": None,
            "current_topic": None,
            "recent_sessions_summary": [],
            "active_goals": [],
            "key_notes_snippets": [],
        }

        # 1. Subject & Topic Context if provided
        if subject_id:
            subject = db.query(Subject).filter(Subject.id == subject_id, Subject.user_id == user_id).first()
            if subject:
                context["current_subject"] = {"id": subject.id, "title": subject.title}

        if topic_id:
            topic = db.query(Topic).filter(Topic.id == topic_id).first()
            if topic:
                context["current_topic"] = {"id": topic.id, "title": topic.title}

        # 2. Recent 5 Study Sessions (Duration, Focus Score, Distractions)
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

        # 3. Active Goals (Top 3)
        goals = db.query(Goal).filter(Goal.user_id == user_id).limit(3).all()
        context["active_goals"] = [
            {"title": g.title, "progress_percentage": g.progress_percentage}
            for g in goals
        ]

        # 4. Truncated Note Snippets (Max 3 notes, first 120 chars each to prevent token bloat)
        notes = db.query(Note).filter(Note.user_id == user_id).limit(3).all()
        context["key_notes_snippets"] = [
            {
                "title": n.title,
                "snippet": (n.content[:120] + "...") if len(n.content) > 120 else n.content,
            }
            for n in notes
        ]

        return context

    @staticmethod
    def format_context_for_prompt(context: Dict[str, Any]) -> str:
        """Serializes context dictionary into a concise text block for prompt injection."""
        lines: List[str] = []

        if context.get("current_subject"):
            lines.append(f"Active Subject: {context['current_subject']['title']}")
        if context.get("current_topic"):
            lines.append(f"Active Topic: {context['current_topic']['title']}")

        goals = context.get("active_goals", [])
        if goals:
            goal_strs = [f"{g['title']} ({g['progress_percentage']}%)" for g in goals]
            lines.append(f"Active Goals: {', '.join(goal_strs)}")

        recent_sessions = context.get("recent_sessions_summary", [])
        if recent_sessions:
            avg_score = sum(s["focus_score"] for s in recent_sessions) // len(recent_sessions)
            lines.append(f"Recent Study Average Focus Score: {avg_score}/100 across {len(recent_sessions)} sessions.")

        return "\n".join(lines) if lines else "General Study Context"
