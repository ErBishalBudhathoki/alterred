import os
import sys
from services.vertex_ai_client import VertexAIClient, ClientMode

def verify():
    print("Verifying Vertex AI Client Configuration...")
    
    # Check env vars
    project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("VERTEX_AI_LOCATION")
    
    print(f"Project ID: {project_id}")
    print(f"Location: {location}")
    
    try:
        client = VertexAIClient()
        print(f"Vertex AI Available: {client.vertex_ai_available}")
        
        if client.vertex_ai_available:
            print("SUCCESS: Vertex AI client initialized successfully.")
        else:
            print("WARNING: Vertex AI client not available (likely missing credentials or package).")
            
    except Exception as e:
        print(f"ERROR: Failed to initialize Vertex AI client: {e}")

if __name__ == "__main__":
    verify()
