#!/usr/bin/env python3
"""
Calendar Connection Diagnostic Tool
==================================== 
Tests calendar connection in production to diagnose why calendar doesn't work
even when the user has connected it in Settings.

Usage: python scripts/diagnose_calendar.py <user_id>
"""

import os
import sys
import json
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.user_settings import UserSettings
from services.calendar_mcp import check_mcp_ready, list_events_today, _get_user_credentials_file
import services.firebase_client as firebase_client

def diagnose_calendar_connection(user_id: str):
    """
    Comprehensive diagnostic for calendar connection issues.
    """
    print("=" * 80)
    print(f"🔍 Calendar Connection Diagnostic for User: {user_id}")
    print("=" * 80)
    
    # Initialize Firebase
    firebase_client.init_firebase()
    
    try:
        settings = UserSettings(user_id)
        
        # Check 1: OAuth Connection Status
        print("\n📋 Check 1: OAuth Connection Status")
        is_connected = settings.is_oauth_connected("google_calendar")
        print(f"   Connected in settings: {is_connected}")
        
        # Check 2: Retrieve OAuth Tokens
        print("\n📋 Check 2: OAuth Tokens")
        tokens = settings.get_oauth_tokens("google_calendar")
        if tokens:
            print("   ✅ Tokens found in Firestore")
            print(f"   Provider: {tokens.get('provider')}")
            print(f"   Scopes: {tokens.get('scopes')}")
            print(f"   Has access_token: {bool(tokens.get('access_token'))}")
            print(f"   Has refresh_token: {bool(tokens.get('refresh_token'))}")
            
            # Check expiration
            expires_at_str = tokens.get("expires_at")
            if expires_at_str:
                try:
                    expires_at = datetime.fromisoformat(expires_at_str)
                    now = datetime.now(expires_at.tzinfo) if expires_at.tzinfo else datetime.now()
                    is_expired = now >= expires_at
                    print(f"   Expires at: {expires_at_str}")
                    print(f"   Expired: {is_expired}")
                except Exception as e:
                    print(f"   ⚠️  Could not parse expires_at: {e}")
        else:
            print("   ❌ No tokens found in Firestore")
            return
        
        # Check 3: Credentials File Path
        print("\n📋 Check 3: Credentials File Resolution")
        creds_path = _get_user_credentials_file(user_id, "normal")
        if creds_path:
            print(f"   ✅ Credentials file created: {creds_path}")
            print(f"   File exists: {os.path.exists(creds_path)}")
            if os.path.exists(creds_path):
                print(f"   File size: {os.path.getsize(creds_path)} bytes")
                # Show structure (without sensitive data)
                try:
                    with open(creds_path, 'r') as f:
                        data = json.load(f)
                    print(f"   Structure: type={data.get('type')}, has_client_id={bool(data.get('client_id'))}, has_refresh_token={bool(data.get('refresh_token'))}, has_access_token={bool(data.get('access_token'))}")
                except Exception as e:
                    print(f"   ⚠️  Could not read file: {e}")
        else:
            print("   ❌ No credentials file resolved")
            return
        
        # Check 4: MCP Server Ready
        print("\n📋 Check 4: MCP Server Status")
        try:
            mcp_status = check_mcp_ready(user_id=user_id)
            if mcp_status.get("ok"):
                print(f"   ✅ MCP server is ready")
                print(f"   Tools available: {mcp_status.get('tools', [])}")
            else:
                print(f"   ❌ MCP server not ready: {mcp_status.get('error')}")
                return
        except Exception as e:
            print(f"   ❌ MCP check failed: {e}")
            import traceback
            traceback.print_exc()
            return
        
        # Check 5: List Events Test
        print("\n📋 Check 5: List Events Test")
        try:
            events_result = list_events_today(user_id=user_id)
            if events_result.get("ok"):
                events = events_result.get("result", {}).get("events", [])
                print(f"   ✅ Successfully listed events")
                print(f"   Event count: {len(events)}")
                if events:
                    print(f"   First event: {events[0].get('summary', 'No summary')}")
            else:
                print(f"   ❌ Failed to list events: {events_result.get('error')}")
        except Exception as e:
            print(f"   ❌ List events test failed: {e}")
            import traceback
            traceback.print_exc()
        
        print("\n" + "=" * 80)
        print("✅ Diagnostic Complete")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ Diagnostic failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/diagnose_calendar.py <user_id>")
        print("\nExample:")
        print("  python scripts/diagnose_calendar.py abc123")
        sys.exit(1)
    
    user_id = sys.argv[1]
    diagnose_calendar_connection(user_id)
