from __future__ import annotations

from datetime import datetime, timezone

from ..models import AccessCode, AccessCodeRedemption, db


class AccessCodeService:
    @staticmethod
    def normalize_code(raw_code: str) -> str:
        return raw_code.strip().upper()

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def _is_expired(code: AccessCode, now: datetime | None = None) -> bool:
        if not code.expires_at:
            return False
        now = now or AccessCodeService._now()
        expires_at = code.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        return expires_at <= now

    @staticmethod
    def _has_capacity(code: AccessCode) -> bool:
        if code.max_redemptions is None:
            return True
        return (code.redeemed_count or 0) < code.max_redemptions

    @staticmethod
    def lookup_code(raw_code: str) -> AccessCode | None:
        normalized = AccessCodeService.normalize_code(raw_code)
        if not normalized:
            return None
        return AccessCode.query.filter_by(code=normalized).first()

    @staticmethod
    def validate_code_for_redemption(code: AccessCode) -> None:
        now = AccessCodeService._now()
        if not code.active:
            raise ValueError("Code not working")
        if AccessCodeService._is_expired(code, now):
            raise ValueError("Code not working")
        if not AccessCodeService._has_capacity(code):
            raise ValueError("Code not working")
        if (code.percent_off or 0) < 100:
            raise ValueError("Code not working")

    @staticmethod
    def redeem_code(user_id: int, raw_code: str) -> AccessCodeRedemption:
        code = AccessCodeService.lookup_code(raw_code)
        if not code:
            raise ValueError("Code not working")
        AccessCodeService.validate_code_for_redemption(code)

        existing = AccessCodeRedemption.query.filter_by(
            user_id=user_id,
            access_code_id=code.id,
        ).first()
        if existing:
            raise ValueError("Code not working")

        redemption = AccessCodeRedemption(user_id=user_id, access_code_id=code.id)
        db.session.add(redemption)
        code.redeemed_count = (code.redeemed_count or 0) + 1
        return redemption

    @staticmethod
    def active_access_for_user(user_id: int) -> AccessCodeRedemption | None:
        now = AccessCodeService._now()
        redemption = (
            AccessCodeRedemption.query.join(AccessCode)
            .filter(
                AccessCodeRedemption.user_id == user_id,
                AccessCode.active.is_(True),
            )
            .order_by(AccessCodeRedemption.redeemed_at.desc())
            .first()
        )
        if not redemption:
            return None
        code = redemption.access_code
        if not code:
            return None
        if AccessCodeService._is_expired(code, now):
            return None
        if (code.percent_off or 0) < 100:
            return None
        return redemption
