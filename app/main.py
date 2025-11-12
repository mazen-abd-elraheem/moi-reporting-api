from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from sqlalchemy import text
import logging

from app.core.config import get_settings
from app.core.database import engine  # This must be an async engine

# Load settings
settings = get_settings()

# Configure structured logging
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events."""
    # === Startup ===
    logger.info(f"Starting {settings.APP_NAME} in {settings.ENVIRONMENT} environment")
    logger.info("Verifying async database connection...")

    try:
        # Test async connection to Azure SQL
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))  # Lightweight ping
        logger.info("✓ Async database connection successful")
    except Exception as e:
        logger.critical(f"✗ Failed to connect to database: {e}", exc_info=True)
        raise SystemExit("Database connection failed. Shutting down.")

    yield  # App runs here

    # === Shutdown ===
    logger.info("Shutting down application...")
    await engine.dispose()  # Properly close async engine


# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.API_VERSION,
    description="MVP API for MoI Digital Reporting System — Secure citizen incident reporting",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Configure CORS (from settings, e.g., Flutter Web or Mobile domains)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# === Endpoints ===

@app.get("/health", status_code=status.HTTP_200_OK, include_in_schema=False)
async def health_check():
    """Lightweight health check for load balancers and monitoring."""
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "version": settings.API_VERSION,
        "environment": settings.ENVIRONMENT
    }


@app.get("/", include_in_schema=False)
async def root():
    """Root redirect to API documentation."""
    return {
        "message": "Welcome to the MoI Digital Reporting System API",
        "version": settings.API_VERSION,
        "docs": "/api/docs"
    }


# === Exception Handling ===

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Catch unhandled exceptions and log them securely."""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error",
            "message": str(exc) if settings.DEBUG else "An unexpected error occurred"
        }
    )


# === Development server ===
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )