import os
from typing import Optional, Dict, Any
from functools import cached_property
from google.adk.models.google_llm import Gemini as BaseGemini
from google.genai import types, Client

class Gemini(BaseGemini):
    vertexai: bool = False
    project: Optional[str] = None
    location: Optional[str] = None
    api_key: Optional[str] = None

    @cached_property
    def api_client(self) -> Client:
        kwargs: Dict[str, Any] = {}
        if self.api_key:
            kwargs["api_key"] = self.api_key
        if self.vertexai:
            kwargs["vertexai"] = True
            if self.project:
                kwargs["project"] = self.project
            if self.location:
                kwargs["location"] = self.location
        
        # Log initialization for debugging
        if kwargs.get("vertexai"):
            print(f"[Gemini] Initializing Client with Vertex AI (project={kwargs.get('project')}, location={kwargs.get('location')})")
        elif kwargs.get("api_key"):
            print(f"[Gemini] Initializing Client with API Key")
        
        # Build HttpOptions with only valid parameters
        http_opts_kwargs: Dict[str, Any] = {}
        if self._tracking_headers:
            http_opts_kwargs["headers"] = self._tracking_headers
        
        return Client(
            http_options=types.HttpOptions(**http_opts_kwargs) if http_opts_kwargs else None,
            **kwargs
        )

def get_adk_model(model_name: Optional[str] = None) -> Gemini:
    """Factory to get a configured ADK Gemini model."""
    name = model_name or os.getenv("DEFAULT_MODEL", "gemini-2.0-flash-exp")
    
    # Initialize Vertex AI environment if configured
    project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("VERTEX_AI_LOCATION", "us-central1")
    force_vertex = (os.getenv("FORCE_VERTEX_AI", "").lower() == "true")

    gemini_kwargs = {}
    if project_id or force_vertex:
        gemini_kwargs = {
            "vertexai": True,
            "project": project_id,
            "location": location
        }
    
    return Gemini(model=name, **gemini_kwargs)
