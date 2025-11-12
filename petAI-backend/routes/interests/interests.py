from flask import Blueprint, jsonify, request
from flask_login import login_user
from sqlalchemy.exc import IntegrityError

try:
    from ...models.user.user import User, db
except ImportError:
    from models.user.user import User, db


auth_bp = Blueprint("interests", __name__, url_prefix="/interests")
