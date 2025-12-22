"""
User Settings Service
=====================
User-specific settings management with encryption support.
Handles secure storage and retrieval of sensitive configuration like API keys and OAuth tokens.

Implementation Details:
- Uses `cryptography.fernet` for symmetric encryption of sensitive data.
- Stores settings in Firestore under `users/{uid}/settings` and `users/{uid}/oauth_tokens`.
- Requires `ENCRYPTION_KEY` environment variable for initializing the cipher.

Design Decisions:
- Segregates OAuth tokens by provider (e.g., "google_calendar") for extensibility.
- Stores encrypted values in the database; decryption happens only in memory within this service.
- Includes a validation step (`validate_api_key`) before saving custom API keys to prevent bad config.

Behavioral Specifications:
- `save_api_key`: Encrypts and saves the user's Gemini API key.
- `get_api_key`: Retrieves and decrypts the stored API key.
- `save_oauth_tokens`: Encrypts and saves OAuth access/refresh tokens.
- `get_oauth_tokens`: Retrieves and decrypts OAuth tokens for a specific provider.
- `validate_api_key`: Static method to test if a Gemini API key is valid.
"""

import os
from typing import Optional, Dict, Any
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import base64
import secrets
from cryptography.fernet import Fernet
from google.genai import Client as GenAIClient
from firebase_admin import firestore
from services.firebase_client import get_client


