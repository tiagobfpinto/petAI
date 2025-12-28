from __future__ import annotations

from ..models import db
from ..models.event_log import EventLog


class EventService:
    @staticmethod
    def log_event(
        user_id: int | None,
        event_name: str,
        payload: dict | None = None,
    ) -> EventLog:
        event_name = event_name.strip()
        if not event_name:
            raise ValueError("event_name is required")
        entry = EventLog(
            user_id=user_id,
            event_name=event_name,
            payload=payload or {},
        )
        db.session.add(entry)
        return entry
