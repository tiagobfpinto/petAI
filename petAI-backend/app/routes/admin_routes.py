from __future__ import annotations

from functools import wraps

from flask import Blueprint, redirect, render_template, request, session, url_for
from sqlalchemy import or_

from ..models import Admin_Users, db
from ..routes import error_response, success_response


admin_bp = Blueprint("admin", __name__, url_prefix="/admin")


def _wants_json_response() -> bool:
    accept = (request.headers.get("Accept") or "").lower()
    return request.is_json or "application/json" in accept


def admin_login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        admin_id = session.get("admin_id")
        if not admin_id:
            if _wants_json_response():
                return error_response("Admin authentication required", 401)
            return redirect(url_for("admin.login", next=request.full_path))

        admin = db.session.get(Admin_Users, admin_id)
        if not admin:
            session.pop("admin_id", None)
            if _wants_json_response():
                return error_response("Invalid admin session", 401)
            return redirect(url_for("admin.login"))

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
        return success_response("Admin logged in", {"admin": admin.to_dict()})

    return redirect(next_url or url_for("admin.dashboard"))


@admin_bp.route("/logout", methods=["POST", "GET"])
def logout():
    session.pop("admin_id", None)
    if _wants_json_response():
        return success_response("Admin logged out", {})
    return redirect(url_for("admin.login"))
