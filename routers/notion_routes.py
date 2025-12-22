"""
Notion API Proxy Routes
=======================

This module provides backend proxy endpoints for Notion API calls.
This is necessary because:
1. Flutter Web cannot make direct calls to api.notion.com due to CORS restrictions
2. Keeps the Notion integration token secure on the backend
3. Allows for rate limiting and request validation

Usage:
------
The Flutter app stores the user's Notion token securely and sends it via
the Authorization header. The backend proxies requests to Notion's API.

When Public OAuth is set up:
- Users authenticate via OAuth flow
- Backend exchanges code for access token
- Token is stored per-user in Firestore

For Internal Integration (current):
- Users paste their integration token in the app
- Token is sent with each request
- Backend proxies to Notion API

Endpoints:
----------
- POST /notion/search - Search pages and databases
- POST /notion/pages - Create a new page
- GET /notion/pages/{page_id} - Get a page
- PATCH /notion/pages/{page_id} - Update a page
- POST /notion/databases/{database_id}/query - Query a database
- GET /notion/users/me - Get current bot user info
"""

import os
import logging
from typing import Any, Dict, Optional
from fastapi import APIRouter, Request, HTTPException, status, Body
import httpx

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notion", tags=["notion"])

# Notion API configuration
NOTION_API_BASE = "https://api.notion.com/v1"
NOTION_API_VERSION = "2022-06-28"

# Rate limiting
_RATE_BUCKETS: dict[str, list[float]] = {}


def _get_notion_token(request: Request) -> str:
    """
    Extract Notion token from request.
    
    Priority:
    1. Authorization header (Bearer token)
    2. X-Notion-Token header
    
    Returns:
        str: The Notion API token
        
    Raises:
        HTTPException: If no token is provided
    """
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    
    token_header = request.headers.get("X-Notion-Token")
    if token_header:
        return token_header
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"ok": False, "error": "notion_token_required"}
    )


def _rate_limit_check(request: Request, limit: int = 30, window: int = 60) -> None:
    """
    Simple rate limiting per IP.
    
    Args:
        request: The incoming request
        limit: Max requests per window
        window: Time window in seconds
    """
    import time
    
    ip = request.client.host if request.client else "0.0.0.0"
    now = time.time()
    
    bucket = _RATE_BUCKETS.get(ip, [])
    bucket = [t for t in bucket if now - t <= window]
    
    if len(bucket) >= limit:
        _RATE_BUCKETS[ip] = bucket
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"ok": False, "error": "rate_limited"}
        )
    
    bucket.append(now)
    _RATE_BUCKETS[ip] = bucket


