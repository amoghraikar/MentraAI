import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.dependencies import get_db
from app.db.base import Base
from app.main import app as fastapi_app
import app.db.session as db_session
import app.models  # noqa: F401 Ensure all models are registered in Base.metadata

TEST_DATABASE_URL = "sqlite:///:memory:"

engine_test = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine_test)


@pytest.fixture(autouse=True, scope="session")
def setup_test_db():
    Base.metadata.create_all(bind=engine_test)
    original_session_local = db_session.SessionLocal
    original_engine = db_session.engine
    db_session.SessionLocal = TestingSessionLocal
    db_session.engine = engine_test

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    fastapi_app.dependency_overrides[get_db] = override_get_db

    from app.api.v1.endpoints.ai_coach import ai_coach_service
    from app.services.ai.providers import HeuristicAiProvider
    original_provider = ai_coach_service.provider
    ai_coach_service.set_provider(HeuristicAiProvider())

    yield

    ai_coach_service.set_provider(original_provider)
    fastapi_app.dependency_overrides.clear()
    db_session.SessionLocal = original_session_local
    db_session.engine = original_engine
    Base.metadata.drop_all(bind=engine_test)
