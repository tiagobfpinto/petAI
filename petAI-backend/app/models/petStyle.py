from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)




class PetStyle(db.Model):
    __tablename__ = "PetStyles"

    id = db.Column(db.Integer, primary_key=True)
    pet_id = db.Column(db.Integer, db.ForeignKey("pets.id", ondelete="CASCADE"), nullable=True, index=True)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)
    
    hat_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="SET NULL"), nullable=True)
    sunglasses_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="SET NULL"), nullable=True)
    color_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="SET NULL"), nullable=True)
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "pet_id": self.pet_id,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "hat_id": self.hat_id,
            "sunglasses_id": self.sunglasses_id,
            "color_id": self.color_id,
        }
    
 