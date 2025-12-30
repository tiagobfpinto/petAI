from __future__ import annotations

from . import db


class Chest(db.Model):
    __tablename__ = "Chest"

    item_id = db.Column(db.Integer, db.ForeignKey("Item.id", ondelete="CASCADE"), primary_key=True)
    tier = db.Column(db.String, nullable=False, default="common")
    item_drop_rate = db.Column(db.Float, nullable=False, default=0.05)
    xp_min = db.Column(db.Integer, nullable=False, default=25)
    xp_max = db.Column(db.Integer, nullable=False, default=60)
    coin_min = db.Column(db.Integer, nullable=False, default=40)
    coin_max = db.Column(db.Integer, nullable=False, default=120)
    max_item_rarity = db.Column(db.String, nullable=True)

    item = db.relationship("Item", backref=db.backref("chest", uselist=False))

    def to_dict(self) -> dict:
        return {
            "item_id": self.item_id,
            "tier": self.tier,
            "item_drop_rate": self.item_drop_rate,
            "xp_min": self.xp_min,
            "xp_max": self.xp_max,
            "coin_min": self.coin_min,
            "coin_max": self.coin_max,
            "max_item_rarity": self.max_item_rarity,
        }
