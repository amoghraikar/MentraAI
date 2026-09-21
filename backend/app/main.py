import asyncio
from contextlib import asynccontextmanager
import logging
from typing import Optional
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func, select

from app.api.v1.endpoints.health import HealthResponse
from app.api.v1.router import api_router
from app.core.config import settings
from app.db.base import Base
import app.models  # noqa: F401
from app.db.session import SessionLocal, engine
from app.models.user import User
from app.services.ai.local_llm import local_llm_engine

logger = logging.getLogger("mentra.main")


async def _warmup_local_llm() -> None:
    """Load the local model into memory in the background at startup."""
    try:
        warmed = await local_llm_engine.warmup()
        if warmed:
            logger.info("Local LLM ready for the first request (no cold start).")
        else:
            logger.warning(
                "Local LLM warm-up incomplete; the first request will load the model."
            )
    except Exception as e:  # pragma: no cover - defensive
        logger.warning("Local LLM warm-up failed: %s", e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure database tables exist with a clean schema
    Base.metadata.create_all(bind=engine)
    logger.info("Database schema initialized.")

    # Report the accounts that actually exist. Mentra never invents accounts or
    # rewrites stored credentials on boot: overwriting hashes here previously
    # reset real users' passwords to a shared demo value on every restart.
    try:
        db = SessionLocal()
        user_count = db.query(func.count(User.id)).scalar() or 0
        db.close()
        logger.info("Registered user accounts: %d", user_count)
    except Exception as e:
        logger.warning("Could not read user count at startup: %s", e)

    # Warm the local model so the AI coach answers on the first try.
    warmup_task: Optional[asyncio.Task] = None
    if settings.LOCAL_LLM_WARMUP_ON_STARTUP:
        warmup_task = asyncio.create_task(_warmup_local_llm())
        app.state.local_llm_warmup_task = warmup_task

    yield

    if warmup_task is not None and not warmup_task.done():
        warmup_task.cancel()


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
