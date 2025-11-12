from sqlalchemy import Column, String, Boolean, DateTime, func
from app.core.database import Base


class User(Base):
    __tablename__ = "User"  # Matches UML Class Diagram

    userId = Column(String(450), primary_key=True, index=True)
    isAnonymous = Column(Boolean, nullable=False, default=False)
    createdAt = Column(DateTime, nullable=False, server_default=func.now())
    role = Column(String(50), nullable=False, default="citizen")
    
    # Nullable for anonymous users; unique when provided
    email = Column(String(256), nullable=True, unique=True)
    phoneNumber = Column(String(20), nullable=True, unique=True)
    hashedDeviceId = Column(String(256), nullable=True, unique=True)

    def __repr__(self):
        return f"<User(id={self.userId}, anonymous={self.isAnonymous}, role={self.role})>"