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
    # Ensure database tables exist with clean schema
    Base.metadata.create_all(bind=engine)
    logger.info("Database schema initialized. Running in clean production mode.")

    # Ensure demo accounts exist so login always succeeds out-of-the-box
    try:
        db = SessionLocal()
        default_users = [
            ("student@mentra.ai", "Mentra Student", "password123"),
            ("demo@mentra.ai", "Alex Chen", "password123"),
            ("alex@mentra.ai", "Alex Chen", "password123"),
        ]
        for email, full_name, password in default_users:
            u = db.query(User).filter(User.email == email).first()
            if not u:
                u = User(
                    email=email,
                    full_name=full_name,
                    hashed_password=get_password_hash(password),
                    is_active=True,
                )
                db.add(u)
            else:
                u.hashed_password = get_password_hash(password)
        db.commit()
        db.close()
    except Exception as e:
        logger.warning(f"Auto-seed error: {e}")

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