async def _proxy_notion_request(
    method: str,
    endpoint: str,
    token: str,
    body: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Proxy a request to the Notion API.
    
    Args:
        method: HTTP method (GET, POST, PATCH, DELETE)
        endpoint: Notion API endpoint (e.g., /search, /pages)
        token: Notion API token
        body: Optional request body
        
    Returns:
        Dict containing the Notion API response
    """
    url = f"{NOTION_API_BASE}{endpoint}"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Notion-Version": NOTION_API_VERSION,
        "Content-Type": "application/json",
    }
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            if method.upper() == "GET":
                response = await client.get(url, headers=headers)
            elif method.upper() == "POST":
                response = await client.post(url, headers=headers, json=body)
            elif method.upper() == "PATCH":
                response = await client.patch(url, headers=headers, json=body)
            elif method.upper() == "DELETE":
                response = await client.delete(url, headers=headers)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            result = response.json()
            
            if response.status_code >= 400:
                logger.warning(
                    "Notion API error: %s %s -> %s: %s",
                    method, endpoint, response.status_code, result
                )
                raise HTTPException(
                    status_code=response.status_code,
                    detail={
                        "ok": False,
                        "error": result.get("code", "notion_error"),
                        "message": result.get("message", "Unknown error"),
                    }
                )
            
            return {"ok": True, "data": result}
            
        except httpx.TimeoutException:
            logger.error("Notion API timeout: %s %s", method, endpoint)
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail={"ok": False, "error": "notion_timeout"}
            )
        except httpx.RequestError as e:
            logger.error("Notion API request error: %s %s -> %s", method, endpoint, str(e))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={"ok": False, "error": "notion_connection_error"}
            )


# ============================================================================
# Search Endpoint
# ============================================================================

@router.post("/search")
async def search_notion(
    request: Request,
    payload: Dict[str, Any] = Body(default={}),
):
    """
    Search Notion pages and databases.
    
    Body:
        query (str): Search query text
        filter (dict): Optional filter for object type
        sort (dict): Optional sort configuration
        page_size (int): Number of results (max 100)
        start_cursor (str): Pagination cursor
        
    Returns:
        Search results from Notion
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    body = {
        "query": payload.get("query", ""),
        "page_size": min(payload.get("page_size", 20), 100),
    }
    
    if "filter" in payload:
        body["filter"] = payload["filter"]
    if "sort" in payload:
        body["sort"] = payload["sort"]
    if "start_cursor" in payload:
        body["start_cursor"] = payload["start_cursor"]
    
    return await _proxy_notion_request("POST", "/search", token, body)


# ============================================================================
# Pages Endpoints
# ============================================================================

@router.post("/pages")
async def create_page(
    request: Request,
    payload: Dict[str, Any] = Body(...),
):
    """
    Create a new Notion page.
    
    Body:
        parent (dict): Parent page or database
        properties (dict): Page properties
        children (list): Optional content blocks
        
    Returns:
        Created page object
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    if "parent" not in payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"ok": False, "error": "parent_required"}
        )
    
    return await _proxy_notion_request("POST", "/pages", token, payload)


@router.get("/pages/{page_id}")
async def get_page(
    request: Request,
    page_id: str,
):
    """
    Get a Notion page by ID.
    
    Args:
        page_id: The page ID
        
    Returns:
        Page object
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    return await _proxy_notion_request("GET", f"/pages/{page_id}", token)


@router.patch("/pages/{page_id}")
async def update_page(
    request: Request,
    page_id: str,
    payload: Dict[str, Any] = Body(...),
):
    """
    Update a Notion page.
    
    Args:
        page_id: The page ID
        
    Body:
        properties (dict): Updated properties
        archived (bool): Archive status
        
    Returns:
        Updated page object
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    return await _proxy_notion_request("PATCH", f"/pages/{page_id}", token, payload)


# ============================================================================
# Blocks Endpoints
# ============================================================================

@router.get("/blocks/{block_id}/children")
async def get_block_children(
    request: Request,
    block_id: str,
    page_size: int = 100,
    start_cursor: Optional[str] = None,
):
    """
    Get children blocks of a block/page.
    
    Args:
        block_id: The block or page ID
        page_size: Number of results
        start_cursor: Pagination cursor
        
    Returns:
        List of child blocks
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    endpoint = f"/blocks/{block_id}/children?page_size={min(page_size, 100)}"
    if start_cursor:
        endpoint += f"&start_cursor={start_cursor}"
    
    return await _proxy_notion_request("GET", endpoint, token)


@router.patch("/blocks/{block_id}/children")
async def append_block_children(
    request: Request,
    block_id: str,
    payload: Dict[str, Any] = Body(...),
):
    """
    Append children blocks to a block/page.
    
    Args:
        block_id: The block or page ID
        
    Body:
        children (list): Blocks to append
        
    Returns:
        Appended blocks
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    if "children" not in payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"ok": False, "error": "children_required"}
        )
    
    return await _proxy_notion_request("PATCH", f"/blocks/{block_id}/children", token, payload)


# ============================================================================
# Database Endpoints
# ============================================================================

@router.post("/databases")
async def create_database(
    request: Request,
    payload: Dict[str, Any] = Body(...),
):
    """
    Create a new Notion database.
    
    Body:
        parent (dict): Parent page
        title (list): Database title
        properties (dict): Database schema
        
    Returns:
        Created database object
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    return await _proxy_notion_request("POST", "/databases", token, payload)


@router.get("/databases/{database_id}")
async def get_database(
    request: Request,
    database_id: str,
):
    """
    Get a Notion database by ID.
    
    Args:
        database_id: The database ID
        
    Returns:
        Database object
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    return await _proxy_notion_request("GET", f"/databases/{database_id}", token)


@router.post("/databases/{database_id}/query")
async def query_database(
    request: Request,
    database_id: str,
    payload: Dict[str, Any] = Body(default={}),
):
    """
    Query a Notion database.
    
    Args:
        database_id: The database ID
        
    Body:
        filter (dict): Query filter
        sorts (list): Sort configuration
        page_size (int): Number of results
        start_cursor (str): Pagination cursor
        
    Returns:
        Query results
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    body = {
        "page_size": min(payload.get("page_size", 100), 100),
    }
    
    if "filter" in payload:
        body["filter"] = payload["filter"]
    if "sorts" in payload:
        body["sorts"] = payload["sorts"]
    if "start_cursor" in payload:
        body["start_cursor"] = payload["start_cursor"]
    
    return await _proxy_notion_request("POST", f"/databases/{database_id}/query", token, body)


# ============================================================================
# Users Endpoint
# ============================================================================

@router.get("/users/me")
async def get_bot_user(request: Request):
    """
    Get the bot user info (validates token).
    
    Returns:
        Bot user object with workspace info
    """
    _rate_limit_check(request)
    token = _get_notion_token(request)
    
    return await _proxy_notion_request("GET", "/users/me", token)


# ============================================================================
# Health Check
# ============================================================================

@router.get("/health")
async def notion_health():
    """
    Health check for Notion proxy.
    """
    return {
        "ok": True,
        "service": "notion_proxy",
        "api_base": NOTION_API_BASE,
        "api_version": NOTION_API_VERSION,
    }


# ============================================================================
# Token Sync Endpoint (for Agent Tools)
# ============================================================================

@router.post("/connect")
async def connect_notion(
    request: Request,
    payload: Dict[str, Any] = Body(...),
):
    """
    Save Notion token to Firestore for agent tool access.
    
    This endpoint is called by the Flutter app after the user connects
    their Notion integration. It stores the token in Firestore so that
    the AI agent can access Notion on behalf of the user.
    
    Body:
        token (str): The Notion integration token (ntn_xxx)
        
    Headers:
        Authorization: Bearer <firebase_id_token>
        
    Returns:
        Success confirmation or error
    """
    from services.auth import get_user_id_from_request
    from services.user_settings import UserSettings
    
    # Get user ID from Firebase auth
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"ok": False, "error": "authentication_required"}
        )
    
    token = payload.get("token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"ok": False, "error": "token_required"}
        )
    
    # Validate token format (should start with ntn_ for internal integrations
    # or secret_ for OAuth tokens)
    if not (token.startswith("ntn_") or token.startswith("secret_")):
        logger.warning(f"Invalid Notion token format for user {user_id}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"ok": False, "error": "invalid_token_format", "message": "Token should start with 'ntn_' or 'secret_'"}
        )
    
    # Optionally validate the token by making a test API call
    try:
        result = await _proxy_notion_request("GET", "/users/me", token)
        if not result.get("ok"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"ok": False, "error": "invalid_token", "message": "Token validation failed"}
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token validation error for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"ok": False, "error": "token_validation_failed", "message": str(e)}
        )
    
    # Save token to Firestore
    try:
        settings = UserSettings(user_id)
        save_result = settings.save_notion_token(token)
        
        if not save_result.get("ok"):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"ok": False, "error": "save_failed", "message": save_result.get("error")}
            )
        
        logger.info(f"Notion token saved for user {user_id}")
        return {"ok": True, "message": "Notion connected successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to save Notion token for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"ok": False, "error": "save_failed", "message": str(e)}
        )


