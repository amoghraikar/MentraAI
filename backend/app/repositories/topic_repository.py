from typing import Sequence
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.topic import Topic
from app.schemas.topic import TopicCreate, TopicUpdate


class TopicRepository:
    def get_by_id(self, db: Session, topic_id: str) -> Topic | None:
        statement = select(Topic).where(Topic.id == topic_id)
        return db.scalars(statement).first()

    def get_all_by_subject(self, db: Session, subject_id: str) -> Sequence[Topic]:
        statement = (
            select(Topic)
            .where(Topic.subject_id == subject_id)
            .order_by(Topic.created_at.asc())
        )
        return db.scalars(statement).all()

    def create(self, db: Session, topic_in: TopicCreate) -> Topic:
        db_topic = Topic(
            subject_id=topic_in.subject_id,
            title=topic_in.title,
            description=topic_in.description,
            progress=topic_in.progress,
            total_minutes=topic_in.total_minutes,
            key_concepts=topic_in.key_concepts,
            notes_snippet=topic_in.notes_snippet,
            is_completed=topic_in.is_completed,
        )
        db.add(db_topic)
        db.commit()
        db.refresh(db_topic)
        return db_topic

    def update(self, db: Session, db_topic: Topic, topic_in: TopicUpdate) -> Topic:
        update_data = topic_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_topic, field, value)
        db.commit()
        db.refresh(db_topic)
        return db_topic

    def delete(self, db: Session, db_topic: Topic) -> None:
        db.delete(db_topic)
        db.commit()


topic_repository = TopicRepository()
