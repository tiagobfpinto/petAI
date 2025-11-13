from datetime import datetime, timezone

from models import db


def _utcnow():
    return datetime.now(timezone.utc)


class Pet(db.Model):
    __tablename__ = "pets"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )

    # Pet progression
    xp = db.Column(db.Integer, default=0, nullable=False)
    level = db.Column(
        db.Integer, default=1, nullable=False
    )  # numeric level for internal logic
    stage = db.Column(
        db.String(50), default="egg", nullable=False
    )  # human-readable stage name

    # Evolution metadata
    next_evolution_xp = db.Column(db.Integer, default=100, nullable=False)

    # Cosmetic / future-proofing
    pet_type = db.Column(db.String(50), default="sprout", nullable=False)
    current_sprite = db.Column(
        db.String(255), nullable=True
    )  # URL/path to current sprite

    # Timestamps
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow)
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=_utcnow,
        onupdate=_utcnow,
    )
