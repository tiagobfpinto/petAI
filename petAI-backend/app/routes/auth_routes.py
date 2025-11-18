from __future__ import annotations

from flask import Blueprint, request
from sqlalchemy.exc import IntegrityError

from ..auth import get_current_token_value, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.auth_token_service import AuthTokenService
from ..services.user_service import UserService
from ..dao.userDAO import UserDAO

auth_bp = Blueprint("auth", __name__, url_prefix="/auth")


@auth_bp.route("/register", methods=["POST", "OPTIONS"])
def register():
    if request.method == "OPTIONS":
        return "", 200
    payload = request.get_json(silent=True) or {}
    username = (payload.get("username") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password")
    full_name = (payload.get("full_name") or "").strip() or None

    if not username or not email or not password:
        return error_response("username, email, and password are required", 400)

    try:
        user, _ = UserService.create_user(username, email, full_name, password)
        db.session.commit()
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 409)
    except IntegrityError:
        db.session.rollback()
        return error_response("Failed to create user", 500)

    token_value = AuthTokenService.issue_token(user.id)
    db.session.commit()

    data = UserService.get_user_payload(user)
    data["token"] = token_value
    return success_response("Account created", data, 201)


@auth_bp.route("/login", methods=["POST"])
def login():
    payload = request.get_json(silent=True) or {}
    identifier = (payload.get("email") or payload.get("username") or "").strip()
    password = payload.get("password")

    if not identifier or not password:
        return error_response("email/username and password are required", 400)

    user = UserDAO.get_by_identifier(identifier)
    if not user or not user.check_password(password):
        return error_response("Invalid credentials", 401)

    token_value = AuthTokenService.issue_token(user.id)
    db.session.commit()

    data = UserService.get_user_payload(user)
    data["token"] = token_value
    return success_response("Logged in", data)


@auth_bp.route("/logout", methods=["POST"])
@token_required
def logout():
    token_value = get_current_token_value() or AuthTokenService.extract_bearer_token(request.headers.get("Authorization"))
    if token_value:
        AuthTokenService.revoke_token(token_value)
        db.session.commit()
    return success_response("Logged out", {})
