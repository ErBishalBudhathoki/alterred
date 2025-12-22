"""
Vertex AI Client Wrapper
=========================
Unified client for Gemini API access with support for both Vertex AI (org billing) and BYOK modes.
Implements automatic fallback logic and credit consumption tracking.

Model Name Resolution:
- Order of precedence for resolving the model name:
  1) Explicit function parameter `model_name` when provided and non-empty
  2) Environment variable `DEFAULT_MODEL` (loaded from `.env` if available)
  3) GitHub Actions environment variables when `GITHUB_ACTIONS=true`:
     - `GITHUB_DEFAULT_MODEL`, then `MODEL_NAME`, then `DEFAULT_MODEL`
  4) Fallback to `"gemini-2.0-flash-exp"` for backward compatibility

Required Environment Variables:
- `DEFAULT_MODEL` (recommended): default Gemini model name for local/dev
- `GITHUB_DEFAULT_MODEL` or `MODEL_NAME` (optional): set in GitHub Actions for deploy-time configuration
- `GITHUB_ACTIONS` (auto-set by GitHub): indicates running in Actions

Example .env Configuration:
```
DEFAULT_MODEL=gemini-2.0-flash-exp
VERTEX_AI_PROJECT_ID=neuropilot-23fb5
VERTEX_AI_LOCATION=australia-southeast1
GOOGLE_APPLICATION_CREDENTIALS=./credentials/vertex-ai-service-account.json
```

Design Decisions:
- Encapsulates both `vertexai` and `google.genai` to provide unified interface
- Credit checks happen before generation to prevent quota overruns
- Falls back to BYOK automatically when credits exhausted
- Logs all usage for analytics and abuse detection

Behavioral Specifications:
- `get_client`: Returns appropriate client based on credits and BYOK status
- `generate_content`: Unified generation method with credit consumption
- `check_and_consume_credit`: Credit validation and deduction
"""

import os
from typing import Optional, Dict, Any, AsyncIterator
from enum import Enum
from google.genai import Client as GenAIClient
from firebase_admin import firestore
from dotenv import load_dotenv
from services.firebase_client import get_client
from services.metrics_service import record_model_usage


class ClientMode(Enum):
    """Enum for client operation modes."""
    VERTEX_AI = "vertex_ai"  # Organization billing via Vertex AI
    BYOK = "byok"  # Bring Your Own Key (user's API key)
    FALLBACK = "fallback"  # Deprecated: system key fallback (disabled)


