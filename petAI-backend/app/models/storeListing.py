from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)




class StoreListing(db.Model):
    __tablename__ = "storeListing"

    id = db.Column(db.Integer, primary_key=True)
    item_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="CASCADE"), nullable=False)
    price = db.Column(db.Integer, nullable=False)
    stock = db.Column(db.Integer, nullable=True)  # Null stock means unlimited stock
    currency = db.Column(db.String, nullable=False, default="coins")  # e.g., coins, gems, etc.
    active = db.Column(db.Boolean, default=True, nullable=False)
    starts_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    ends_at = db.Column(db.DateTime(timezone=True), nullable=True)  # Null means no end date
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "item_id": self.item_id,
            "price": self.price,
            "stock": self.stock,
            "currency": self.currency,
            "active": self.active,
            "starts_at": self.starts_at.isoformat() if self.starts_at else None,
            "ends_at": self.ends_at.isoformat() if self.ends_at else None,
        }
    
    