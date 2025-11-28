"""
Credit API endpoints to add to api_server.py
"""

# Add these endpoints after the OAuth endpoints (around line 600)

# ===== Credit Management Endpoints =====

@app.get("/credits/balance")
def api_get_credit_balance(request: Request):
    """Get user's current credit balance."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    
    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.get_balance(uid)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/credits/history")
def api_get_credit_history(request: Request, limit: int = 50):
    """Get user's credit transaction history."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    
    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.get_transaction_history(uid, limit=limit)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


# Admin endpoints (require admin auth - TODO: add admin check)
@app.post("/admin/credits/allocate")
def api_admin_allocate_credits(request: Request, user_id: str, amount: float, reason: str = "admin_grant"):
    """Admin endpoint to allocate credits to a user."""
    # TODO: Add admin authentication check
    admin_uid = get_user_id_from_request(request) if request else _uid(None)
    
    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        result = credit_service.add_credits(
            user_id=user_id,
            amount=amount,
            reason=reason,
            metadata={"admin_id": admin_uid}
        )
        return result
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/admin/credits/initialize")
def api_admin_initialize_credits(request: Request, user_id: str):
    """Admin endpoint to manually initialize credits for a user."""
    # TODO: Add admin authentication check
    
    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.initialize_user_credits(user_id)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})
