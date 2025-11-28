"""
Direct Google Calendar API Integration
=======================================

This module provides direct Google Calendar API access using tokens from Settings OAuth,
bypassing the MCP NPM package which has OAuth compatibility issues.
"""

import os
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import logging

logger = logging.getLogger(__name__)


def _get_calendar_service(user_id: str):
    """Get authenticated Google Calendar service using user's Firestore tokens."""
    from services.user_settings import UserSettings
    from services.oauth_handlers import GoogleOAuthHandler
    
    user_settings = UserSettings(user_id)
    tokens = user_settings.get_oauth_tokens("google_calendar")
    
    if not tokens:
        raise ValueError("No calendar tokens found. Please connect calendar in Settings.")
    
    # Check if token needs refresh
    try:
        expires_at = datetime.fromisoformat(tokens["expires_at"])
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
    except Exception:
        expires_at = datetime.now(timezone.utc)
    
    # Refresh if expired or expiring soon
    if datetime.now(timezone.utc) >= (expires_at - timedelta(minutes=5)):
        logger.info(f"Refreshing calendar token for user {user_id}")
        oauth_handler = GoogleOAuthHandler()
        refresh_result = oauth_handler.refresh_access_token(tokens["refresh_token"])
        
        if not refresh_result.get("ok"):
            raise ValueError(f"Token refresh failed: {refresh_result.get('error')}")
        
        # Save refreshed tokens
        user_settings.save_oauth_tokens(
            provider="google_calendar",
            access_token=refresh_result["access_token"],
            refresh_token=tokens["refresh_token"],
            expires_at=refresh_result["expires_at"],
            scopes=tokens["scopes"]
        )
        tokens = {
            "access_token": refresh_result["access_token"],
            "refresh_token": tokens["refresh_token"],
            "expires_at": refresh_result["expires_at"],
            "scopes": tokens["scopes"]
        }
    
    # Create credentials
    creds = Credentials(
        token=tokens["access_token"],
        refresh_token=tokens["refresh_token"],
        token_uri="https://oauth2.googleapis.com/token",
        client_id=os.getenv("GOOGLE_OAUTH_CLIENT_ID"),
        client_secret=os.getenv("GOOGLE_OAUTH_CLIENT_SECRET"),
        scopes=tokens["scopes"]
    )
    
    # Build and return service
    service = build('calendar', 'v3', credentials=creds)
    return service


def list_events(user_id: str, start_time: str, end_time: str, calendar_id: str = "primary", max_results: int = 50) -> List[Dict[str, Any]]:
    """
    List calendar events within a time range.
    
    Args:
        user_id: User ID
        start_time: ISO format start time
        end_time: ISO format end time
        calendar_id: Calendar ID (default: "primary")
        max_results: Maximum number of events to return
    
    Returns:
        List of event dictionaries
    """
    try:
        service = _get_calendar_service(user_id)
        
        events_result = service.events().list(
            calendarId=calendar_id,
            timeMin=start_time,
            timeMax=end_time,
            maxResults=max_results,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        logger.info(f"Retrieved {len(events)} events for user {user_id}")
        return events
        
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Error listing events: {e}")
        raise


def create_event(user_id: str, summary: str, start_time: str, end_time: str, 
                description: Optional[str] = None, location: Optional[str] = None,
                calendar_id: str = "primary") -> Dict[str, Any]:
    """
    Create a new calendar event.
    
    Args:
        user_id: User ID
        summary: Event title
        start_time: ISO format start time
        end_time: ISO format end time
        description: Event description (optional)
        location: Event location (optional)
        calendar_id: Calendar ID (default: "primary")
    
    Returns:
        Created event dictionary
    """
    try:
        service = _get_calendar_service(user_id)
        
        event = {
            'summary': summary,
            'start': {'dateTime': start_time, 'timeZone': 'UTC'},
            'end': {'dateTime': end_time, 'timeZone': 'UTC'},
        }
        
        if description:
            event['description'] = description
        if location:
            event['location'] = location
        
        created_event = service.events().insert(calendarId=calendar_id, body=event).execute()
        logger.info(f"Created event for user {user_id}: {created_event.get('id')}")
        return created_event
        
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Error creating event: {e}")
        raise


def get_event(user_id: str, event_id: str, calendar_id: str = "primary") -> Dict[str, Any]:
    """Get a specific calendar event by ID."""
    try:
        service = _get_calendar_service(user_id)
        event = service.events().get(calendarId=calendar_id, eventId=event_id).execute()
        return event
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise


def delete_event(user_id: str, event_id: str, calendar_id: str = "primary") -> bool:
    """Delete a calendar event."""
    try:
        service = _get_calendar_service(user_id)
        service.events().delete(calendarId=calendar_id, eventId=event_id).execute()
        logger.info(f"Deleted event {event_id} for user {user_id}")
        return True
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise


def list_calendars(user_id: str) -> List[Dict[str, Any]]:
    """List all calendars for the user."""
    try:
        service = _get_calendar_service(user_id)
        calendars_result = service.calendarList().list().execute()
        calendars = calendars_result.get('items', [])
        logger.info(f"Retrieved {len(calendars)} calendars for user {user_id}")
        return calendars
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise
