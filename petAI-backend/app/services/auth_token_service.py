from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

from flask import current_app

from ..models import AuthToken, db


class AuthTokenService:
    @staticmethod
    def issue_token(user_id: int) -> str:
        token_value = AuthTokenService._generate_token_value()
        expires_at = AuthTokenService._compute_expiration()
        token = AuthToken(user_id=user_id, token=token_value, expires_at=expires_at)
        db.session.add(token)
        return token_value

    @staticmethod
    def revoke_token(token_value: str) -> bool:
        if not token_value:
            return False
        token = AuthToken.query.filter_by(token=token_value).first()
        if not token:
            return False
        db.session.delete(token)
        return True

    @staticmethod
    def get_token(token_value: str) -> AuthToken | None:
        if not token_value:
            return None
        return AuthToken.query.filter_by(token=token_value).first()

    @staticmethod
    def is_token_active(token: AuthToken | None) -> bool:
        if not token:
            return False
        if token.expires_at and token.expires_at <= datetime.now(timezone.utc):
            return False
        return True

    @staticmethod
    def extract_bearer_token(auth_header: str | None) -> str | None:
        if not auth_header:
            return None
        parts = auth_header.strip().split()
        if len(parts) != 2:
            return None
        scheme, token = parts
        if scheme.lower() != "bearer":
            return None
        return token

    @staticmethod
    def _generate_token_value() -> str:
        return secrets.token_urlsafe(48)

    @staticmethod
    def _compute_expiration() -> datetime | None:
        ttl_seconds = current_app.config.get("AUTH_TOKEN_EXPIRES_SECONDS")
        if not ttl_seconds or ttl_seconds <= 0:
            return None
        return datetime.now(timezone.utc) + timedelta(seconds=int(ttl_seconds))
