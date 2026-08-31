from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.router import api_router
from app.api.v1.endpoints.health import HealthResponse

app = FastAPI(
    title="Mentra API",
    description="Backend API for Mentra AI Study Coach",
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
