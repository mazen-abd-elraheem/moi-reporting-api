from sqlalchemy import Column, String, Float, DateTime, Text, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from geoalchemy2 import Geography
from app.core.database import Base


class Report(Base):
    __tablename__ = "Report"
    
    reportId = Column(String(450), primary_key=True, index=True)
    title = Column(String(500), nullable=False)
    descriptionText = Column(Text, nullable=False)
    location = Column(Geography(geometry_type='POINT', srid=4326), nullable=False)
    status = Column(String(50), nullable=False, default="Submitted")
    categoryId = Column(String(100), nullable=False)
    aiConfidence = Column(Float, nullable=True)
    createdAt = Column(DateTime(timezone=True), nullable=False, server_default=func.getutcdate())
    updatedAt = Column(DateTime(timezone=True), nullable=False, server_default=func.getutcdate(), onupdate=func.getutcdate())
    userId = Column(String(450), ForeignKey("User.userId", ondelete="SET NULL"), nullable=True)
    transcribedVoiceText = Column(Text, nullable=True)
    
    # Relationships
    user = relationship("User", backref="reports")
    attachments = relationship("Attachment", back_populates="report", cascade="all, delete-orphan")
