from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class FriendRequest(db.Model):
    __tablename__ = "friend_requests"

    id = db.Column(db.Integer, primary_key=True)
    requester_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    receiver_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status = db.Column(db.String(20), nullable=False, default="pending")
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=_utcnow)
    responded_at = db.Column(db.DateTime(timezone=True))

    requester = db.relationship("User", foreign_keys=[requester_id])
    receiver = db.relationship("User", foreign_keys=[receiver_id])

    __table_args__ = (
        db.UniqueConstraint("requester_id", "receiver_id", name="uq_friend_request_pair"),
        db.CheckConstraint("requester_id <> receiver_id", name="ck_friend_request_not_self"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "requester_id": self.requester_id,
            "receiver_id": self.receiver_id,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "responded_at": self.responded_at.isoformat() if self.responded_at else None,
            "from_username": getattr(self.requester, "username", None),
            "to_username": getattr(self.receiver, "username", None),
        }