class VertexAIClient:
    """
    Unified Gemini client with Vertex AI, BYOK, and credit management.
    """
    
    def __init__(
        self,
        user_id: Optional[str] = None,
        project_id: Optional[str] = None,
        location: Optional[str] = None
    ):
        """
        Initialize the Vertex AI client.
        
        Args:
            user_id: User ID for credit tracking and BYOK lookup
            project_id: GCP project ID for Vertex AI (defaults to env var)
            location: Vertex AI location (defaults to env var)
        """
        self.user_id = user_id
        self.project_id = project_id or os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
        self.location = location or os.getenv("VERTEX_AI_LOCATION", "australia-southeast1")
        self.db = get_client()
        
        # Check if Vertex AI configuration is present
        self.vertex_ai_available = bool(self.project_id and self.location)
    
    def _get_user_api_key(self) -> Optional[str]:
        """Get user's custom API key from UserSettings."""
        if not self.user_id:
            return None
        
        try:
            from services.user_settings import UserSettings
            user_settings = UserSettings(self.user_id)
            return user_settings.get_api_key()
        except Exception as e:
            print(f"Error getting user API key: {e}")
            return None
    
    def _get_credit_balance(self) -> float:
        """Get user's current credit balance."""
        if not self.user_id:
            return 0.0
        
        try:
            doc = self.db.collection("user_credits").document(self.user_id).get()
            if doc.exists:
                return doc.to_dict().get("balance", 0.0)
            return 0.0
        except Exception as e:
            print(f"Error getting credit balance: {e}")
            return 0.0
    
    def _consume_credit(self, amount: float = 1.0, metadata: Optional[Dict] = None) -> bool:
        """
        Consume credits from user's balance.
        
        Args:
            amount: Number of credits to consume
            metadata: Additional data to log with the transaction
            
        Returns:
            True if credits were successfully consumed, False otherwise
        """
        if not self.user_id:
            return False
        
        try:
            credit_ref = self.db.collection("user_credits").document(self.user_id)
            
            # Use Firestore transaction to ensure atomic decrement
            @firestore.transactional
            def update_credit(transaction, ref):
                snapshot = ref.get(transaction=transaction)
                if not snapshot.exists:
                    return False
                
                current_balance = snapshot.to_dict().get("balance", 0.0)
                if current_balance < amount:
                    return False
                
                transaction.update(ref, {
                    "balance": current_balance - amount,
                    "total_consumed": firestore.Increment(amount),
                    "last_updated": firestore.SERVER_TIMESTAMP
                })
                return True
            
            transaction = self.db.transaction()
            success = update_credit(transaction, credit_ref)
            
            if success:
                # Log the transaction
                self._log_credit_transaction(amount, "consumption", metadata)
            
            return success
        except Exception as e:
            print(f"Error consuming credit: {e}")
            return False
    
    def _log_credit_transaction(
        self,
        amount: float,
        transaction_type: str,
        metadata: Optional[Dict] = None
    ):
        """Log a credit transaction for analytics."""
        try:
            self.db.collection("credit_transactions").add({
                "user_id": self.user_id,
                "amount": amount,
                "type": transaction_type,
                "metadata": metadata or {},
                "timestamp": firestore.SERVER_TIMESTAMP
            })
        except Exception as e:
            print(f"Error logging credit transaction: {e}")
    
    def determine_mode(self) -> ClientMode:
        """
        Determine which client mode to use based on credits and BYOK.
        
        Returns:
            ClientMode enum indicating the mode to use
        """
        # Check if user has custom API key (BYOK)
        user_api_key = self._get_user_api_key()
        if user_api_key:
            return ClientMode.BYOK
        
        # Check credit balance - IF vertex_ai_available is True
        if self.vertex_ai_available:
            # Prefer Vertex AI when configured; credit enforcement happens at generate time
            return ClientMode.VERTEX_AI
        
        # Do NOT fallback to system key; only BYOK explicitly allowed
        
        # No fallback to system key

        # No valid auth method available
        raise ValueError("No valid authentication method available. User needs to either have credits or provide their own API key.")
    
    def get_client(self, model_name: str = "gemini-2.0-flash-exp") -> tuple[Any, ClientMode]:
        """
        Get the appropriate Gemini client based on available auth and credits.
        
        Args:
            model_name: Name of the Gemini model to use. When None or empty,
                resolves dynamically from environment per the documented precedence.
        
        Returns:
            Tuple of (client, mode) where client is the generative model and mode is the ClientMode used
        """
        mode = self.determine_mode()
        resolved_model = resolve_model_name(model_name)
        
        if mode == ClientMode.VERTEX_AI:
            # Use Vertex AI with org billing via new SDK
            client = GenAIClient(vertexai=True, project=self.project_id, location=self.location)
            return client, mode
        
        elif mode == ClientMode.BYOK:
            # Use user's custom API key
            user_api_key = self._get_user_api_key()
            client = GenAIClient(api_key=user_api_key)
            return client, mode
        
        else:
            # System API key fallback is disabled
            raise ValueError("Google AI Studio system key usage is disabled. Provide BYOK or configure Vertex AI.")
    
    async def generate_content_async(
        self,
        prompt: str,
        model_name: str = "gemini-2.0-flash-exp",
        **kwargs
    ) -> AsyncIterator[str]:
        """
        Generate content with automatic credit management and mode selection.
        
        Args:
            prompt: The input prompt
            model_name: Model to use
            **kwargs: Additional generation parameters
            
        Yields:
            Generated text chunks
        """
        mode = self.determine_mode()
        import time
        t0 = time.time()
        
        # Consume credit if using Vertex AI
        if mode == ClientMode.VERTEX_AI:
            if not self._consume_credit(amount=1.0, metadata={"prompt_length": len(prompt)}):
                # Fall back to BYOK if credit consumption fails
                mode = ClientMode.BYOK
        
        resolved_model = resolve_model_name(model_name)
        client, actual_mode = self.get_client(resolved_model)
        
        # Generate content
        try:
            contents = [{"role": "user", "parts": [{"text": prompt}]}]
            # Unified call for both modes using google.genai SDK
            try:
                response = await client.models.generate_content_async(model=resolved_model, contents=contents, **kwargs)
                async for chunk in response:
                    text = getattr(chunk, "text", None)
                    if text:
                        yield text
            except TypeError:
                # Handle keyword-only parameter signature differences
                response = await client.models.generate_content_async(model=resolved_model, contents=contents)
                async for chunk in response:
                    text = getattr(chunk, "text", None)
                    if text:
                        yield text
            finally:
                try:
                    ms = int((time.time() - t0) * 1000)
                    record_model_usage(model_name=resolved_model, latency_ms=ms, status="success")
                except Exception:
                    pass
        except Exception as e:
            try:
                ms = int((time.time() - t0) * 1000)
                record_model_usage(model_name=resolved_model, latency_ms=ms, status="error", error=str(e))
            except Exception:
                pass
            raise
            
    def generate_content(
        self,
        prompt: str,
        model_name: str = "gemini-2.0-flash-exp",
        **kwargs
    ) -> str:
        """
        Synchronous version of generate_content.
        
        Args:
            prompt: The input prompt
            model_name: Model to use
            **kwargs: Additional generation parameters
            
        Returns:
            Generated text
        """
        mode = self.determine_mode()
        import time
        t0 = time.time()
        
        # Consume credit if using Vertex AI
        if mode == ClientMode.VERTEX_AI:
            if not self._consume_credit(amount=1.0, metadata={"prompt_length": len(prompt)}):
                # Fall back to BYOK if credit consumption fails
                mode = ClientMode.BYOK
        
        resolved_model = resolve_model_name(model_name)
        client, actual_mode = self.get_client(resolved_model)
        
        try:
            contents = [{"role": "user", "parts": [{"text": prompt}]}]
            # Unified call for both modes using google.genai SDK
            try:
                response = client.models.generate_content(model=resolved_model, contents=contents, **kwargs)
                text = getattr(response, "text", "")
                try:
                    ms = int((time.time() - t0) * 1000)
                    record_model_usage(model_name=resolved_model, latency_ms=ms, status="success")
                except Exception:
                    pass
                return text
            except TypeError:
                # Handle keyword-only parameter signature differences
                response = client.models.generate_content(model=resolved_model, contents=contents)
                text = getattr(response, "text", "")
                try:
                    ms = int((time.time() - t0) * 1000)
                    record_model_usage(model_name=resolved_model, latency_ms=ms, status="success")
                except Exception:
                    pass
                return text
        except Exception as e:
            try:
                ms = int((time.time() - t0) * 1000)
                record_model_usage(model_name=resolved_model, latency_ms=ms, status="error", error=str(e))
            except Exception:
                pass
            raise


