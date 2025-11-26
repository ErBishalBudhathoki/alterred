"""
Firebase Client
===============
Provides a singleton Firestore client instance for the application.
Handles initialization using credentials from environment variables or default application credentials.

Implementation Details:
- Uses `firebase_admin` to initialize the app.
- Returns a `firestore.client()` instance.
- Implements a singleton pattern to avoid multiple initializations.

Design Decisions:
- Supports both local development (via service account path) and cloud environments (default creds).
- Lazy initialization via `get_client()`.
"""
import os
from typing import Optional
from dotenv import load_dotenv

import firebase_admin
from firebase_admin import credentials, firestore

_initialized = False
_client: Optional[firestore.Client] = None


def init_firebase() -> Optional[firestore.Client]:
    """
    Initializes the Firebase Admin SDK and Firestore client.
    
    Reads configuration from environment variables:
    - FIREBASE_PROJECT_ID: The Google Cloud project ID.
    - FIREBASE_SERVICE_ACCOUNT_PATH: Path to the service account JSON key (optional).
    
    Returns:
        Optional[firestore.Client]: The initialized Firestore client, or None on failure.
    """
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
    """
    Retrieves the singleton Firestore client instance.
    Initializes it if necessary.
    
    Returns:
        Optional[firestore.Client]: The Firestore client.
    """
    return _client if _initialized else init_firebase()