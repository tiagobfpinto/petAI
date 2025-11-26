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
        user = token.user
        inactive = False
        if user.is_guest:
            # Lazy-import to avoid circular dependency.
            from ..services.user_service import UserService

            remaining = UserService._trial_days_left(user)
            if remaining <= 0:
                UserService.mark_trial_expired(user)
                inactive = True
        if not user.is_active:
            inactive = True

        # Store on both g and request so downstream code can access it reliably.
        g.current_user = user
        g.current_token_value = token_value
        g.current_token = token
        setattr(request, "current_user", user)
        setattr(request, "current_token_value", token_value)
        setattr(request, "current_token", token)
        setattr(request, "current_user_inactive", inactive)
        return fn(*args, **kwargs)

    return wrapper


def active_user_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        inactive = getattr(request, "current_user_inactive", False)
        if inactive:
            return error_response("Trial expired. Upgrade to continue.", 403)
        user = getattr(request, "current_user", None)
        if user is not None and not getattr(user, "is_active", True):
            return error_response("Account inactive. Upgrade to continue.", 403)
        return fn(*args, **kwargs)

    return wrapper


def get_current_user():
    return getattr(g, "current_user", None)


def get_current_user_id() -> int | None:
    user = get_current_user()
    return user.id if user else None


def get_current_token_value() -> str | None:
    return getattr(g, "current_token_value", None)
