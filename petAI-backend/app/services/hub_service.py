from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone

from ..dao.activityDAO import ActivityDAO
from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.goalDAO import GoalDAO
from ..dao.userDAO import UserDAO
from ..services.interest_service import InterestService
from ..services.pet_service import PetService
from ..services.friend_service import FriendService
from ..services.user_service import UserService


class HubService:
    """Lightweight services that power the new navigation tabs (shop, friends, progression)."""

    # Static catalog we can serve without new tables/migrations.
    _SHOP_ITEMS: list[dict] = [
        {
            "id": "cozy-cap",
            "name": "Cozy Cap",
            "price": 140,
            "rarity": "uncommon",
            "tag": "Headwear",
            "description": "A soft knit hat that sits snugly on top of your buddy.",
            "accent": "#FFB74D",
            "slot": "head",
            "image": "hat",
            "type": "cosmetic",
        },
        {
            "id": "sunny-shades",
            "name": "Sunny Shades",
            "price": 120,
            "rarity": "rare",
            "tag": "Face",
            "description": "Tinted sunglasses that add instant cool to every pose.",
            "accent": "#6DD5ED",
            "slot": "face",
            "image": "shades",
            "type": "cosmetic",
        },
        {
            "id": "trail-sneakers",
            "name": "Trail Sneakers",
            "price": 175,
            "rarity": "epic",
            "tag": "Feet",
            "description": "Comfy kicks that keep the pet light on its toes.",
            "accent": "#00BFA6",
            "slot": "feet",
            "image": "sneakers",
            "type": "cosmetic",
        },
        {
            "id": "leafy-cape",
            "name": "Leafy Cape",
            "price": 160,
            "rarity": "rare",
            "tag": "Back",
            "description": "A flowing cape stitched with little leaves for forest vibes.",
            "accent": "#4CAF50",
            "slot": "back",
            "image": "cape",
            "type": "cosmetic",
        },
        {
            "id": "starlit-bowtie",
            "name": "Starlit Bowtie",
            "price": 95,
            "rarity": "uncommon",
            "tag": "Neck",
            "description": "A sparkly bowtie that makes every check-in feel like a gala.",
            "accent": "#CE93D8",
            "slot": "neck",
            "image": "bowtie",
            "type": "cosmetic",
        },
        {
            "id": "glow-collar",
            "name": "Glow Collar",
            "price": 110,
            "rarity": "common",
            "tag": "Neck",
            "description": "A luminescent collar so your buddy shines on the feed.",
            "accent": "#4AC2F7",
            "slot": "neck",
            "image": "collar",
            "type": "cosmetic",
        },
    ]

    _user_owned_items: defaultdict[int, set[str]] = defaultdict(set)

    @classmethod
    def _ensure_pet(cls, user_id: int):
        return PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)

    @classmethod
    def shop_state(cls, user_id: int) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")
        pet = cls._ensure_pet(user_id)
        # Give a small baseline that scales with level so the shop never feels empty.
        baseline = 260 + max(0, pet.level - 1) * 10
        owned = cls._user_owned_items[user_id]
        if (user.coins or 0) <= 0 and not owned:
            UserService.add_coins(user, baseline)
        loadout = PetService.cosmetic_loadout(user_id)
        items = []
        for entry in cls._SHOP_ITEMS:
            item = dict(entry)
            item["owned"] = entry["id"] in owned
            if loadout.get(entry.get("slot")) == entry["id"]:
                item["equipped"] = True
            items.append(item)
        return {
            "balance": user.coins or 0,
            "items": items,
            "equipped": loadout,
        }

    @classmethod
    def purchase_item(cls, user_id: int, item_id: str) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")
        state = cls.shop_state(user_id)
        owned = cls._user_owned_items[user_id]
        item = next((itm for itm in cls._SHOP_ITEMS if itm["id"] == item_id), None)
        if not item:
            raise LookupError("Item not found")
        if item_id in owned:
            raise ValueError("You already own this item")
        if state["balance"] < item["price"]:
            raise ValueError("Not enough coins for this item")

        pet = cls._ensure_pet(user_id)
        UserService.spend_coins(user, item["price"])
        owned.add(item_id)
        slot = item.get("slot")
        if slot:
            PetService.equip_cosmetic(user_id, slot, item_id)

        # Tiny XP boost to keep purchases meaningful.
        PetService.add_xp(pet, 5)

        return cls.shop_state(user_id)

    @classmethod
    def friends_feed(cls, user_id: int) -> list[dict]:
        payload = FriendService.friends_payload(user_id)
        return payload.get("friends", [])

    @classmethod
    def progression_snapshot(cls, user_id: int) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        pet = cls._ensure_pet(user_id)
        interests = InterestService.list_user_interests(user_id)

        now = datetime.now(timezone.utc)
        start_week = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=6)
        weekly = ActivityDAO.list_for_user_between(user_id, start_week, now)
        today_logs = ActivityDAO.list_for_user_today(user_id)

        daily_buckets: dict[str, dict[str, int]] = {}
        for offset in range(6, -1, -1):
            day = (now - timedelta(days=offset)).date().isoformat()
            daily_buckets[day] = {"xp": 0, "count": 0}

        for log in weekly:
            day = log.timestamp.date().isoformat() if log.timestamp else now.date().isoformat()
            bucket = daily_buckets.get(day)
            if bucket is None:
                daily_buckets[day] = {"xp": 0, "count": 0}
                bucket = daily_buckets[day]
            bucket["xp"] += log.xp_earned
            bucket["count"] += 1

        streak_current = user.streak_current or 0
        streak_best = user.streak_best or 0
        milestones = [
            {
                "id": "streak-3",
                "label": "Keep a 3 day streak",
                "progress": min(streak_current / 3, 1.0),
                "achieved": streak_current >= 3,
                "reward": "+10% XP boost",
            },
            {
                "id": "week-5",
                "label": "Log 5 wins this week",
                "progress": min(len(weekly) / 5, 1.0),
                "achieved": len(weekly) >= 5,
                "reward": "Bonus shop coins",
            },
            {
                "id": "level-5",
                "label": "Reach level 5",
                "progress": min(pet.level / 5, 1.0),
                "achieved": pet.level >= 5,
                "reward": "Pet evolution gift",
            },
        ]

        summary = {
            "level": pet.level,
            "stage": pet.stage,
            "xp": pet.xp,
            "next_evolution_xp": pet.next_evolution_xp,
            "streak_current": streak_current,
            "streak_best": streak_best,
            "interests": len(interests),
            "activities": len(weekly),
        }

        today = {
            "completed": len(today_logs),
            "xp": sum(log.xp_earned for log in today_logs),
        }

        weekly_payload = [
            {"day": key, "xp": value["xp"], "count": value["count"]}
            for key, value in sorted(daily_buckets.items())
        ]

        weekly_goals: list[dict] = []
        for interest in interests:
            # Gather all activity types for this interest so we return every goal, not just the first.
            activity_types = list(getattr(interest, "activity_types", []) or [])
            if not activity_types:
                primary = ActivityTypeDAO.primary_for_area(user_id, interest.id) or ActivityTypeDAO.get_or_create(
                    user_id, interest.id, interest.name
                )
                activity_types = [primary]

            for activity_type in activity_types:
                plan = activity_type._plan_dict() if activity_type else None
                goal = GoalDAO.latest_active(user_id, activity_type.id) if activity_type else None

                if plan is None:
                    if (
                        goal is None
                        or goal.amount is None
                        or goal.amount <= 0
                        or activity_type is None
                        or activity_type.weekly_goal_value is None
                        or activity_type.weekly_goal_value <= 0
                    ):
                        continue
                    plan = {
                        "weekly_goal_value": float(goal.amount),
                        "weekly_goal_unit": goal.unit or "units",
                        "days": [],
                        "per_day_goal_value": None,
                    }

                progress_value = float(goal.progress_value or 0) if goal else 0.0
                progress_target = float((goal.amount if goal else None) or plan.get("weekly_goal_value") or 0)
                progress = 0.0
                if progress_target > 0:
                    try:
                        progress = max(0.0, min(progress_value / progress_target, 1.0))
                    except Exception:
                        progress = 0.0

                weekly_goals.append(
                    {
                        "interest": interest.name,
                        "goal": (goal.title if goal else None) or (activity_type.goal if activity_type else None),
                        "plan": plan,
                        "progress": progress,
                        "progress_value": progress_value,
                        "progress_target": progress_target,
                    }
                )

        return {
            "summary": summary,
            "today": today,
            "weekly_xp": weekly_payload,
            "milestones": milestones,
            "weekly_goals": weekly_goals,
        }
