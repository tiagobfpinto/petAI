from __future__ import annotations

import random

from ..dao.chestDAO import ChestDAO
from ..dao.itemsDAO import ItemOwnershipDAO, ItemsDAO
from ..models import db
from ..services.pet_service import PetService
from ..services.user_service import UserService
from ..dao.userDAO import UserDAO


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
    RARITY_ORDER = ("common", "uncommon", "rare", "epic", "legendary")
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
    def grant_chest(cls, *, user_id: int, tier: str | None = None) -> dict | None:
        chest = cls._pick_chest(tier)
        if not chest or not chest.item_id:
            return None

        owned = ItemOwnershipDAO.get_item_from_inventory(user_id, chest.item_id)
        if owned:
            owned.quantity = (owned.quantity or 0) + 1
            db.session.add(owned)
        else:
            pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
            owned = ItemOwnershipDAO.create_item_ownership(user_id, chest.item_id, pet.id, 1)

        return cls._chest_payload(chest, owned)

    @classmethod
    def open_chest_for_user(cls, *, user_id: int, chest_item_id: int) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        chest = ChestDAO.get_by_item_id(chest_item_id)
        if not chest:
            raise LookupError("Chest not found")

        owned = ItemOwnershipDAO.get_item_from_inventory(user_id, chest_item_id)
        if not owned or (owned.quantity or 0) <= 0:
            raise ValueError("Chest not owned")

        pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
        reward = cls.open_chest(user=user, pet=pet, chest=chest)

        remaining = (owned.quantity or 0) - 1
        if remaining <= 0:
            db.session.delete(owned)
            remaining = 0
        else:
            owned.quantity = remaining

        db.session.flush()

        return {
            "reward": reward,
            "remaining_quantity": remaining,
            "pet": PetService.pet_payload(pet),
            "coins_balance": user.coins,
        }

    @classmethod
    def open_chest(cls, *, user, pet, chest) -> dict:
        chest_tier = (chest.tier or "common").strip().lower()
        config = cls._resolve_chest_config(chest, chest_tier)

        item_payload = None
        if random.random() < config["item_chance"]:
            item_payload = cls._award_item(
                user_id=user.id,
                tier=chest_tier,
                max_item_rarity=config.get("max_item_rarity"),
            )
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
        reward["chest_item_id"] = chest.item_id
        return reward

    @classmethod
    def _roll_chest_tier(cls) -> str:
        weights = [cls.CHEST_TIER_WEIGHTS.get(tier, 0) for tier in cls.CHEST_TIERS]
        if not any(weights):
            return "common"
        return random.choices(cls.CHEST_TIERS, weights=weights, k=1)[0]

    @classmethod
    def _pick_chest(cls, tier: str | None = None):
        if tier:
            candidates = ChestDAO.list_chests_by_tier(tier)
            if candidates:
                return random.choice(candidates)

        candidates = ChestDAO.list_chests()
        if not candidates:
            return None

        weights = []
        for chest in candidates:
            chest_tier = (chest.tier or "common").strip().lower()
            weight = cls.CHEST_TIER_WEIGHTS.get(chest_tier, 1.0)
            weights.append(max(weight, 0.05))
        return random.choices(candidates, weights=weights, k=1)[0]

    @classmethod
    def _resolve_chest_config(cls, chest, tier: str) -> dict:
        fallback = cls.TIER_CONFIG.get(tier, cls.TIER_CONFIG["common"])
        item_chance = chest.item_drop_rate
        if item_chance is None or item_chance < 0:
            item_chance = fallback["item_chance"]
        xp_range = cls._range_or_default(chest.xp_min, chest.xp_max, fallback["xp_range"])
        coin_range = cls._range_or_default(chest.coin_min, chest.coin_max, fallback["coin_range"])
        return {
            "item_chance": item_chance,
            "xp_range": xp_range,
            "coin_range": coin_range,
            "max_item_rarity": chest.max_item_rarity,
        }

    @staticmethod
    def _range_or_default(low: int | None, high: int | None, fallback: tuple[int, int]) -> tuple[int, int]:
        if low is None or high is None:
            return fallback
        if low > high:
            return fallback
        return (int(low), int(high))

    @classmethod
    def _rarity_rank(cls, rarity: str | None) -> int:
        if not rarity:
            return 0
        normalized = rarity.strip().lower()
        if normalized in cls.RARITY_ORDER:
            return cls.RARITY_ORDER.index(normalized)
        return 0

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
    def _award_item(cls, *, user_id: int, tier: str | None = None, max_item_rarity: str | None = None) -> dict | None:
        items = ItemsDAO.list_items()
        if not items:
            return None
        chest_item_ids = {chest.item_id for chest in ChestDAO.list_chests() if chest.item_id}
        chest_items = [
            item
            for item in items
            if item.id not in chest_item_ids
            if (item.default_source or "").strip().lower() == "chest"
        ]
        if chest_items:
            pool = chest_items
        else:
            pool = [item for item in items if item.id not in chest_item_ids]
        if not pool:
            return None
        owned = ItemOwnershipDAO.get_items_owned_by_user(user_id)
        owned_qty = {entry.item_id: (entry.quantity or 0) for entry in owned}
        eligible = []
        max_rank = cls._rarity_rank(max_item_rarity) if max_item_rarity else None
        for item in pool:
            if max_rank is not None and cls._rarity_rank(item.rarity) > max_rank:
                continue
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
            "trigger_value": picked.trigger_value,
        }

    @staticmethod
    def _chest_payload(chest, owned) -> dict:
        item = chest.item
        chest_tier = (chest.tier or "common").strip().lower()
        return {
            "type": "chest",
            "chest_tier": chest_tier,
            "chest": {
                "item_id": item.id if item else chest.item_id,
                "name": item.name if item else None,
                "description": item.description if item else None,
                "asset_type": item.asset_type.value if item and item.asset_type else None,
                "asset_path": item.asset_path if item else None,
                "tier": chest_tier,
                "item_drop_rate": chest.item_drop_rate,
                "xp_min": chest.xp_min,
                "xp_max": chest.xp_max,
                "coin_min": chest.coin_min,
                "coin_max": chest.coin_max,
                "max_item_rarity": chest.max_item_rarity,
                "quantity": owned.quantity if owned else 1,
                "ownership_id": owned.id if owned else None,
            },
        }
