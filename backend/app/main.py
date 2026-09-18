from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.api.v1.endpoints.health import HealthResponse
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.security import get_password_hash
from app.db.base import Base
import app.models  # noqa: F401
from app.db.session import SessionLocal, engine
from app.models.user import User

logger = logging.getLogger("mentra.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure tables exist
    Base.metadata.create_all(bind=engine)

    # Seed default demo student if database is fresh
    db = SessionLocal()
    try:
        existing_user = db.scalars(
            select(User).where(User.email == "student@mentra.ai")
        ).first()
        if not existing_user:
            demo_user = User(
                email="student@mentra.ai",
                full_name="Mentra Student",
                hashed_password=get_password_hash("Password123!"),
                is_active=True,
            )
            db.add(demo_user)
            db.commit()
            logger.info("Default user student@mentra.ai created.")
    except Exception as e:
        logger.warning("Could not seed default user: %s", e)
        db.rollback()
    finally:
        db.close()

    yield


app = FastAPI(
    title="Mentra API",
    description="Backend API for Mentra AI Study Coach",
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS middleware configuration
origins = settings.CORS_ORIGINS
if isinstance(origins, str):
    origins = [origins]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse, tags=["health"])
async def root_health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="mentra-api",
        version=settings.VERSION,
    )


# Include API v1 router
app.include_router(api_router, prefix="/api/v1")
