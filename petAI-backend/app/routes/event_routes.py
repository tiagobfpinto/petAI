from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.event_service import EventService


events_bp = Blueprint("events", __name__, url_prefix="/events")


@events_bp.route("/log", methods=["POST"])
@token_required
def log_event():
    user_id = get_current_user_id()
    payload = request.get_json(silent=True) or {}
    event_name = (payload.get("event") or payload.get("event_name") or "").strip()
    meta = payload.get("payload")
    if event_name == "":
        return error_response("event_name is required", 400)
    if meta is not None and not isinstance(meta, dict):
        return error_response("payload must be an object", 400)

    try:
        entry = EventService.log_event(user_id, event_name, meta)
        db.session.commit()
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Event logged", {"event": entry.to_dict()}, 201)
