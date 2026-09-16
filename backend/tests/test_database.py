import uuid
from datetime import datetime, timezone
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.goal import Goal, GoalMilestone
from app.models.note import Note
from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.user import User


def test_database_connection_and_models():
    db = SessionLocal()
    try:
        # Create user
        uid = str(uuid.uuid4())
        user = User(
            id=uid,
            email=f"dbtest_{uid[:8]}@mentra.ai",
            full_name="DB Tester",
            hashed_password="hashed_secret",
            is_active=True,
        )
        db.add(user)
        db.flush()

        # Create subject
        subject = Subject(
            user_id=user.id,
            title="Advanced Machine Learning",
            code="CS-501",
            description="Deep Learning and Neural Nets",
            color_hex="#8B5CF6",
            total_hours=5.0,
            target_hours=40.0,
        )
        db.add(subject)
        db.flush()

        # Create topic
        topic = Topic(
            subject_id=subject.id,
            title="Convolutional Neural Networks",
            description="Kernels, pooling, backpropagation",
            progress=0.5,
            total_minutes=90,
            key_concepts=["Conv2D", "Pooling", "Stride"],
            notes_snippet="Kernels extract spatial features.",
            is_completed=False,
        )
        db.add(topic)
        db.flush()

        # Create note
        note = Note(
            user_id=user.id,
            subject_id=subject.id,
            topic_id=topic.id,
            title="CNN Architecture Notes",
            content="AlexNet, VGG, ResNet skip connections.",
            tags=["ML", "Vision", "Deep Learning"],
        )
        db.add(note)
        db.flush()

        # Create goal with milestone
        goal = Goal(
            user_id=user.id,
            subject_id=subject.id,
            title="Pass DL Certification",
            target_date=datetime.now(timezone.utc),
            is_completed=False,
        )
        db.add(goal)
        db.flush()

        milestone = GoalMilestone(
            goal_id=goal.id,
            title="Complete assignments 1-4",
            is_completed=False,
        )
        db.add(milestone)
        db.flush()

        # Create study session
        now = datetime.now(timezone.utc)
        session_rec = StudySession(
            user_id=user.id,
            subject_id=subject.id,
            topic_id=topic.id,
            target_duration_minutes=45,
            actual_duration_minutes=45,
            study_mode="Focus Mode",
            is_focus_monitoring_enabled=True,
            focus_score=95,
            distractions_count=1,
            reflection="excellent",
            started_at=now,
            ended_at=now,
        )
        db.add(session_rec)
        db.commit()

        # Verify query and relationships
        queried_user = db.scalars(select(User).where(User.id == user.id)).first()
        assert queried_user is not None
        assert len(queried_user.subjects) == 1
        assert queried_user.subjects[0].title == "Advanced Machine Learning"
        assert len(queried_user.subjects[0].topics) == 1
        assert queried_user.subjects[0].topics[0].title == "Convolutional Neural Networks"
        assert len(queried_user.notes) == 1
        assert len(queried_user.goals) == 1
        assert len(queried_user.goals[0].milestones) == 1
        assert len(queried_user.study_sessions) == 1

        # Test cascading deletion of user
        db.delete(queried_user)
        db.commit()

        # Ensure all associated entities are deleted via CASCADE
        assert db.scalars(select(Subject).where(Subject.id == subject.id)).first() is None
        assert db.scalars(select(Topic).where(Topic.id == topic.id)).first() is None
        assert db.scalars(select(Note).where(Note.id == note.id)).first() is None
        assert db.scalars(select(Goal).where(Goal.id == goal.id)).first() is None
        assert db.scalars(select(GoalMilestone).where(GoalMilestone.id == milestone.id)).first() is None
        assert db.scalars(select(StudySession).where(StudySession.id == session_rec.id)).first() is None

    finally:
        db.close()
