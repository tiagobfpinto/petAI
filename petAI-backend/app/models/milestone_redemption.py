from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class MilestoneRedemption(db.Model):
    __tablename__ = "milestone_redemptions"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    milestone_id = db.Column(db.String(64), nullable=False)
    redeemed_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)

    __table_args__ = (
        db.UniqueConstraint("user_id", "milestone_id", name="uq_user_milestone_redemption"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "milestone_id": self.milestone_id,
            "redeemed_at": self.redeemed_at.isoformat() if self.redeemed_at else None,
        }
