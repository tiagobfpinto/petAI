from __future__ import annotations

from functools import wraps

from flask import Blueprint, current_app, redirect, render_template, request, session, url_for
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from sqlalchemy import or_

from ..dao.chestDAO import ChestDAO
from ..dao.itemsDAO import ItemOwnershipDAO
from ..models import Admin_Users, db
from ..models.user import User
from ..routes import error_response, success_response
from ..services.auth_token_service import AuthTokenService
from ..services.chest_service import ChestService
from ..services.pet_service import PetService


admin_bp = Blueprint("admin", __name__, url_prefix="/admin")


def _wants_json_response() -> bool:
    accept = (request.headers.get("Accept") or "").lower()
    return request.is_json or "application/json" in accept


def _admin_token_serializer() -> URLSafeTimedSerializer | None:
    secret_key = current_app.secret_key or current_app.config.get("SECRET_KEY")
    if not secret_key:
        return None
    return URLSafeTimedSerializer(secret_key, salt="admin-token")


def _issue_admin_token(admin: Admin_Users) -> str | None:
    serializer = _admin_token_serializer()
    if not serializer:
        return None
    return serializer.dumps({"admin_id": admin.id})


def _extract_admin_token() -> str | None:
    auth_header = request.headers.get("Authorization")
    token = AuthTokenService.extract_bearer_token(auth_header)
    if token:
        return token
    return None


def _load_admin_from_token(token: str) -> Admin_Users | None:
    serializer = _admin_token_serializer()
    if not serializer:
        return None
    ttl = current_app.config.get("ADMIN_TOKEN_TTL_SECONDS")
    max_age = int(ttl) if isinstance(ttl, int) and ttl > 0 else None
    try:
        payload = serializer.loads(token, max_age=max_age)
    except (BadSignature, SignatureExpired):
        return None
    admin_id = payload.get("admin_id") if isinstance(payload, dict) else None
    if not admin_id:
        return None
    return db.session.get(Admin_Users, admin_id)


def admin_login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        admin_id = session.get("admin_id")
        admin = None
        if admin_id:
            admin = db.session.get(Admin_Users, admin_id)
            if not admin:
                session.pop("admin_id", None)

        if not admin:
            token = _extract_admin_token()
            if token:
                admin = _load_admin_from_token(token)

        if not admin:
            if _wants_json_response():
                return error_response("Admin authentication required", 401)
            return redirect(url_for("admin.login", next=request.full_path))

        setattr(request, "current_admin", admin)
        return fn(*args, **kwargs)

    return wrapper


def _safe_next_url(raw_next: str | None) -> str | None:
    if not raw_next:
        return None
    raw_next = raw_next.strip()
    if raw_next.startswith("/") and not raw_next.startswith("//"):
        return raw_next
    return None


@admin_bp.route("/", methods=["GET"])
@admin_login_required
def dashboard():
    admin = getattr(request, "current_admin", None)
    return render_template("admin/dashboard.html", admin=admin)


@admin_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        if session.get("admin_id"):
            return redirect(url_for("admin.dashboard"))
        next_url = _safe_next_url(request.args.get("next"))
        return render_template("admin/login.html", error=None, next=next_url)

    payload = request.get_json(silent=True) if request.is_json else None
    form = request.form if payload is None else None

    identifier = (
        ((payload or {}).get("identifier") if payload is not None else None)
        or ((payload or {}).get("email") if payload is not None else None)
        or ((payload or {}).get("username") if payload is not None else None)
        or ((form or {}).get("identifier") if form is not None else None)
        or ((form or {}).get("email") if form is not None else None)
        or ((form or {}).get("username") if form is not None else None)
        or ""
    ).strip()
    password = (
        ((payload or {}).get("password") if payload is not None else None)
        or ((form or {}).get("password") if form is not None else None)
        or ""
    )
    next_url = _safe_next_url(
        ((payload or {}).get("next") if payload is not None else None) or ((form or {}).get("next") if form is not None else None)
    )

    if not identifier or not password:
        if _wants_json_response():
            return error_response("identifier and password are required", 400)
        return render_template("admin/login.html", error="Identifier and password are required", next=next_url), 400

    identifier_email = identifier.lower()
    admin = (
        db.session.query(Admin_Users)
        .filter(or_(Admin_Users.email == identifier_email, Admin_Users.username == identifier))
        .first()
    )
    if not admin or not admin.password_hash or not admin.check_password(password):
        if _wants_json_response():
            return error_response("Invalid credentials", 401)
        return render_template("admin/login.html", error="Invalid credentials", next=next_url), 401

    session["admin_id"] = admin.id

    if _wants_json_response():
        payload = {"admin": admin.to_dict()}
        token = _issue_admin_token(admin)
        if token:
            payload["admin_token"] = token
        return success_response("Admin logged in", payload)

    return redirect(next_url or url_for("admin.dashboard"))


