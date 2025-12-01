from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone

from ..dao.activityDAO import ActivityDAO
from ..dao.userDAO import UserDAO
from ..services.interest_service import InterestService
from ..services.pet_service import PetService
from ..services.friend_service import FriendService


class HubService:
    """Lightweight services that power the new navigation tabs (shop, friends, progression)."""

    # Static catalog we can serve without new tables/migrations.
    _SHOP_ITEMS: list[dict] = [
        {
            "id": "berry-boost",
            "name": "Berry Boost",
            "price": 120,
            "rarity": "rare",
            "tag": "Energy",
            "description": "Sweet berries that add a spark to your next training log.",
            "accent": "#FF7A9E",
        },
        {
            "id": "focus-tea",
            "name": "Focus Tea",
            "price": 95,
            "rarity": "uncommon",
            "tag": "Focus",
            "description": "Calming brew that keeps your streak safe for the day.",
            "accent": "#7C4DFF",
        },
        {
            "id": "trail-sneakers",
            "name": "Trail Sneakers",
            "price": 175,
            "rarity": "epic",
            "tag": "Speed",
            "description": "Lightweight sneakers that double XP on your next logged win.",
            "accent": "#00BFA6",
        },
        {
            "id": "zen-kit",
            "name": "Zen Starter Kit",
            "price": 80,
            "rarity": "common",
            "tag": "Calm",
            "description": "Mini rituals to unwind and keep your pet mellow.",
            "accent": "#6C8BA4",
        },
        {
            "id": "coach-whistle",
            "name": "Coach Whistle",
            "price": 140,
            "rarity": "rare",
            "tag": "Guidance",
            "description": "Calls in a coach to suggest an extra activity idea.",
            "accent": "#F8B400",
        },
        {
            "id": "glow-collar",
            "name": "Glow Collar",
            "price": 110,
            "rarity": "uncommon",
            "tag": "Style",
            "description": "Cosmetic flair that keeps your buddy visible on the feed.",
            "accent": "#4AC2F7",
        },
    ]

    _user_owned_items: defaultdict[int, set[str]] = defaultdict(set)

    @classmethod
    def _ensure_pet(cls, user_id: int):
        return PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)

    @classmethod
    def shop_state(cls, user_id: int) -> dict:
        pet = cls._ensure_pet(user_id)
        # Give a small baseline that scales with level so the shop never feels empty.
        baseline = 260 + max(0, pet.level - 1) * 10
        owned = cls._user_owned_items[user_id]
        if (pet.coins or 0) <= 0 and not owned:
            PetService.add_coins(pet, baseline)
        items = []
        for entry in cls._SHOP_ITEMS:
            item = dict(entry)
            item["owned"] = entry["id"] in owned
            items.append(item)
        return {
            "balance": pet.coins or 0,
            "items": items,
        }

    @classmethod
    def purchase_item(cls, user_id: int, item_id: str) -> dict:
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
        PetService.spend_coins(pet, item["price"])
        owned.add(item_id)

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
            plan = interest._plan_dict()
            if not plan:
                continue
            weekly_goals.append(
                {
                    "interest": interest.name,
                    "goal": interest.goal,
                    "plan": plan,
                }
            )

        return {
            "summary": summary,
            "today": today,
            "weekly_xp": weekly_payload,
            "milestones": milestones,
            "weekly_goals": weekly_goals,
        }
