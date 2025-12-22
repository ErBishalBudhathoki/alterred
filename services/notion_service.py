"""
Notion Service for Agent Tools
==============================

Provides Notion API operations for the AI agent to create, search, and update pages.
Uses the user's Notion token stored in Firestore via UserSettings.
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
import httpx

logger = logging.getLogger(__name__)

NOTION_API_BASE = "https://api.notion.com/v1"
NOTION_API_VERSION = "2022-06-28"


def _get_notion_token(user_id: str) -> Optional[str]:
    """Get user's Notion token from Firestore."""
    try:
        from services.user_settings import UserSettings
        settings = UserSettings(user_id)
        return settings.get_notion_token()
    except Exception as e:
        logger.error(f"Failed to get Notion token for user {user_id}: {e}")
        return None


async def _notion_request(
    method: str,
    endpoint: str,
    token: str,
    body: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Make a request to the Notion API."""
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
            else:
                return {"ok": False, "error": f"Unsupported method: {method}"}
            
            result = response.json()
            
            if response.status_code >= 400:
                logger.warning(f"Notion API error: {method} {endpoint} -> {response.status_code}: {result}")
                return {
                    "ok": False,
                    "error": result.get("code", "notion_error"),
                    "message": result.get("message", "Unknown error"),
                }
            
            return {"ok": True, "data": result}
            
        except httpx.TimeoutException:
            logger.error(f"Notion API timeout: {method} {endpoint}")
            return {"ok": False, "error": "notion_timeout"}
        except httpx.RequestError as e:
            logger.error(f"Notion API request error: {method} {endpoint} -> {e}")
            return {"ok": False, "error": "notion_connection_error"}


async def search_notion_pages(user_id: str, query: str, page_size: int = 10) -> Dict[str, Any]:
    """
    Search for pages in user's Notion workspace.
    
    Args:
        user_id: The user's ID
        query: Search query text
        page_size: Number of results to return
        
    Returns:
        Dict with search results or error
    """
    token = _get_notion_token(user_id)
    if not token:
        return {
            "ok": False,
            "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
        }
    
    body = {
        "query": query,
        "page_size": min(page_size, 100),
        "filter": {"property": "object", "value": "page"}
    }
    
    result = await _notion_request("POST", "/search", token, body)
    
    if result.get("ok"):
        pages = []
        for item in result.get("data", {}).get("results", []):
            title = ""
            props = item.get("properties", {})
            # Try to get title from various property types
            for prop_name, prop_value in props.items():
                if prop_value.get("type") == "title":
                    title_arr = prop_value.get("title", [])
                    if title_arr:
                        title = title_arr[0].get("plain_text", "")
                    break
            
            pages.append({
                "id": item.get("id"),
                "title": title or "Untitled",
                "url": item.get("url"),
                "created_time": item.get("created_time"),
                "last_edited_time": item.get("last_edited_time"),
            })
        
        return {"ok": True, "pages": pages, "count": len(pages)}
    
    return result


async def create_notion_page(
    user_id: str,
    title: str,
    content: str,
    parent_page_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Create a new page in Notion.
    
    Args:
        user_id: The user's ID
        title: Page title
        content: Page content (plain text, will be converted to blocks)
        parent_page_id: Optional parent page ID. If not provided, searches for a default page.
        
    Returns:
        Dict with created page info or error
    """
    token = _get_notion_token(user_id)
    if not token:
        return {
            "ok": False,
            "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
        }
    
    # If no parent specified, try to find a suitable parent page
    if not parent_page_id:
        # Search for a page to use as parent (user needs to have shared at least one page)
        search_result = await _notion_request("POST", "/search", token, {
            "query": "",
            "page_size": 1,
            "filter": {"property": "object", "value": "page"}
        })
        
        if search_result.get("ok"):
            results = search_result.get("data", {}).get("results", [])
            if results:
                parent_page_id = results[0].get("id")
            else:
                return {
                    "ok": False,
                    "error": "No Notion pages found. Please share at least one page with your Notion integration."
                }
        else:
            return search_result
    
    # Convert content to Notion blocks
    blocks = _text_to_blocks(content)
    
    # Create the page
    body = {
        "parent": {"page_id": parent_page_id},
        "properties": {
            "title": {
                "title": [{"text": {"content": title}}]
            }
        },
        "children": blocks
    }
    
    result = await _notion_request("POST", "/pages", token, body)
    
    if result.get("ok"):
        page_data = result.get("data", {})
        return {
            "ok": True,
            "page": {
                "id": page_data.get("id"),
                "url": page_data.get("url"),
                "title": title,
            },
            "message": f"Created page '{title}' in Notion"
        }
    
    return result


async def append_to_notion_page(
    user_id: str,
    page_id: str,
    content: str,
) -> Dict[str, Any]:
    """
    Append content to an existing Notion page.
    
    Args:
        user_id: The user's ID
        page_id: The page ID to append to
        content: Content to append (plain text)
        
    Returns:
        Dict with result or error
    """
    token = _get_notion_token(user_id)
    if not token:
        return {
            "ok": False,
            "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
        }
    
    blocks = _text_to_blocks(content)
    
    body = {"children": blocks}
    
    result = await _notion_request("PATCH", f"/blocks/{page_id}/children", token, body)
    
    if result.get("ok"):
        return {
            "ok": True,
            "message": "Content appended to Notion page"
        }
    
    return result


async def get_notion_databases(user_id: str) -> Dict[str, Any]:
    """
    Get list of databases in user's Notion workspace.
    
    Args:
        user_id: The user's ID
        
    Returns:
        Dict with databases list or error
    """
    token = _get_notion_token(user_id)
    if not token:
        return {
            "ok": False,
            "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
        }
    
    body = {
        "query": "",
        "page_size": 50,
        "filter": {"property": "object", "value": "database"}
    }
    
    result = await _notion_request("POST", "/search", token, body)
    
    if result.get("ok"):
        databases = []
        for item in result.get("data", {}).get("results", []):
            title_arr = item.get("title", [])
            title = title_arr[0].get("plain_text", "Untitled") if title_arr else "Untitled"
            
            databases.append({
                "id": item.get("id"),
                "title": title,
                "url": item.get("url"),
            })
        
        return {"ok": True, "databases": databases, "count": len(databases)}
    
    return result


async def add_to_notion_database(
    user_id: str,
    database_id: str,
    title: str,
    properties: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Add a new item to a Notion database.
    
    Args:
        user_id: The user's ID
        database_id: The database ID
        title: Title for the new item
        properties: Additional properties (optional)
        
    Returns:
        Dict with created item info or error
    """
    token = _get_notion_token(user_id)
    if not token:
        return {
            "ok": False,
            "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
        }
    
    # Build properties - title is usually "Name" or "Title"
    props = {
        "Name": {"title": [{"text": {"content": title}}]},
        "Title": {"title": [{"text": {"content": title}}]},
    }
    
    if properties:
        props.update(properties)
    
    body = {
        "parent": {"database_id": database_id},
        "properties": props
    }
    
    result = await _notion_request("POST", "/pages", token, body)
    
    if result.get("ok"):
        page_data = result.get("data", {})
        return {
            "ok": True,
            "item": {
                "id": page_data.get("id"),
                "url": page_data.get("url"),
                "title": title,
            },
            "message": f"Added '{title}' to Notion database"
        }
    
    return result


def _text_to_blocks(text: str) -> List[Dict[str, Any]]:
    """Convert plain text to Notion blocks."""
    blocks = []
    
    # Split by double newlines for paragraphs
    paragraphs = text.split("\n\n")
    
    for para in paragraphs:
        if not para.strip():
            continue
            
        # Check for bullet points
        lines = para.split("\n")
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Bullet point
            if line.startswith("- ") or line.startswith("• "):
                blocks.append({
                    "object": "block",
                    "type": "bulleted_list_item",
                    "bulleted_list_item": {
                        "rich_text": [{"type": "text", "text": {"content": line[2:]}}]
                    }
                })
            # Numbered list
            elif len(line) > 2 and line[0].isdigit() and line[1] in ".)" and line[2] == " ":
                blocks.append({
                    "object": "block",
                    "type": "numbered_list_item",
                    "numbered_list_item": {
                        "rich_text": [{"type": "text", "text": {"content": line[3:]}}]
                    }
                })
            # Heading (starts with #)
            elif line.startswith("# "):
                blocks.append({
                    "object": "block",
                    "type": "heading_1",
                    "heading_1": {
                        "rich_text": [{"type": "text", "text": {"content": line[2:]}}]
                    }
                })
            elif line.startswith("## "):
                blocks.append({
                    "object": "block",
                    "type": "heading_2",
                    "heading_2": {
                        "rich_text": [{"type": "text", "text": {"content": line[3:]}}]
                    }
                })
            elif line.startswith("### "):
                blocks.append({
                    "object": "block",
                    "type": "heading_3",
                    "heading_3": {
                        "rich_text": [{"type": "text", "text": {"content": line[4:]}}]
                    }
                })
            # Regular paragraph
            else:
                blocks.append({
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": [{"type": "text", "text": {"content": line}}]
                    }
                })
    
    # If no blocks created, add empty paragraph
    if not blocks:
        blocks.append({
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [{"type": "text", "text": {"content": text or " "}}]
            }
        })
    
    return blocks
