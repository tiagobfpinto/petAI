from __future__ import annotations

from datetime import datetime, timedelta, timezone

from ..models import db
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

    @staticmethod
    def set_mock_subscription(user_id: int, active: bool) -> Subscription:
        now = datetime.now(timezone.utc)
        sub = Subscription.query.filter_by(user_id=user_id, provider="mock").first()
        if not sub:
            sub = Subscription(
                user_id=user_id,
                provider="mock",
                product_id="mock_premium",
                status="active" if active else "canceled",
                is_trial=False,
                started_at=now,
                expires_at=now + timedelta(days=30) if active else now,
                latest_transaction_id="mock",
                original_transaction_id="mock",
            )
        else:
            sub.status = "active" if active else "canceled"
            sub.expires_at = now + timedelta(days=30) if active else now
            sub.latest_transaction_id = "mock"
            sub.original_transaction_id = sub.original_transaction_id or "mock"
            if not sub.started_at:
                sub.started_at = now
        db.session.add(sub)
        return sub
