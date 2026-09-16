"""
Development database seeding script for Mentra AI Study Coach.
Creates a demo user and initial study data (subjects, topics, notes, goals, sessions).
"""
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Add backend directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.security import get_password_hash
from app.db.session import SessionLocal
from app.models.goal import Goal, GoalMilestone
from app.models.note import Note
from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.user import User


def seed_database():
    db = SessionLocal()
    try:
        print("🌱 Seeding development database...")

        # 1. Create or get Demo User
        demo_email = "demo@mentra.ai"
        user = db.query(User).filter(User.email == demo_email).first()
        if not user:
            user = User(
                email=demo_email,
                full_name="Alex Chen",
                hashed_password=get_password_hash("password123"),
                is_active=True,
            )
            db.add(user)
            db.flush()
            print(f"  ✓ Created demo user: {user.email} (password: password123)")
        else:
            print(f"  ✓ Demo user already exists: {user.email}")

        # 2. Create Subjects & Topics
        subjects_data = [
            {
                "title": "Data Analytics",
                "code": "DA-301",
                "description": "Exploratory data analysis, statistical modeling, and predictive analytics.",
                "color_hex": "#3B82F6",
                "target_hours": 24.0,
                "total_hours": 12.5,
                "topics": [
                    {
                        "title": "Correlation Analysis",
                        "description": "Pearson, Spearman, and Kendall rank correlation metrics.",
                        "progress": 1.0,
                        "total_minutes": 180,
                        "key_concepts": ["Pearson coefficient", "Scatter matrices", "P-values"],
                        "notes_snippet": "Correlation does not imply causation.",
                        "is_completed": True,
                    },
                    {
                        "title": "Linear & Logistic Regression",
                        "description": "Ordinary least squares, gradient descent, sigmoid functions.",
                        "progress": 0.75,
                        "total_minutes": 240,
                        "key_concepts": ["Residual sum of squares", "Log-odds", "Confusion matrix"],
                        "notes_snippet": "Ensure feature scaling before training.",
                        "is_completed": False,
                    },
                    {
                        "title": "Probability Distributions",
                        "description": "Normal, Binomial, Poisson, and Exponential distributions.",
                        "progress": 0.40,
                        "total_minutes": 120,
                        "key_concepts": ["PDF", "CDF", "Central Limit Theorem"],
                        "notes_snippet": "CLT applies when sample size n >= 30.",
                        "is_completed": False,
                    },
                ],
            },
            {
                "title": "Software Engineering",
                "code": "CS-401",
                "description": "Design patterns, architecture, system design, and testing.",
                "color_hex": "#10B981",
                "target_hours": 30.0,
                "total_hours": 18.0,
                "topics": [
                    {
                        "title": "Microservices Architecture",
                        "description": "Decoupled services, event-driven architecture, API gateways.",
                        "progress": 0.85,
                        "total_minutes": 310,
                        "key_concepts": ["Service Mesh", "Saga Pattern", "CQRS"],
                        "notes_snippet": "Use sagas for distributed transactions.",
                        "is_completed": False,
                    },
                    {
                        "title": "Database Indexing & Optimization",
                        "description": "B-Trees, Hash indexes, query plan inspection, vacuuming.",
                        "progress": 1.0,
                        "total_minutes": 220,
                        "key_concepts": ["Composite Index", "EXPLAIN ANALYZE", "Covering Index"],
                        "notes_snippet": "Always inspect EXPLAIN plans for sequential scans.",
                        "is_completed": True,
                    },
                ],
            },
        ]

        created_subjects = []
        for s_data in subjects_data:
            existing_sub = (
                db.query(Subject)
                .filter(Subject.user_id == user.id, Subject.code == s_data["code"])
                .first()
            )
            if not existing_sub:
                new_sub = Subject(
                    user_id=user.id,
                    title=s_data["title"],
                    code=s_data["code"],
                    description=s_data["description"],
                    color_hex=s_data["color_hex"],
                    total_hours=s_data["total_hours"],
                    target_hours=s_data["target_hours"],
                )
                db.add(new_sub)
                db.flush()

                for t_data in s_data["topics"]:
                    new_topic = Topic(
                        subject_id=new_sub.id,
                        title=t_data["title"],
                        description=t_data["description"],
                        progress=t_data["progress"],
                        total_minutes=t_data["total_minutes"],
                        key_concepts=t_data["key_concepts"],
                        notes_snippet=t_data["notes_snippet"],
                        is_completed=t_data["is_completed"],
                    )
                    db.add(new_topic)

                created_subjects.append(new_sub)
                print(f"  ✓ Created subject: {new_sub.title} ({new_sub.code})")
            else:
                created_subjects.append(existing_sub)

        db.commit()

        # 3. Create Demo Notes
        if created_subjects:
            first_sub = created_subjects[0]
            existing_notes = db.query(Note).filter(Note.user_id == user.id).count()
            if existing_notes == 0:
                demo_notes = [
                    Note(
                        user_id=user.id,
                        subject_id=first_sub.id,
                        title="Key Theorems in Linear Regression",
                        content="Gauss-Markov Theorem asserts that under certain conditions OLS estimator is BLUE (Best Linear Unbiased Estimator).",
                        tags=["Statistics", "ML", "Regression"],
                    ),
                    Note(
                        user_id=user.id,
                        subject_id=first_sub.id,
                        title="Data Cleansing Checklist",
                        content="1. Check for null values\n2. Detect outliers with IQR\n3. One-hot encode categorical features.",
                        tags=["Data Prep", "Cheatsheet"],
                    ),
                ]
                db.add_all(demo_notes)
                print("  ✓ Created demo study notes")

        # 4. Create Demo Goals
        if created_subjects:
            first_sub = created_subjects[0]
            existing_goals = db.query(Goal).filter(Goal.user_id == user.id).count()
            if existing_goals == 0:
                goal = Goal(
                    user_id=user.id,
                    subject_id=first_sub.id,
                    title="Master Regression & Classification",
                    target_date=datetime.now(timezone.utc) + timedelta(days=14),
                    is_completed=False,
                )
                db.add(goal)
                db.flush()

                milestones = [
                    GoalMilestone(goal_id=goal.id, title="Complete 10 hours of study", is_completed=True),
                    GoalMilestone(goal_id=goal.id, title="Implement logistic regression from scratch", is_completed=True),
                    GoalMilestone(goal_id=goal.id, title="Score 90%+ on mock exam", is_completed=False),
                ]
                db.add_all(milestones)
                print("  ✓ Created demo goals and milestones")

        # 5. Create Demo Study Session
        if created_subjects:
            first_sub = created_subjects[0]
            existing_sessions = db.query(StudySession).filter(StudySession.user_id == user.id).count()
            if existing_sessions == 0:
                now = datetime.now(timezone.utc)
                session = StudySession(
                    user_id=user.id,
                    subject_id=first_sub.id,
                    target_duration_minutes=45,
                    actual_duration_minutes=45,
                    study_mode="Focus Mode",
                    is_focus_monitoring_enabled=True,
                    focus_score=92,
                    distractions_count=2,
                    reflection="excellent",
                    started_at=now - timedelta(minutes=50),
                    ended_at=now - timedelta(minutes=5),
                )
                db.add(session)
                print("  ✓ Created demo study session")

        db.commit()
        print("✅ Database seeding completed successfully!")
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
