# app/core/database.py

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.pool import AsyncAdaptedQueuePool
import urllib.parse
from typing import AsyncGenerator

from app.core.config import get_settings

settings = get_settings()

# URL-encode the connection string (Azure SQL uses ODBC)
params = urllib.parse.quote_plus(settings.DATABASE_CONNECTION_STRING)
DATABASE_URL = f"mssql+aioodbc:///?odbc_connect={params}"

# Async engine for Azure SQL
engine = create_async_engine(
    DATABASE_URL,
    echo=settings.DEBUG,
    poolclass=AsyncAdaptedQueuePool,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    connect_args={
        "timeout": 30,
        "command_timeout": 30,
        "autocommit": False,
    }
)

# Async session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

# Base for models
Base = declarative_base()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Async database session dependency for FastAPI endpoints"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()