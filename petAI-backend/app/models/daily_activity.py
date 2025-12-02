from __future__ import annotations

from datetime import datetime, timezone, date

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DailyActivity(db.Model):
    __tablename__ = "daily_activities"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    interest_id = db.Column(db.Integer, db.ForeignKey("areas.id", ondelete="CASCADE"), nullable=False, index=True)
    activity_type_id = db.Column(db.Integer, db.ForeignKey("activity_types.id", ondelete="CASCADE"), nullable=False)
    goal_id = db.Column(db.Integer, db.ForeignKey("goals.id", ondelete="SET NULL"))
    title = db.Column(db.String(255), nullable=False)
    scheduled_for = db.Column(db.Date, nullable=False, index=True)
    todo_date = db.Column(db.Date, nullable=False, index=True)
    status = db.Column(db.String(32), default="pending", nullable=False)
    completed_at = db.Column(db.DateTime(timezone=True))
    xp_awarded = db.Column(db.Integer)
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    interest = db.relationship("Area")
    activity_type = db.relationship("ActivityType")
    goal = db.relationship("Goal")

    __table_args__ = (
        db.UniqueConstraint(
            "user_id",
            "activity_type_id",
            "scheduled_for",
            "title",
            name="uq_user_activitytype_date_title",
        ),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "interest_id": self.interest_id,
            "activity_type_id": self.activity_type_id,
            "goal_id": self.goal_id,
            "title": self.title,
            "scheduled_for": self.scheduled_for.isoformat(),
            "todo_date": self.todo_date.isoformat(),
            "status": self.status,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "xp_awarded": self.xp_awarded,
        }
