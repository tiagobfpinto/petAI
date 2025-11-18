from __future__ import annotations

from functools import wraps

from flask import g, request

from ..routes import error_response
from ..services.auth_token_service import AuthTokenService


def token_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        token_value = AuthTokenService.extract_bearer_token(auth_header)
        if not token_value:
            return error_response("Authorization token missing", 401)

        token = AuthTokenService.get_token(token_value)
        if not AuthTokenService.is_token_active(token):
            return error_response("Invalid or expired token", 401)

        g.current_user = token.user
        g.current_token_value = token_value
        g.current_token = token
        return fn(*args, **kwargs)

    return wrapper


def get_current_user():
    return getattr(g, "current_user", None)


def get_current_user_id() -> int | None:
    user = get_current_user()
    return user.id if user else None


def get_current_token_value() -> str | None:
    return getattr(g, "current_token_value", None)
