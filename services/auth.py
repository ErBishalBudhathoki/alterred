"""
Authentication Service
======================
Handles user authentication via Firebase Auth.
Extracts and verifies ID tokens from the Authorization header.

Implementation Details:
- Uses `firebase_admin.auth` to verify tokens.
- Expects `Authorization: Bearer <token>`.

Design Decisions:
- Falls back to `os.getenv("USER")` or "terminal_user" if auth fails or is unconfigured.
  This simplifies local development and testing without requiring a full Firebase setup.
"""
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
    """
    Extracts the user ID from the request headers.
    
    Args:
        request (Request): The FastAPI request object.
        
    Returns:
        str: The authenticated user ID, or a fallback value.
    """
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
