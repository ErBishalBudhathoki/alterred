from typing import Optional
from fastapi import Request
import os

try:
    import firebase_admin
    from firebase_admin import auth as fb_auth
except Exception:
    firebase_admin = None
    fb_auth = None


def get_user_id_from_request(request: Request) -> str:
    auth_header: Optional[str] = request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer ") and fb_auth:
        token = auth_header.split(" ", 1)[1]
        try:
            decoded = fb_auth.verify_id_token(token)
            uid = decoded.get("uid")
            if uid:
                return uid
        except Exception:
            pass
    return os.getenv("USER") or "terminal_user"