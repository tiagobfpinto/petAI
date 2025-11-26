from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Pet(db.Model):
    __tablename__ = "pets"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)

    xp = db.Column(db.Integer, default=0, nullable=False)
    level = db.Column(db.Integer, default=1, nullable=False)
    stage = db.Column(db.String(50), default="egg", nullable=False)
    next_evolution_xp = db.Column(db.Integer, default=100, nullable=False)
    pet_type = db.Column(db.String(50), default="sprout", nullable=False)
    current_sprite = db.Column(db.String(255))

    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    user = db.relationship("User", back_populates="pet")

    __table_args__ = (
        db.CheckConstraint("xp >= 0", name="ck_pet_xp_non_negative"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "xp": self.xp,
            "level": self.level,
            "stage": self.stage,
            "next_evolution_xp": self.next_evolution_xp,
            "pet_type": self.pet_type,
            "current_sprite": self.current_sprite,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
