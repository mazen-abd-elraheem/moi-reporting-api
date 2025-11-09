from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "User"
    
    userId = Column(String(450), primary_key=True, index=True)
    isAnonymous = Column(Boolean, nullable=False, default=False)
    createdAt = Column(DateTime(timezone=True), nullable=False, server_default=func.getutcdate())
    role = Column(String(50), nullable=False, default="citizen")
    email = Column(String(256), nullable=True)
    phoneNumber = Column(String(20), nullable=True)
    hashedDeviceId = Column(String(256), nullable=True)