def get_vertex_ai_client(user_id: Optional[str] = None) -> VertexAIClient:
    """
    Factory function to create a VertexAIClient.
    
    Args:
        user_id: Optional user ID for credit tracking
        
    Returns:
        Configured VertexAIClient instance
    """
    return VertexAIClient(user_id=user_id)


def _validate_model_name(name: Optional[str]) -> bool:
    """
    Basic validation for model name.
    Returns True for non-empty strings; does not leak values to logs.
    """
    return bool(name and isinstance(name, str) and name.strip())


def resolve_model_name(preferred: Optional[str] = None) -> str:
    """
    Resolve the Gemini model name using documented precedence.
    Order:
    1) Explicit `preferred` parameter when provided and non-empty
    2) Environment variable `DEFAULT_MODEL` (from .env if available)
    3) GitHub Actions env when `GITHUB_ACTIONS=true`: `GITHUB_DEFAULT_MODEL`, then `MODEL_NAME`, then `DEFAULT_MODEL`
    4) Fallback to "gemini-2.0-flash"
    """
    # Load .env if present (safe in dev; no secrets printed)
    try:
        load_dotenv()
    except Exception:
        pass

    if preferred and isinstance(preferred, str):
        p = preferred.strip()
        if p:
            return p

    env_model = (os.getenv("DEFAULT_MODEL") or "").strip()
    if env_model:
        return env_model

    if (os.getenv("GITHUB_ACTIONS", "").lower() == "true"):
        for key in ("GITHUB_DEFAULT_MODEL", "MODEL_NAME", "DEFAULT_MODEL"):
            val = (os.getenv(key) or "").strip()
            if val:
                return val

    return "gemini-2.0-flash"
