from sqlalchemy import Column, String, Float, DateTime, Text, ForeignKey, text
from sqlalchemy.orm import relationship
from app.core.database import Base


class Report(Base):
    __tablename__ = "Report"  # Matches your UML and existing DB schema

    reportId = Column(String(450), primary_key=True, index=True)
    title = Column(String(500), nullable=False)
    descriptionText = Column(Text, nullable=False)
    
    # Flexible location input: can be a map URL, address, or "lat,lng" string
    locationRaw = Column(String(2048), nullable=True)

    # Optional structured coordinates (for reports that provide them)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    
    status = Column(String(50), nullable=False, default="Submitted")
    categoryId = Column(String(100), nullable=False)
    aiConfidence = Column(Float, nullable=True, check_constraint="aiConfidence >= 0 AND aiConfidence <= 1")
    
    # UTC timestamps using Azure SQL native function
    createdAt = Column(DateTime, nullable=False, server_default=text('GETUTCDATE()'))
    updatedAt = Column(DateTime, nullable=False, server_default=text('GETUTCDATE()'), onupdate=text('GETUTCDATE()'))
    
    # Nullable for anonymous reports
    userId = Column(String(450), ForeignKey("User.userId", ondelete="SET NULL"), nullable=True)
    transcribedVoiceText = Column(Text, nullable=True)

    # Relationships
    user = relationship("User", back_populates="reports")
    attachments = relationship("Attachment", back_populates="report", cascade="all, delete-orphan")