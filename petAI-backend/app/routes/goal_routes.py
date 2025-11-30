from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.goal_service import GoalService

goal_bp = Blueprint("goals", __name__, url_prefix="/goals")


def _resolve_interest_name(payload: dict | None = None) -> str:
    payload = payload or {}
    name = (payload.get("interest") or payload.get("interest_name") or "").strip()
    if name:
        return name
    return (request.args.get("interest") or "").strip()


@goal_bp.route("/suggestions", methods=["GET"])
@token_required
def goal_suggestions():
    user_id = get_current_user_id()
    interest_name = _resolve_interest_name()
    if not user_id:
        return error_response("user_id is required", 400)
    if not interest_name:
        return error_response("interest is required", 400)

    try:
        payload = GoalService.suggestions_for_interest(user_id, interest_name)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)

    return success_response("Goal suggestions ready", payload)


@goal_bp.route("/monthly", methods=["POST"])
@token_required
def set_monthly_goal():
    payload = request.get_json(silent=True) or {}
    user_id = get_current_user_id()
    interest_name = _resolve_interest_name(payload)
    if not user_id:
        return error_response("user_id is required", 400)
    if not interest_name:
        return error_response("interest is required", 400)

    monthly_goal = payload.get("monthly_goal")
    if monthly_goal is None:
        return error_response("monthly_goal is required", 400)
    try:
        monthly_goal_val = float(monthly_goal)
    except (TypeError, ValueError):
        return error_response("monthly_goal must be a number", 400)
    if monthly_goal_val <= 0:
        return error_response("monthly_goal must be greater than zero", 400)

    unit = (payload.get("unit") or payload.get("target_unit") or "").strip() or None

    try:
        interest = GoalService.set_monthly_goal(user_id, interest_name, monthly_goal_val, unit=unit)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response(
        "Monthly goal updated",
        {"interest": interest.to_dict()},
        200,
    )
