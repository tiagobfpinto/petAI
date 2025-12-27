from __future__ import annotations

import random

from ..dao.itemsDAO import ItemOwnershipDAO, ItemsDAO
from ..models import db
from ..services.pet_service import PetService
from ..services.user_service import UserService


class ChestService:
    CHEST_INTERVAL = 5
    ITEM_CHANCE = 0.05
    XP_RANGE = (25, 60)
    COIN_RANGE = (40, 120)

    @classmethod
    def open_chest(cls, *, user, pet) -> dict:
        roll = random.random()
        if roll < cls.ITEM_CHANCE:
            item_payload = cls._award_item(user_id=user.id)
            if item_payload:
                return {"type": "item", "item": item_payload}
        return cls._award_currency(user=user, pet=pet)

    @classmethod
    def _award_currency(cls, *, user, pet) -> dict:
        if random.random() < 0.5:
            xp = random.randint(cls.XP_RANGE[0], cls.XP_RANGE[1])
            evolution = PetService.add_xp(pet, xp)
            return {
                "type": "xp",
                "xp": xp,
                "pet": evolution["pet"],
                "evolved": evolution["evolved"],
            }
        coins = random.randint(cls.COIN_RANGE[0], cls.COIN_RANGE[1])
        UserService.add_coins(user, coins)
        return {"type": "coins", "coins": coins}

    @classmethod
    def _award_item(cls, *, user_id: int) -> dict | None:
        items = ItemsDAO.list_items()
        if not items:
            return None
        chest_items = [
            item
            for item in items
            if (item.default_source or "").strip().lower() == "chest"
        ]
        pool = chest_items if chest_items else items
        owned = ItemOwnershipDAO.get_items_owned_by_user(user_id)
        owned_qty = {entry.item_id: (entry.quantity or 0) for entry in owned}
        eligible = []
        for item in pool:
            max_qty = item.max_quantity
            if max_qty is not None and owned_qty.get(item.id, 0) >= max_qty:
                continue
            eligible.append(item)
        if not eligible:
            return None

        picked = random.choice(eligible)
        existing = ItemOwnershipDAO.get_item_from_inventory(user_id, picked.id)
        if existing:
            existing.quantity = (existing.quantity or 0) + 1
            db.session.add(existing)
        else:
            pet = PetService.get_pet_by_user(user_id)
            if not pet:
                pet = PetService.create_pet(user_id)
            ItemOwnershipDAO.create_item_ownership(user_id, picked.id, pet.id, 1)

        return {
            "id": picked.id,
            "name": picked.name,
            "type": picked.type.value if picked.type else None,
            "rarity": picked.rarity,
            "asset_path": picked.asset_path,
            "trigger": picked.trigger,
        }
