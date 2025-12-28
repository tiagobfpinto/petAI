from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class EventLog(db.Model):
    __tablename__ = "event_logs"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    event_name = db.Column(db.String(120), nullable=False, index=True)
    payload = db.Column(db.JSON)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=_utcnow)

    user = db.relationship("User", back_populates="event_logs")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "event_name": self.event_name,
            "payload": self.payload,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
