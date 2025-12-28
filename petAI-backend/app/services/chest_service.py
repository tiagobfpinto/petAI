from __future__ import annotations

import random

from ..dao.itemsDAO import ItemOwnershipDAO, ItemsDAO
from ..models import db
from ..services.pet_service import PetService
from ..services.user_service import UserService


class ChestService:
    CHEST_INTERVAL = 5
    CHEST_TIERS = ("common", "rare", "epic")
    CHEST_TIER_WEIGHTS = {
        "common": 0.7,
        "rare": 0.23,
        "epic": 0.07,
    }
    TIER_CONFIG = {
        "common": {
            "item_chance": 0.05,
            "xp_range": (25, 60),
            "coin_range": (40, 120),
        },
        "rare": {
            "item_chance": 0.18,
            "xp_range": (60, 110),
            "coin_range": (110, 220),
        },
        "epic": {
            "item_chance": 0.45,
            "xp_range": (120, 200),
            "coin_range": (220, 420),
        },
    }
    RARITY_WEIGHTS = {
        "common": {
            "common": 1.0,
            "uncommon": 0.7,
            "rare": 0.35,
            "epic": 0.2,
            "legendary": 0.1,
        },
        "rare": {
            "common": 0.6,
            "uncommon": 1.0,
            "rare": 1.4,
            "epic": 1.9,
            "legendary": 2.4,
        },
        "epic": {
            "common": 0.3,
            "uncommon": 0.7,
            "rare": 1.3,
            "epic": 2.2,
            "legendary": 3.0,
        },
    }

    @classmethod
    def open_chest(cls, *, user, pet, tier: str | None = None) -> dict:
        chest_tier = (tier or cls._roll_chest_tier()).strip().lower()
        if chest_tier not in cls.CHEST_TIERS:
            chest_tier = "common"
        config = cls.TIER_CONFIG.get(chest_tier, cls.TIER_CONFIG["common"])

        item_payload = None
        if random.random() < config["item_chance"]:
            item_payload = cls._award_item(user_id=user.id, tier=chest_tier)
        if item_payload:
            reward = {"type": "item", "item": item_payload}
        else:
            reward = cls._award_currency(
                user=user,
                pet=pet,
                xp_range=config["xp_range"],
                coin_range=config["coin_range"],
            )
        reward["chest_tier"] = chest_tier
        return reward

    @classmethod
    def _roll_chest_tier(cls) -> str:
        weights = [cls.CHEST_TIER_WEIGHTS.get(tier, 0) for tier in cls.CHEST_TIERS]
        if not any(weights):
            return "common"
        return random.choices(cls.CHEST_TIERS, weights=weights, k=1)[0]

    @classmethod
    def _award_currency(cls, *, user, pet, xp_range: tuple[int, int], coin_range: tuple[int, int]) -> dict:
        if random.random() < 0.5:
            xp = random.randint(xp_range[0], xp_range[1])
            evolution = PetService.add_xp(pet, xp)
            return {
                "type": "xp",
                "xp": xp,
                "pet": evolution["pet"],
                "evolved": evolution["evolved"],
            }
        coins = random.randint(coin_range[0], coin_range[1])
        UserService.add_coins(user, coins)
        return {"type": "coins", "coins": coins}

    @classmethod
    def _award_item(cls, *, user_id: int, tier: str | None = None) -> dict | None:
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

        chest_tier = (tier or "common").strip().lower()
        weights = []
        rarity_weights = cls.RARITY_WEIGHTS.get(chest_tier, {})
        for item in eligible:
            rarity = (item.rarity or "").strip().lower()
            weight = rarity_weights.get(rarity, 1.0)
            weights.append(max(weight, 0.05))
        picked = random.choices(eligible, weights=weights, k=1)[0]
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
