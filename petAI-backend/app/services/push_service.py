from __future__ import annotations

from datetime import datetime, timezone

from ..models import db
from ..models.push_token import PushToken


class PushService:
    @staticmethod
    def register_token(
        user_id: int,
        token: str,
        platform: str,
        device_id: str | None = None,
    ) -> PushToken:
        token = token.strip()
        platform = platform.strip().lower()
        existing = PushToken.query.filter_by(token=token).first()
        now = datetime.now(timezone.utc)
        if existing:
            existing.user_id = user_id
            existing.platform = platform
            existing.device_id = device_id or existing.device_id
            existing.last_seen_at = now
            db.session.add(existing)
            return existing

        entry = PushToken(
            user_id=user_id,
            token=token,
            platform=platform,
            device_id=device_id,
            created_at=now,
            last_seen_at=now,
        )
        db.session.add(entry)
        return entry

    @staticmethod
    def unregister_token(user_id: int, token: str) -> bool:
        token = token.strip()
        entry = PushToken.query.filter_by(token=token, user_id=user_id).first()
        if not entry:
            return False
        db.session.delete(entry)
        return True
