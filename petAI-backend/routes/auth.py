from flask import Blueprint, jsonify, request
from flask_login import login_user
from sqlalchemy.exc import IntegrityError

try:
    from ..models.user.user import User, db
except ImportError:
    from models.user.user import User, db


auth_bp = Blueprint("auth", __name__, url_prefix="/auth")



def _user_payload(user):
    """Serialize user data for API responses."""
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "full_name": user.full_name,
        "plan": user.plan.value if user.plan else None,
    }


@auth_bp.route("/register", methods=["POST"])
def register():
    payload = request.get_json(silent=True) or {}
    username = (payload.get("username") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password")
    full_name = (payload.get("full_name") or None)

    if not username or not email or not password:
        return jsonify({"error": "username, email, and password are required"}), 400

    existing_user = User.query.filter(
        (User.username == username) | (User.email == email)
    ).first()
    if existing_user:
        return (
            jsonify({"error": "User with provided username or email already exists"}),
            409,
        )

    user = User(username=username, email=email, full_name=full_name)
    user.set_password(password)

    db.session.add(user)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "Failed to create user"}), 500

    login_user(user)
    return jsonify({"message": "Account created", "user": _user_payload(user)}), 201


@auth_bp.route("/login", methods=["POST"])
def login():
    payload = request.get_json(silent=True) or {}
    identifier = (payload.get("email") or payload.get("username") or "").strip()
    password = payload.get("password")

    if not identifier or not password:
        return jsonify({"error": "email/username and password are required"}), 400

    user = User.query.filter(
        (User.email == identifier.lower()) | (User.username == identifier)
    ).first()

    if not user or not user.check_password(password):
        return jsonify({"error": "Invalid credentials"}), 401

    login_user(user)
    return jsonify({"message": "Logged in", "user": _user_payload(user)})
