from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import and_, or_

from ..dao.userDAO import UserDAO
from ..models import db
from ..models.friend_request import FriendRequest
from ..services.pet_service import PetService


class FriendService:
    @staticmethod
    def send_request(user_id: int, target_username: str) -> FriendRequest:
        target = UserDAO.get_by_username(target_username.strip())
        if not target:
            raise LookupError("User not found")
        if target.id == user_id:
            raise ValueError("You cannot add yourself")

        existing = FriendService._request_between(user_id, target.id)
        if existing:
            if existing.status == "accepted":
                raise ValueError("You are already friends")
            if existing.receiver_id == user_id and existing.status == "pending":
                # The other user already sent a request; auto-accept.
                existing.status = "accepted"
                existing.responded_at = datetime.now(timezone.utc)
                db.session.add(existing)
                return existing
            raise ValueError("A request is already pending between you")

        request = FriendRequest(
            requester_id=user_id,
            receiver_id=target.id,
            status="pending",
        )
        db.session.add(request)
        return request

    @staticmethod
    def accept_request(user_id: int, request_id: int) -> FriendRequest:
        request = FriendRequest.query.get(request_id)
        if not request or request.receiver_id != user_id:
            raise LookupError("Friend request not found")
        if request.status == "accepted":
            return request
        request.status = "accepted"
        request.responded_at = datetime.now(timezone.utc)
        db.session.add(request)
        return request

    @staticmethod
    def friends_payload(user_id: int) -> dict:
        accepted = FriendRequest.query.filter(
            and_(
                FriendRequest.status == "accepted",
                or_(FriendRequest.requester_id == user_id, FriendRequest.receiver_id == user_id),
            )
        ).all()

        friends = []
        for fr in accepted:
            other = fr.requester if fr.receiver_id == user_id else fr.receiver
            if other is None:
                continue
            pet = PetService.get_pet_by_user(other.id) or PetService.create_pet(other.id)
            friends.append(
                {
                    "id": other.id,
                    "username": FriendService._display_name(other.username, other.id),
                    "pet_stage": pet.stage,
                    "pet_level": pet.level,
                    "pet_xp": pet.xp,
                    "pet_next_evolution_xp": pet.next_evolution_xp,
                    "pet_type": pet.pet_type,
                    "pet_current_sprite": pet.current_sprite,
                    "pet_cosmetics": PetService.cosmetic_payload(pet.user_id),
                }
            )

        incoming = FriendRequest.query.filter_by(receiver_id=user_id, status="pending").all()
        outgoing = FriendRequest.query.filter_by(requester_id=user_id, status="pending").all()

        return {
            "friends": friends,
            "incoming": [
                {
                    "request_id": req.id,
                    "from_username": FriendService._display_name(req.requester.username if req.requester else None, req.requester_id),
                    "status": req.status,
                }
                for req in incoming
            ],
            "outgoing": [
                {
                    "request_id": req.id,
                    "to_username": FriendService._display_name(req.receiver.username if req.receiver else None, req.receiver_id),
                    "status": req.status,
                }
                for req in outgoing
            ],
        }

    @staticmethod
    def _request_between(user_a: int, user_b: int) -> FriendRequest | None:
        return (
            FriendRequest.query.filter(
                or_(
                    and_(FriendRequest.requester_id == user_a, FriendRequest.receiver_id == user_b),
                    and_(FriendRequest.requester_id == user_b, FriendRequest.receiver_id == user_a),
                )
            )
            .order_by(FriendRequest.created_at.desc())
            .first()
        )

    @staticmethod
    def _display_name(username: str | None, fallback_id: int | None) -> str:
        if username:
            return username
        return f"Guest#{fallback_id or 0}"
