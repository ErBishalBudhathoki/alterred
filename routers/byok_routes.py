from fastapi import APIRouter, Depends, HTTPException, Body, Request
from typing import Dict, Any
from services.user_settings import UserSettings
from services.model_wrapper import ADKModelWrapper, ModelInput
from services.auth import get_user_id_from_request

router = APIRouter(prefix="/byok", tags=["byok"])

async def verify_byok_key(request: Request):
    """
    Dependency to verify user has a custom API key.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    try:
        settings = UserSettings(user_id)
        if not settings.has_custom_api_key():
            raise HTTPException(
                status_code=403, 
                detail="No custom API key found. Please configure BYOK or use Vertex endpoint."
            )
    except HTTPException:
        raise
    except Exception as e:
        if "ENCRYPTION_KEY" in str(e):
            # If encryption key missing, system error
            raise HTTPException(status_code=500, detail="System misconfiguration (Encryption)")
        raise HTTPException(status_code=500, detail="Error verifying BYOK settings")
    
    return user_id

@router.post("/generate")
async def byok_generate(
    payload: Dict[str, Any] = Body(...),
    user_id: str = Depends(verify_byok_key)
):
    """
    Generate content using Bring-Your-Own-Key (Standard API).
    
    - Verifies custom key existence
    - Routes to Standard API (via wrapper)
    - No credit deduction
    """
    prompt = payload.get("prompt")
    if not prompt:
        raise HTTPException(status_code=400, detail="Prompt is required")
        
    model_name = payload.get("model", "gemini-2.0-flash-exp")
    params = payload.get("parameters", {})
    
    wrapper = ADKModelWrapper(user_id=user_id)
    
    # wrapper uses VertexAIClient which prefers BYOK if has_custom_api_key is true.
    # Since we verified it is true, it should use BYOK.
    
    result = await wrapper.generate(ModelInput(
        prompt=prompt,
        model_name=model_name,
        parameters=params,
        user_id=user_id
    ))
    
    if result.error:
        raise HTTPException(status_code=500, detail=result.error)
        
    return {
        "ok": True,
        "text": result.text,
        "model": result.model_name,
        "latency_ms": result.latency_ms,
        "mode": result.mode,
        "credits_used": False
    }
