import contextvars
from typing import Optional, List, Dict, Any

# Context variable to store the current user ID for tool access
current_user_id: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar("current_user_id", default=None)

# Context variable to store the current user timezone for tool access
current_user_timezone: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar("current_user_timezone", default=None)

# Context variable to store the current user country for tool access
current_user_country: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar("current_user_country", default=None)

# Context variable to store tool outputs for the current request
current_tool_outputs: contextvars.ContextVar[Optional[List[Dict[str, Any]]]] = contextvars.ContextVar("current_tool_outputs", default=None)
