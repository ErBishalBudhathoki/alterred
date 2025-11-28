
import os
import sys
import asyncio
import logging
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.vertex_ai_client import VertexAIClient, ClientMode

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("vertex_verification")

def init_firebase():
    try:
        firebase_admin.get_app()
    except ValueError:
        # Not initialized
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)

async def verify_vertex_configuration():
    load_dotenv()
    init_firebase()
    
    logger.info("--- Vertex AI Default Configuration Verification ---")
    
    # 1. Check Environment Variables
    project_id = os.getenv("VERTEX_AI_PROJECT_ID")
    location = os.getenv("VERTEX_AI_LOCATION")
    logger.info(f"Env VERTEX_AI_PROJECT_ID: {project_id}")
    logger.info(f"Env VERTEX_AI_LOCATION: {location}")
    
    if not project_id:
        logger.warning("VERTEX_AI_PROJECT_ID is not set in environment!")
    
    # 2. Instantiate Client
    logger.info("\nInstantiating VertexAIClient...")
    # Using a dummy user_id to avoid BYOK lookup issues if firestore permissions are strict
    # But we need a valid user for credit check if we want to test that path.
    # We'll use 'verification_user'
    client = VertexAIClient(user_id="verification_user")
    
    logger.info(f"Client Project ID: {client.project_id}")
    logger.info(f"Client Location: {client.location}")
    logger.info(f"Vertex AI Available (SDK check): {client.vertex_ai_available}")
    
    # 3. Determine Mode
    logger.info("\nDetermining Operation Mode...")
    
    # Patch _get_credit_balance to simulate available credits
    # This proves that logic prioritizes Vertex AI when credits exist
    original_get_credits = client._get_credit_balance
    client._get_credit_balance = lambda: 10.0
    logger.info("PATCH: Mocking credit balance to 10.0 to test routing logic...")
    
    mode = client.determine_mode()
    logger.info(f"Determined Mode (with mocked credits): {mode}")
    
    # Restore for authentic test (optional, but we proceed with the chosen mode)
    # client._get_credit_balance = original_get_credits
    
    if mode == ClientMode.VERTEX_AI:
        logger.info("✅ System logic correctly prioritizes Vertex AI when credits are available.")
        
        # 4. Test Invocation
        logger.info("\nAttempting Test Generation (Hello World)...")
        
        # Try multiple models and print debug info
        models_to_try = [
            "gemini-1.5-flash-001",
            "gemini-1.5-pro-001",
            "gemini-1.0-pro",
            "gemini-flash-latest"  # Fallback to what was in the file
        ]
        
        # Verify credentials explicitly
        import google.auth
        creds, project = google.auth.default()
        logger.info(f"Using Service Account: {creds.service_account_email}")
        logger.info(f"Auth Project: {project}")
        
        for model in models_to_try:
            logger.info(f"\nTrying model: {model}...")
            try:
                response_text = ""
                async for chunk in client.generate_content_async("Hello, are you running on Vertex AI?", model_name=model):
                    response_text += chunk
                
                logger.info(f"✅ Generation Successful with {model}!")
                logger.info(f"Response Preview: {response_text[:50]}...")
                break # Success!
                
            except Exception as e:
                logger.error(f"❌ Failed with {model}: {e}")
                
    elif mode == ClientMode.BYOK:
        logger.info("⚠️ System defaulted to BYOK mode (likely due to missing credits or explicit configuration).")
    else:
        logger.info(f"⚠️ System defaulted to {mode}.")

if __name__ == "__main__":
    asyncio.run(verify_vertex_configuration())
