from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AccessCodeRedemption(db.Model):
    __tablename__ = "access_code_redemptions"

    id = db.Column(db.Integer, primary_key=True)
    access_code_id = db.Column(
        db.Integer,
        db.ForeignKey("access_codes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    redeemed_at = db.Column(db.DateTime(timezone=True), nullable=False, default=_utcnow)

    access_code = db.relationship("AccessCode", back_populates="redemptions")
    user = db.relationship("User", back_populates="access_code_redemptions")

    __table_args__ = (
        db.UniqueConstraint("access_code_id", "user_id", name="uq_access_code_user"),
    )
