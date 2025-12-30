from __future__ import annotations

from ..models.chest import Chest


class ChestDAO:
    @staticmethod
    def get_by_item_id(item_id: int) -> Chest | None:
        return Chest.query.filter_by(item_id=item_id).first()

    @staticmethod
    def list_chests() -> list[Chest]:
        return Chest.query.order_by(Chest.item_id.asc()).all()

    @staticmethod
    def list_chests_by_tier(tier: str | None) -> list[Chest]:
        if not tier:
            return ChestDAO.list_chests()
        normalized = tier.strip().lower()
        return Chest.query.filter(Chest.tier.ilike(normalized)).order_by(Chest.item_id.asc()).all()
