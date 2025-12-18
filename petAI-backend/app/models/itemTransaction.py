from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)



class ItemTransaction(db.Model):
    __tablename__ = "ItemTransaction"

    id = db.Column(db.Integer, primary_key=True)
    item_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="CASCADE"), nullable=False)
    valu = db.Column(db.Integer, nullable=False)
    op = db.Column(db.String, nullable=False)  # e.g., "purchase", "sale", etc.
    currency = db.Column(db.String, nullable=False, default="coins")  # e.g., coins, gems, etc.
    date = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "item_id": self.item_id,
            "valu": self.valu,
            "op": self.op,
            "currency": self.currency,
            "date": self.date.isoformat() if self.date else None,
        }
 
    
    