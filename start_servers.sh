#!/bin/bash

# Start Servers Script
# This script starts both the main backend (port 8000) and the OAuth redirect server (port 3500)

echo "=================================================="
echo "Starting NeuroPilot Servers"
echo "=================================================="

# Check if Flask is installed
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Installing Flask..."
    pip install flask
fi

# Kill any existing processes on these ports
echo "Cleaning up existing processes..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:3500 | xargs kill -9 2>/dev/null || true

# Start OAuth redirect server in background
echo "Starting OAuth redirect server on port 3500..."
python3 oauth_redirect_server.py &
REDIRECT_PID=$!
echo "OAuth redirect server PID: $REDIRECT_PID"

# Give it a moment to start
sleep 1

# Start main backend
echo "Starting main backend on port 8000..."
echo "=================================================="
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload

# When uvicorn is killed, also kill the redirect server
kill $REDIRECT_PID 2>/dev/null || true
