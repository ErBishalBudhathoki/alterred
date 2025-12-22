"""
Direct Google Calendar API Integration
=======================================

This module provides direct Google Calendar API access using tokens from Settings OAuth,
bypassing the MCP NPM package which has OAuth compatibility issues.
"""

import os
from datetime import datetime, timedelta
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
        if expires_at.tzinfo is not None:
            expires_at = expires_at.astimezone().replace(tzinfo=None)
    except Exception:
        expires_at = datetime.now()
    
    # Refresh if expired or expiring soon
    if datetime.now() >= (expires_at - timedelta(minutes=5)):
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
            'start': {'dateTime': start_time},
            'end': {'dateTime': end_time},
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


def list_events_all_calendars(
    user_id: str, 
    start_time: str, 
    end_time: str, 
    max_results_per_calendar: int = 50,
    include_declined: bool = False
) -> List[Dict[str, Any]]:
    """
    List calendar events from ALL visible/selected calendars within a time range.
    
    This function queries all calendars the user can see (including subscribed calendars
    from the "Other calendars" section), and merges/sorts the events by start time.
    
    Args:
        user_id: User ID
        start_time: ISO format start time
        end_time: ISO format end time
        max_results_per_calendar: Maximum number of events to return per calendar
        include_declined: Whether to include events the user has declined
    
    Returns:
        List of event dictionaries from all visible calendars, sorted by start time
    """
    try:
        service = _get_calendar_service(user_id)
        
        # Get all visible calendars
        calendars = list_calendars(user_id)
        
        # Log all calendars found for debugging
        logger.info(f"Found {len(calendars)} total calendars for user {user_id}")
        for cal in calendars:
            cal_id = cal.get('id', 'unknown')
            cal_summary = cal.get('summary', 'Untitled')
            cal_selected = cal.get('selected', 'unspecified')
            cal_access = cal.get('accessRole', 'unknown')
            logger.debug(f"  Calendar: '{cal_summary}' (id={cal_id[:30]}..., selected={cal_selected}, accessRole={cal_access})")
        
        # Include ALL calendars with any access role (owner, writer, reader, freeBusyReader)
        # This includes:
        # - "My calendars" section: typically owner or writer
        # - "Other calendars" section: typically reader or freeBusyReader (subscribed calendars)
        # We explicitly include calendars regardless of 'selected' status to capture all subscribed calendars
        accessible_calendars = [
            cal for cal in calendars 
            if cal.get('accessRole') in ('owner', 'writer', 'reader', 'freeBusyReader')
        ]
        
        logger.info(f"Querying {len(accessible_calendars)} accessible calendars for user {user_id}")
        
        # Normalize datetime format to RFC3339 (required by Google Calendar API)
        # If timezone is missing, append 'Z' for UTC
        def normalize_datetime(dt_str: str) -> str:
            """Ensure datetime string has timezone suffix for RFC3339 compliance."""
            if not dt_str:
                return dt_str
            # Already has timezone info (contains + or Z at the end)
            if '+' in dt_str or dt_str.endswith('Z') or '-' in dt_str[10:]:
                return dt_str
            # No timezone - append 'Z' for UTC
            return dt_str + 'Z'
        
        start_time_normalized = normalize_datetime(start_time)
        end_time_normalized = normalize_datetime(end_time)
        logger.debug(f"Normalized time range: {start_time_normalized} to {end_time_normalized}")
        
        all_events = []
        
        for cal in accessible_calendars:
            calendar_id = cal.get('id', 'primary')
            calendar_summary = cal.get('summary', 'Unknown')
            
            try:
                events_result = service.events().list(
                    calendarId=calendar_id,
                    timeMin=start_time_normalized,
                    timeMax=end_time_normalized,
                    maxResults=max_results_per_calendar,
                    singleEvents=True,
                    orderBy='startTime'
                ).execute()
                
                events = events_result.get('items', [])
                
                # Add calendar source info to each event for display
                for event in events:
                    event['_calendarId'] = calendar_id
                    event['_calendarSummary'] = calendar_summary
                    
                    # Filter out declined events if requested
                    if not include_declined:
                        attendees = event.get('attendees', [])
                        user_response = None
                        for attendee in attendees:
                            if attendee.get('self'):
                                user_response = attendee.get('responseStatus')
                                break
                        if user_response == 'declined':
                            continue
                    
                    all_events.append(event)
                
                logger.debug(f"Retrieved {len(events)} events from calendar '{calendar_summary}' ({calendar_id})")
                
            except HttpError as e:
                # Log but continue with other calendars if one fails
                logger.warning(f"Failed to query calendar '{calendar_summary}' ({calendar_id}): {e}")
                continue
        
        # Sort all events by start time
        def get_start_time(event: Dict[str, Any]) -> str:
            start = event.get('start', {})
            return start.get('dateTime') or start.get('date') or ''
        
        all_events.sort(key=get_start_time)
        
        logger.info(f"Retrieved {len(all_events)} total events from {len(accessible_calendars)} calendars for user {user_id}")
        return all_events
        
    except HttpError as e:
        logger.error(f"Google Calendar API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Error listing events from all calendars: {e}")
        raise

