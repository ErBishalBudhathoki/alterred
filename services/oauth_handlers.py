"""
Google OAuth 2.0 handler for calendar integration.
Manages the OAuth flow, token exchange, and refresh.
"""

import os
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from google_auth_oauthlib.flow import Flow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials


class GoogleOAuthHandler:
    """Handle Google OAuth 2.0 flow for calendar access."""
    
    SCOPES = ['https://www.googleapis.com/auth/calendar']
    
    def __init__(self):
        self.client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID")
        self.client_secret = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET")
        self.redirect_uri = os.getenv("OAUTH_REDIRECT_URI")
        
        if not all([self.client_id, self.client_secret, self.redirect_uri]):
            raise ValueError("Missing OAuth environment variables: GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET, or OAUTH_REDIRECT_URI")
    
    def get_authorization_url(self, state: str, redirect_uri: Optional[str] = None) -> str:
        """
        Generate authorization URL for user to grant calendar access.
        
        Args:
            state: Random state string for CSRF protection (should be user_id or session token)
            redirect_uri: Optional custom redirect URI (e.g., for mobile deep link)
        
        Returns:
            Authorization URL to redirect user to
        """
        # Use custom redirect URI if provided, otherwise use default from env
        actual_redirect_uri = redirect_uri or self.redirect_uri
        
        client_config = {
            "web": {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "redirect_uris": [actual_redirect_uri],
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token"
            }
        }
        
        flow = Flow.from_client_config(
            client_config,
            scopes=self.SCOPES,
            redirect_uri=actual_redirect_uri
        )
        
        authorization_url, _ = flow.authorization_url(
            access_type='offline',  # Get refresh token
            include_granted_scopes='true',
            state=state,
            prompt='consent'  # Force consent to always get refresh token
        )
        
        return authorization_url
    
    def exchange_code_for_tokens(self, authorization_code: str) -> Dict[str, Any]:
        """
        Exchange authorization code for access and refresh tokens.
        
        Args:
            authorization_code: Code from OAuth callback
        
        Returns:
            Dict with tokens and expiry info
        """
        try:
            client_config = {
                "web": {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "redirect_uris": [self.redirect_uri],
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token"
                }
            }
            
            flow = Flow.from_client_config(
                client_config,
                scopes=self.SCOPES,
                redirect_uri=self.redirect_uri
            )
            
            flow.fetch_token(code=authorization_code)
            
            credentials = flow.credentials
            
            # Calculate expiry timestamp
            expires_at = datetime.utcnow() + timedelta(seconds=credentials.expiry.timestamp())
            
            return {
                "ok": True,
                "access_token": credentials.token,
                "refresh_token": credentials.refresh_token,
                "expires_at": expires_at.isoformat(),
                "scopes": credentials.scopes
            }
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh an expired access token using refresh token.
        
        Args:
            refresh_token: The refresh token
        
        Returns:
            Dict with new access token and expiry
        """
        try:
            credentials = Credentials(
                token=None,
                refresh_token=refresh_token,
                token_uri="https://oauth2.googleapis.com/token",
                client_id=self.client_id,
                client_secret=self.client_secret,
                scopes=self.SCOPES
            )
            
            # Refresh the token
            request = Request()
            credentials.refresh(request)
            
            # Calculate new expiry
            expires_at = datetime.utcnow() + timedelta(seconds=3600)  # Usually 1 hour
            
            return {
                "ok": True,
                "access_token": credentials.token,
                "expires_at": expires_at.isoformat()
            }
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def revoke_token(self, token: str) -> Dict[str, Any]:
        """
        Revoke an access or refresh token.
        
        Args:
            token: Access or refresh token to revoke
        
        Returns:
            Success/failure dict
        """
        try:
            import requests
            
            response = requests.post(
                'https://oauth2.googleapis.com/revoke',
                params={'token': token},
                headers={'content-type': 'application/x-www-form-urlencoded'}
            )
            
            if response.status_code == 200:
                return {"ok": True}
            else:
                return {"ok": False, "error": f"Revocation failed: {response.text}"}
        except Exception as e:
            return {"ok": False, "error": str(e)}
