import os
from typing import Optional
from dotenv import load_dotenv

import firebase_admin
from firebase_admin import credentials, firestore

_initialized = False
_client: Optional[firestore.Client] = None


def init_firebase() -> Optional[firestore.Client]:
    load_dotenv()
    global _initialized, _client
    if _initialized and _client is not None:
        return _client

    project_id = os.getenv("FIREBASE_PROJECT_ID")
    sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")

    try:
        if not firebase_admin._apps:
            if sa_path and os.path.exists(sa_path):
                cred = credentials.Certificate(sa_path)
                firebase_admin.initialize_app(cred, {"projectId": project_id} if project_id else None)
            else:
                firebase_admin.initialize_app()
        _client = firestore.client()
        _initialized = True
        return _client
    except Exception:
        return None


def get_client() -> Optional[firestore.Client]:
    return _client if _initialized else init_firebase()