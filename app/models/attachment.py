from sqlalchemy import Column, String, BigInteger, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class Attachment(Base):
    __tablename__ = "Attachment"
    
    attachmentId = Column(String(450), primary_key=True, index=True)
    reportId = Column(String(450), ForeignKey("Report.reportId", ondelete="CASCADE"), nullable=False)
    blobStorageUri = Column(String(2048), nullable=False)
    mimeType = Column(String(100), nullable=False)
    fileType = Column(String(50), nullable=False)
    fileSizeBytes = Column(BigInteger, nullable=False)
    
    # Relationships
    report = relationship("Report", back_populates="attachments")
