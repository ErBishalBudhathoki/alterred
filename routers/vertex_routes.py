from fastapi import APIRouter, Depends, HTTPException, Body, Request
from typing import Dict, Any
from services.credit_service import get_credit_service
from services.model_wrapper import ADKModelWrapper, ModelInput
from services.auth import get_user_id_from_request

router = APIRouter(prefix="/vertex", tags=["vertex"])

async def verify_credit_status(request: Request):
    """
    Dependency to verify user has credits.
    Returns user_id if authorized and has credits.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    credit_service = get_credit_service()
    balance = credit_service.get_balance(user_id)
    
    if not balance.get("ok"):
        raise HTTPException(status_code=500, detail="Error checking credit balance")
        
    # Strict check: Must have credits > 0
    if balance.get("balance", 0) <= 0:
        raise HTTPException(
            status_code=402, 
            detail="Insufficient credits. Please upgrade or use BYOK endpoint."
        )
    
    return user_id

@router.post("/generate")
async def vertex_generate(
    payload: Dict[str, Any] = Body(...),
    user_id: str = Depends(verify_credit_status)
):
    """
    Generate content using Vertex AI (Credited).
    
    - Verifies credit balance
    - Routes to Vertex AI
    - Deducts credits (handled by internal client)
    - Logs transaction
    """
    prompt = payload.get("prompt")
    if not prompt:
        raise HTTPException(status_code=400, detail="Prompt is required")
        
    model_name = payload.get("model", "gemini-2.0-flash-exp")
    params = payload.get("parameters", {})
    
    wrapper = ADKModelWrapper(user_id=user_id)
    
    # Determine mode to ensure we are actually using Vertex/Credits
    # Note: VertexAIClient will prefer BYOK if available. 
    # If we want to strictly enforce Credit usage even if BYOK exists (unlikely user desire),
    # we would need to modify client.
    # Assuming "Intelligent routing" means "Use the best available", but since this is the
    # "/vertex" endpoint, implies we WANT to use Vertex.
    # For now, we rely on the wrapper.
    
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
        "credits_used": True if result.mode == "vertex_ai" else False
    }
