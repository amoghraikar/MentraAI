from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.topic import Topic
from app.repositories.subject_repository import subject_repository
from app.repositories.topic_repository import topic_repository
from app.schemas.topic import TopicCreate, TopicUpdate


class TopicService:
    def get_topics_by_subject(
        self, db: Session, subject_id: str, user_id: str
    ) -> Sequence[Topic]:
        subject = subject_repository.get_by_id(db, subject_id=subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found.",
            )
        return topic_repository.get_all_by_subject(db, subject_id=subject_id)

    def get_topic_by_id(self, db: Session, topic_id: str, user_id: str) -> Topic:
        topic = topic_repository.get_by_id(db, topic_id=topic_id)
        if not topic:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Topic not found.",
            )
        subject = subject_repository.get_by_id(db, subject_id=topic.subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Topic not found or access denied.",
            )
        return topic

    def create_topic(self, db: Session, user_id: str, topic_in: TopicCreate) -> Topic:
        subject = subject_repository.get_by_id(db, subject_id=topic_in.subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found or access denied.",
            )
        return topic_repository.create(db, topic_in=topic_in)

    def update_topic(
        self, db: Session, topic_id: str, user_id: str, topic_in: TopicUpdate
    ) -> Topic:
        topic = self.get_topic_by_id(db, topic_id=topic_id, user_id=user_id)
        return topic_repository.update(db, db_topic=topic, topic_in=topic_in)

    def delete_topic(self, db: Session, topic_id: str, user_id: str) -> None:
        topic = self.get_topic_by_id(db, topic_id=topic_id, user_id=user_id)
        topic_repository.delete(db, db_topic=topic)


topic_service = TopicService()
