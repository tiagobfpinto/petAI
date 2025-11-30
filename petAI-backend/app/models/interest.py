from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Interest(db.Model):
    __tablename__ = "interests"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = db.Column(db.String(120), nullable=False)
    level = db.Column(db.String(32), nullable=False)
    goal = db.Column(db.String(255))
    monthly_goal = db.Column(db.Float)  # numeric target (ex: km)
    month_progress = db.Column(db.Float, default=0)
    target_unit = db.Column(db.String(32), default="units")
    last_suggestions_generated_at = db.Column(db.DateTime(timezone=True))
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    user = db.relationship("User", back_populates="interests")

    __table_args__ = (
        db.UniqueConstraint("user_id", "name", name="uq_user_interest_name"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "level": self.level,
            "goal": self.goal,
            "monthly_goal": self.monthly_goal,
            "month_progress": self.month_progress,
            "target_unit": self.target_unit,
            "last_suggestions_generated_at": self.last_suggestions_generated_at.isoformat()
            if self.last_suggestions_generated_at
            else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