class UserSettings:
    """Manage user-specific settings with encryption."""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = get_client()
        
        # Get encryption key from environment
        encryption_key = os.getenv("ENCRYPTION_KEY")
        if not encryption_key:
            raise ValueError("ENCRYPTION_KEY environment variable not set")
        self._master_secret = encryption_key.encode()
    
    def _derive_key(self, salt: bytes) -> bytes:
        hkdf = HKDF(
            algorithm=hashes.SHA256(), length=32, salt=salt, info=b"gemini-user-key", backend=default_backend()
        )
        return hkdf.derive(self._master_secret)

    def _encrypt_aes(self, data: str) -> Dict[str, str]:
        salt = secrets.token_bytes(16)
        key = self._derive_key(salt)
        iv = secrets.token_bytes(12)
        encryptor = Cipher(algorithms.AES(key), modes.GCM(iv), backend=default_backend()).encryptor()
        ct = encryptor.update(data.encode()) + encryptor.finalize()
        tag = encryptor.tag
        return {
            "enc_version": "2",
            "salt": base64.b64encode(salt).decode(),
            "iv": base64.b64encode(iv).decode(),
            "tag": base64.b64encode(tag).decode(),
            "ciphertext": base64.b64encode(ct).decode(),
        }

    def _decrypt_aes(self, payload: Dict[str, Any]) -> str:
        salt = base64.b64decode(payload["salt"])
        iv = base64.b64decode(payload["iv"])
        tag = base64.b64decode(payload["tag"])
        ct = base64.b64decode(payload["ciphertext"])
        key = self._derive_key(salt)
        decryptor = Cipher(algorithms.AES(key), modes.GCM(iv, tag), backend=default_backend()).decryptor()
        pt = decryptor.update(ct) + decryptor.finalize()
        return pt.decode()
    
    # ===== Gemini API Key Management =====
    
    def save_api_key(self, api_key: str) -> Dict[str, Any]:
        """
        Save user's Gemini API key (encrypted).
        Validates key before saving.
        """
        # Validate API key
        valid, error = self.validate_api_key(api_key)
        if not valid:
            return {"ok": False, "error": error}
        
        try:
            aes_payload = self._encrypt_aes(api_key)
            self.db.collection("users").document(self.user_id).collection("settings").document("api_config").set({
                "gemini_api_key": aes_payload,
                "has_custom_key": True,
                "updated_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    def get_api_key(self) -> Optional[str]:
        """
        Retrieve user's Gemini API key (decrypted).
        Returns None if not set.
        """
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("api_config").get()
            
            if not doc.exists:
                return None
            
            data = doc.to_dict()
            if not data:
                return None
            # Prefer AES payload
            aes_payload = data.get("gemini_api_key")
            if aes_payload and isinstance(aes_payload, dict):
                try:
                    return self._decrypt_aes(aes_payload)
                except Exception:
                    return None
            # Legacy fallback
            legacy = data.get("gemini_api_key_encrypted")
            if legacy:
                try:
                    # Backward-compatibility: decrypt legacy Fernet keys so users aren't broken
                    f = Fernet(self._master_secret)
                    return f.decrypt(legacy.encode()).decode()
                except Exception:
                    return None
            return None
        except Exception:
            return None
    
    def has_custom_api_key(self) -> bool:
        """Check if user has set a custom API key."""
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("api_config").get()
            
            if not doc.exists:
                return False
            
            data = doc.to_dict()
            return data.get("has_custom_key", False)
        except Exception:
            return False
    
    def delete_api_key(self) -> Dict[str, Any]:
        """Remove user's custom API key."""
        try:
            self.db.collection("users").document(self.user_id).collection("settings").document("api_config").set({
                "gemini_api_key": firestore.DELETE_FIELD,
                "gemini_api_key_encrypted": firestore.DELETE_FIELD,
                "has_custom_key": False,
                "updated_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    @staticmethod
    def validate_api_key(api_key: str) -> tuple[bool, Optional[str]]:
        """
        Validate Gemini API key by making a test request.
        Returns (is_valid, error_message).
        """
        try:
            client = GenAIClient(api_key=api_key)
            # Try to list models as a validation check
            models = client.models.list()
            list(models)  # Force evaluation
            
            return (True, None)
        except Exception as e:
            error_msg = str(e)
            if "API key not valid" in error_msg or "invalid" in error_msg.lower():
                return (False, "Invalid API key")
            elif "quota" in error_msg.lower():
                return (False, "API key quota exceeded")
            else:
                return (False, f"Validation error: {error_msg}")
    
    # ===== OAuth Token Management =====
    
    def save_oauth_tokens(self, provider: str, access_token: str, refresh_token: str, expires_at: str, scopes: list[str]) -> Dict[str, Any]:
        """
        Save OAuth tokens (encrypted) for a provider.
        Provider examples: 'google_calendar', 'google_drive'
        """
        try:
            enc_access = self._encrypt_aes(access_token)
            enc_refresh = self._encrypt_aes(refresh_token)
            self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).set({
                "provider": provider,
                "access_token": enc_access,
                "refresh_token": enc_refresh,
                "expires_at": expires_at,
                "scopes": scopes,
                "updated_at": firestore.SERVER_TIMESTAMP
            })
            
            # Update settings to reflect connection status
            self.db.collection("users").document(self.user_id).collection("settings").document("integrations").set({
                f"{provider}_connected": True,
                f"{provider}_connected_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    def get_oauth_tokens(self, provider: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve OAuth tokens (decrypted) for a provider.
        Returns None if not set.
        """
        try:
            doc = self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).get()
            
            if not doc.exists:
                return None
            
            data = doc.to_dict() or {}
            access_payload = data.get("access_token")
            refresh_payload = data.get("refresh_token")
            access_token = None
            refresh_token = None
            if isinstance(access_payload, dict):
                try:
                    access_token = self._decrypt_aes(access_payload)
                except Exception:
                    access_token = None
            if isinstance(refresh_payload, dict):
                try:
                    refresh_token = self._decrypt_aes(refresh_payload)
                except Exception:
                    refresh_token = None
            # Legacy support
            enc_access = data.get("access_token_encrypted")
            if access_token is None and isinstance(enc_access, str):
                try:
                    f = Fernet(self._master_secret)
                    access_token = f.decrypt(enc_access.encode()).decode()
                except Exception:
                    access_token = None
            enc_refresh = data.get("refresh_token_encrypted")
            if refresh_token is None and isinstance(enc_refresh, str):
                try:
                    f = Fernet(self._master_secret)
                    refresh_token = f.decrypt(enc_refresh.encode()).decode()
                except Exception:
                    refresh_token = None
            if not access_token or not refresh_token:
                return None
            return {
                "provider": data.get("provider"),
                "access_token": access_token,
                "refresh_token": refresh_token,
                "expires_at": data.get("expires_at"),
                "scopes": data.get("scopes", [])
            }
        except Exception:
            return None
    
    def delete_oauth_tokens(self, provider: str) -> Dict[str, Any]:
        """Revoke/delete OAuth tokens for a provider."""
        try:
            self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).delete()
            
            # Update settings
            self.db.collection("users").document(self.user_id).collection("settings").document("integrations").set({
                f"{provider}_connected": False,
                f"{provider}_disconnected_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    def is_oauth_connected(self, provider: str) -> bool:
        """Check if user has connected OAuth for a provider."""
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("integrations").get()
            
            if not doc.exists:
                return False
            
            data = doc.to_dict()
            return data.get(f"{provider}_connected", False)
        except Exception:
            return False

    def has_oauth_tokens(self, provider: str) -> bool:
        """Return True if an OAuth token document exists for provider."""
        try:
            doc = self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).get()
            if not doc.exists:
                return False
            data = doc.to_dict() or {}
            # Consider tokens present if at least access token payload exists
            return bool(data.get("access_token") or data.get("access_token_encrypted"))
        except Exception:
            return False

    def get_oauth_token_metadata(self, provider: str) -> Dict[str, Any]:
        """Return non-sensitive OAuth metadata without decrypting tokens."""
        try:
            doc = self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).get()
            if not doc.exists:
                return {}
            data = doc.to_dict() or {}
            return {
                "expires_at": data.get("expires_at"),
                "scopes": data.get("scopes", [])
            }
        except Exception:
            return {}

    def save_profile_email(self, email: str) -> Dict[str, Any]:
        try:
            self.db.collection("users").document(self.user_id).collection("settings").document("profile").set({
                "email": email,
                "updated_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def get_profile_email(self) -> Optional[str]:
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("profile").get()
            if not doc.exists:
                return None
            data = doc.to_dict()
            return data.get("email")
        except Exception:
            return None

    # ===== Notion Token Management =====
    
    def save_notion_token(self, token: str) -> Dict[str, Any]:
        """
        Save user's Notion integration token (encrypted).
        Token should start with 'ntn_' for internal integrations.
        """
        try:
            enc_token = self._encrypt_aes(token)
            self.db.collection("users").document(self.user_id).collection("settings").document("notion").set({
                "token": enc_token,
                "connected": True,
                "updated_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    def get_notion_token(self) -> Optional[str]:
        """
        Retrieve user's Notion token (decrypted).
        Returns None if not set.
        """
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("notion").get()
            
            if not doc.exists:
                return None
            
            data = doc.to_dict()
            if not data:
                return None
            
            enc_payload = data.get("token")
            if enc_payload and isinstance(enc_payload, dict):
                try:
                    return self._decrypt_aes(enc_payload)
                except Exception:
                    return None
            return None
        except Exception:
            return None
    
    def is_notion_connected(self) -> bool:
        """Check if user has connected Notion."""
        try:
            doc = self.db.collection("users").document(self.user_id).collection("settings").document("notion").get()
            
            if not doc.exists:
                return False
            
            data = doc.to_dict()
            return data.get("connected", False)
        except Exception:
            return False
    
    def delete_notion_token(self) -> Dict[str, Any]:
        """Remove user's Notion token."""
        try:
            self.db.collection("users").document(self.user_id).collection("settings").document("notion").set({
                "token": firestore.DELETE_FIELD,
                "connected": False,
                "disconnected_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "error": str(e)}
