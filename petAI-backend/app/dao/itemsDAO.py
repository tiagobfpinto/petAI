from __future__ import annotations

from ..models import db
from ..models.pet import Pet
from ..models.storeListing import StoreListing
from ..models.item import Item
from ..models.user import User
from .userDAO import UserDAO
from ..models.itemOwnership import ItemOwnership
class ItemsDAO:
    @staticmethod
    def get_item_by_id(item_id: int) -> Item | None:
        return Item.query.filter_by(id=item_id).first()
    
    @staticmethod
    def get_store_listing_by_id(store_listing_id: int) -> StoreListing | None:
        return StoreListing.query.filter_by(id=store_listing_id).first()
    
    @staticmethod
    def get_price_of_listing(store_listing_id: int) -> int | None:
        listing = StoreListing.query.filter_by(id=store_listing_id).first()
        if listing:
            return listing.price
        return None
    
    @staticmethod
    def get_all_store_listings() -> list[StoreListing]:
        return StoreListing.query.filter_by(active=True).all()

    
class ItemOwnershipDAO:
 
    
    @staticmethod
    def get_item_from_inventory(user_id,item_id) -> ItemOwnership | None:
        return ItemOwnership.query.filter_by(user_id= user_id,item_id=item_id).first()
    
    @staticmethod
    def get_items_owned_by_user(user_id: int) -> list[ItemOwnership]:
        return ItemOwnership.query.filter_by(user_id=user_id).all()
    
    @staticmethod
    def add_item_to_user_inventory(user_id: int, item_id: int, quantity: int) -> None:
        item = ItemsDAO.get_item_by_id(item_id)
        if not item:
            raise ValueError("Item not found")
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise ValueError("User not found")
        ItemOwnershipDAO.create_item_ownership(user_id, item_id,user.pet.id,quantity)
        
    @staticmethod
    def create_item_ownership(user_id: int, item_id: int,pet_id:int,quantity:int) -> ItemOwnership:
        try:
            item_ownership = ItemOwnership(user_id=user_id, item_id=item_id, pet_id=pet_id,acquired_at=db.func.now(), quantity=quantity)
            db.session.add(item_ownership)
        except Exception as e:
            db.session.rollback()
            raise e
        return item_ownership
     
     
class StoreListingDAO:
    @staticmethod
    def get_store_listing_by_id(store_listing_id: int) -> StoreListing | None:
        return StoreListing.query.filter_by(id=store_listing_id).first()
