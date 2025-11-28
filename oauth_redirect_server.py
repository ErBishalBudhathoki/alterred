"""
OAuth Redirect Server
=====================

This server runs on port 3500 to catch OAuth callbacks from the MCP NPM package
and forwards them to the main backend server on port 8000.

The MCP calendar NPM package uses localhost:3500/oauth2callback as its redirect URI.
This server simply forwards those requests to our backend API.
"""

from flask import Flask, request, redirect
import sys

app = Flask(__name__)

@app.route('/oauth2callback')
def oauth_callback():
    """
    Catch OAuth callback from Google and forward to our backend.
    
    The MCP package redirects to: http://localhost:3500/oauth2callback?code=...&scope=...
    We forward to: http://localhost:8000/auth/google/calendar/callback?code=...&state=...
    """
    code = request.args.get('code')
    scope = request.args.get('scope')
    
    if not code:
        return {"error": "No authorization code received"}, 400
    
    # Use a default state since MCP doesn't provide it
    # In production, you might want to maintain a session to track the actual user
    state = request.args.get('state', 'mcp_redirect')
    
    # Forward to our backend
    redirect_url = f'http://localhost:8000/auth/google/calendar/callback?code={code}&state={state}'
    
    print(f"Forwarding OAuth callback to: {redirect_url}")
    
    return redirect(redirect_url, code=302)

@app.route('/health')
def health():
    """Health check endpoint."""
    return {"ok": True, "service": "oauth-redirect-server", "port": 3500}

@app.route('/')
def index():
    """Root endpoint - show simple status."""
    return {
        "service": "OAuth Redirect Server",
        "status": "running",
        "port": 3500,
        "purpose": "Forwards MCP OAuth callbacks to main backend"
    }

if __name__ == '__main__':
    print("=" * 60)
    print("OAuth Redirect Server")
    print("=" * 60)
    print("Starting server on http://localhost:3500")
    print("Forwarding OAuth callbacks to http://localhost:8000")
    print("=" * 60)
    
    try:
        app.run(host='0.0.0.0', port=3500, debug=False)
    except KeyboardInterrupt:
        print("\nShutting down OAuth redirect server...")
        sys.exit(0)
