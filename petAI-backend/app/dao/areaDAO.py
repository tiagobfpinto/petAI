from __future__ import annotations

from sqlalchemy import func

from ..models import db
from ..models.areas import Area


class AreaDAO:
    @staticmethod
    def create(user_id: int, name: str) -> Area:
        area = Area(
            user_id=user_id,
            name=name,
        )
        db.session.add(area)
        return area

    @staticmethod
    def list_for_user(user_id: int) -> list[Area]:
        return Area.query.filter_by(user_id=user_id).order_by(Area.id.asc()).all()

    @staticmethod
    def get_by_user_and_name(user_id: int, name: str) -> Area | None:
        lowered = name.strip().lower()
        return (
            Area.query.filter(Area.user_id == user_id)
            .filter(func.lower(Area.name) == lowered)
            .first()
        )

    @staticmethod
    def get_by_user_and_id(user_id: int, area_id: int) -> Area | None:
        return Area.query.filter_by(user_id=user_id, id=area_id).first()

    @staticmethod
    def delete_for_user(user_id: int) -> None:
        Area.query.filter_by(user_id=user_id).delete(synchronize_session=False)

    @staticmethod
    def save(area: Area) -> Area:
        db.session.add(area)
        return area