@admin_bp.route("/logout", methods=["POST", "GET"])
def logout():
    session.pop("admin_id", None)
    if _wants_json_response():
        return success_response("Admin logged out", {})
    return redirect(url_for("admin.login"))


@admin_bp.route("/api/users", methods=["GET"])
@admin_login_required
def list_users():
    query = (request.args.get("query") or "").strip()
    limit = request.args.get("limit", type=int) or 50
    limit = min(max(limit, 1), 200)

    if query:
        like = f"%{query}%"
        users = (
            User.query.filter(or_(User.username.ilike(like), User.email.ilike(like)))
            .order_by(User.created_at.desc())
            .limit(limit)
            .all()
        )
    else:
        users = User.query.order_by(User.created_at.desc()).limit(limit).all()

    return success_response("Users", {"users": [user.to_dict() for user in users]})


@admin_bp.route("/api/users/<int:user_id>", methods=["GET"])
@admin_login_required
def get_user(user_id: int):
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found", 404)
    return success_response("User", {"user": user.to_dict()})


@admin_bp.route("/api/users/<int:user_id>/coins", methods=["POST"])
@admin_login_required
def update_user_coins(user_id: int):
    payload = request.get_json(silent=True) or {}
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found", 404)

    if "coins" in payload:
        try:
            coins = int(payload.get("coins"))
        except (TypeError, ValueError):
            return error_response("coins must be an integer", 400)
        user.coins = max(0, coins)
    elif "delta" in payload:
        try:
            delta = int(payload.get("delta"))
        except (TypeError, ValueError):
            return error_response("delta must be an integer", 400)
        user.coins = max(0, (user.coins or 0) + delta)
    else:
        return error_response("coins or delta is required", 400)

    db.session.commit()
    return success_response("Coins updated", {"user_id": user.id, "coins": user.coins})


@admin_bp.route("/api/users/<int:user_id>/chests", methods=["POST"])
@admin_login_required
def grant_chests(user_id: int):
    payload = request.get_json(silent=True) or {}
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found", 404)

    quantity_raw = payload.get("quantity", 1)
    try:
        quantity = int(quantity_raw)
    except (TypeError, ValueError):
        return error_response("quantity must be an integer", 400)
    if quantity <= 0:
        return error_response("quantity must be greater than zero", 400)
    if quantity > 100:
        return error_response("quantity too large", 400)

    chest_item_id = payload.get("item_id")
    tier = (payload.get("tier") or "").strip().lower() or None
    if tier and tier not in ChestService.CHEST_TIERS:
        return error_response("Invalid tier", 400)

    if chest_item_id is not None:
        try:
            chest_item_id = int(chest_item_id)
        except (TypeError, ValueError):
            return error_response("item_id must be an integer", 400)
        chest = ChestDAO.get_by_item_id(chest_item_id)
        if not chest:
            return error_response("Chest not found", 404)
        pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
        owned = ItemOwnershipDAO.get_item_from_inventory(user_id, chest_item_id)
        if owned:
            owned.quantity = (owned.quantity or 0) + quantity
            db.session.add(owned)
        else:
            ItemOwnershipDAO.create_item_ownership(user_id, chest_item_id, pet.id, quantity)
        db.session.commit()
        return success_response(
            "Chests granted",
            {"user_id": user.id, "quantity": quantity, "chest_item_id": chest_item_id},
        )

    granted = []
    for _ in range(quantity):
        reward = ChestService.grant_chest(user_id=user.id, tier=tier)
        if reward:
            granted.append(reward)

    db.session.commit()
    return success_response(
        "Chests granted",
        {"user_id": user.id, "quantity": len(granted), "tier": tier, "granted": granted},
    )
