from sqlalchemy import create_engine, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from typing import Generator
import urllib

from app.core.config import get_settings

settings = get_settings()

# Parse connection string for Azure SQL
params = urllib.parse.quote_plus(settings.DATABASE_CONNECTION_STRING)
DATABASE_URL = f"mssql+pyodbc:///?odbc_connect={params}"

# Create engine with Azure SQL optimizations
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=settings.DEBUG,
    connect_args={
        "timeout": 30,
        "autocommit": False,
    }
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db() -> Generator:
    """Database session dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
