"""
User-specific settings management with encryption support.
Handles:
- Gemini API key storage/retrieval
- OAuth token storage/retrieval  
- Encryption/decryption of sensitive data
- API key validation
"""

import os
from typing import Optional, Dict, Any
from cryptography.fernet import Fernet
import google.generativeai as genai
from firebase_admin import firestore


class UserSettings:
    """Manage user-specific settings with encryption."""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
        
        # Get encryption key from environment
        encryption_key = os.getenv("ENCRYPTION_KEY")
        if not encryption_key:
            raise ValueError("ENCRYPTION_KEY environment variable not set")
        
        self.cipher = Fernet(encryption_key.encode())
    
    def _encrypt(self, data: str) -> str:
        """Encrypt sensitive data."""
        return self.cipher.encrypt(data.encode()).decode()
    
    def _decrypt(self, encrypted_data: str) -> str:
        """Decrypt sensitive data."""
        return self.cipher.decrypt(encrypted_data.encode()).decode()
    
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
            encrypted_key = self._encrypt(api_key)
            
            self.db.collection("users").document(self.user_id).collection("settings").document("api_config").set({
                "gemini_api_key_encrypted": encrypted_key,
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
            encrypted_key = data.get("gemini_api_key_encrypted")
            
            if not encrypted_key:
                return None
            
            return self._decrypt(encrypted_key)
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
            # Configure with test key
            genai.configure(api_key=api_key)
            
            # Try to list models as a validation check
            models = genai.list_models()
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
            encrypted_access = self._encrypt(access_token)
            encrypted_refresh = self._encrypt(refresh_token)
            
            self.db.collection("users").document(self.user_id).collection("oauth_tokens").document(provider).set({
                "provider": provider,
                "access_token_encrypted": encrypted_access,
                "refresh_token_encrypted": encrypted_refresh,
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
            
            data = doc.to_dict()
            
            return {
                "provider": data.get("provider"),
                "access_token": self._decrypt(data.get("access_token_encrypted")),
                "refresh_token": self._decrypt(data.get("refresh_token_encrypted")),
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
