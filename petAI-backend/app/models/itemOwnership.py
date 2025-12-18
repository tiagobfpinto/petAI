from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)




class ItemOwnership(db.Model):
    __tablename__ = "itemsOwnership"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #LINK TO THE DEFINITION OF THE ITEM 
    item_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="CASCADE"), nullable=False)
    
    pet_id = db.Column(db.Integer, db.ForeignKey("pets.id", ondelete="CASCADE"), nullable=True, index=True)
    acquired_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "item_id": self.item_id,
            "pet_id": self.pet_id,
            "acquired_at": self.acquired_at.isoformat() if self.acquired_at else None,
            "quantity": self.quantity,
        }
    