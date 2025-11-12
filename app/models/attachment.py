from sqlalchemy import Column, String, BigInteger, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class Attachment(Base):
    __tablename__ = "attachments"  # or "Attachment" if strictly following UML

    attachment_id = Column(String(450), primary_key=True, index=True)
    report_id = Column(String(450), ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False)
    blob_storage_uri = Column(String(2048), nullable=False)
    mime_type = Column(String(100), nullable=False)
    file_type = Column(String(50), nullable=False)
    file_size_bytes = Column(BigInteger, nullable=False)

    # Relationship
    report = relationship("Report", back_populates="attachments")

    def __repr__(self):
        return f"<Attachment(id={self.attachment_id}, report_id={self.report_id}, type={self.file_type})>"