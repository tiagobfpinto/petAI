from __future__ import annotations

from ..models import db
from ..models.milestone_redemption import MilestoneRedemption


class MilestoneRedemptionDAO:
    @staticmethod
    def get(user_id: int, milestone_id: str) -> MilestoneRedemption | None:
        if not milestone_id:
            return None
        return MilestoneRedemption.query.filter_by(
            user_id=user_id, milestone_id=milestone_id
        ).first()

    @staticmethod
    def redeemed_ids(user_id: int) -> set[str]:
        rows = MilestoneRedemption.query.filter_by(user_id=user_id).all()
        return {row.milestone_id for row in rows if row.milestone_id}

    @staticmethod
    def create(user_id: int, milestone_id: str) -> MilestoneRedemption:
        redemption = MilestoneRedemption(
            user_id=user_id,
            milestone_id=milestone_id,
        )
        db.session.add(redemption)
        db.session.flush()
        return redemption
