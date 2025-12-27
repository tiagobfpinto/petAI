from __future__ import annotations

from datetime import datetime, timezone

from ..models.subscription import Subscription


class SubscriptionService:
    @staticmethod
    def latest_for_user(user_id: int) -> Subscription | None:
        return (
            Subscription.query.filter_by(user_id=user_id)
            .order_by(Subscription.expires_at.desc().nullslast(), Subscription.created_at.desc())
            .first()
        )

    @staticmethod
    def subscription_payload(user_id: int) -> dict:
        sub = SubscriptionService.latest_for_user(user_id)
        if not sub:
            return {"active": False, "status": "none"}

        now = datetime.now(timezone.utc)
        expires_at = sub.expires_at
        active = sub.status in ("active", "trialing") and (
            expires_at is None or expires_at > now
        )
        payload = {
            "active": active,
            "status": sub.status,
            "product_id": sub.product_id,
            "provider": sub.provider,
            "is_trial": sub.is_trial,
            "expires_at": expires_at.isoformat() if expires_at else None,
            "started_at": sub.started_at.isoformat() if sub.started_at else None,
        }
        return payload
