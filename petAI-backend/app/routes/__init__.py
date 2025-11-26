from __future__ import annotations

from flask import jsonify


def success_response(message: str, data: dict | None = None, status_code: int = 200):
    payload = {"message": message, "data": data or {}}
    return jsonify(payload), status_code


def error_response(message: str, status_code: int = 400):
    return jsonify({"error": message}), status_code