@router.post("/disconnect")
async def disconnect_notion(request: Request):
    """
    Remove Notion token from Firestore.
    
    Called when user disconnects their Notion integration.
    
    Headers:
        Authorization: Bearer <firebase_id_token>
        
    Returns:
        Success confirmation or error
    """
    from services.auth import get_user_id_from_request
    from services.user_settings import UserSettings
    
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"ok": False, "error": "authentication_required"}
        )
    
    try:
        settings = UserSettings(user_id)
        result = settings.delete_notion_token()
        
        if not result.get("ok"):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"ok": False, "error": "delete_failed", "message": result.get("error")}
            )
        
        logger.info(f"Notion token deleted for user {user_id}")
        return {"ok": True, "message": "Notion disconnected successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete Notion token for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"ok": False, "error": "delete_failed", "message": str(e)}
        )


@router.get("/status")
async def notion_status(request: Request):
    """
    Check if user has Notion connected (token stored in Firestore).
    
    Headers:
        Authorization: Bearer <firebase_id_token>
        
    Returns:
        Connection status
    """
    from services.auth import get_user_id_from_request
    from services.user_settings import UserSettings
    
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"ok": False, "error": "authentication_required"}
        )
    
    try:
        settings = UserSettings(user_id)
        is_connected = settings.is_notion_connected()
        
        return {
            "ok": True,
            "connected": is_connected,
        }
        
    except Exception as e:
        logger.error(f"Failed to check Notion status for user {user_id}: {e}")
        return {
            "ok": False,
            "connected": False,
            "error": str(e)
        }
