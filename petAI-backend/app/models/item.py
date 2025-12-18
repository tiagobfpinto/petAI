from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)

import enum

class AssetType(enum.Enum):
    PNG = "png"
    RIVE = "rive"

class TypeOfItem(enum.Enum):
    HAT = "hat"
    SUNGLASSES = "sunglasses"
    COLOR = "color"
    DEFAULT = "default"

class Item(db.Model):
    __tablename__ = "Item"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String, nullable=False)
    
    type = db.Column(
    db.Enum(TypeOfItem, name="type_of_item_enum"),
    nullable=False,
    default=TypeOfItem.DEFAULT
    )
    
    default_source = db.Column(db.String, nullable=True) #item store/chest/friend gift/quest reward 
    description = db.Column(db.String, nullable=True)
    
    asset_type = db.Column(
    db.Enum(AssetType, name="asset_type_enum"),
    nullable=False,
    default=AssetType.PNG
    )
    asset_path = db.Column(db.String, nullable=True) #path to the asset file
    layer_name = db.Column(db.String, nullable=True) #for layering in the frontend
    
    value = db.Column(db.Integer, nullable=True) #value if user quick sells the item
    rarity = db.Column(db.String, nullable=True)
    trigger = db.Column(db.String, nullable=True) #for the machine state in the frontend
    max_quantity = db.Column(db.Integer, nullable=True) #max quantity a user can hold, null means unlimited
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "type": self.type.value if self.type else None,
            "default_source": self.default_source,
            "asset_type": self.asset_type.value if self.asset_type else None,
            "asset_path": self.asset_path,
            "layer_name": self.layer_name,
            "value": self.value,
            "rarity": self.rarity,
            "trigger": self.trigger,
        }
