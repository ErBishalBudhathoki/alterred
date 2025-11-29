FROM python:3.11-slim

# Install Node.js (required for google-calendar-mcp)
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs graphviz \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Build the Google Calendar MCP with comprehensive error checking
WORKDIR /app/google-calendar-mcp

# Verify package.json exists before attempting build
RUN if [ ! -f package.json ]; then \
    echo "ERROR: google-calendar-mcp/package.json not found!"; \
    exit 1; \
    fi

# Install dependencies and build
RUN echo "Installing MCP dependencies..." && \
    npm ci --quiet && \
    echo "Building MCP server..." && \
    npm run build

# Verify the build succeeded by checking for the output file
RUN if [ ! -f build/index.js ]; then \
    echo "ERROR: MCP build failed - build/index.js not found!"; \
    echo "Contents of google-calendar-mcp directory:"; \
    ls -la; \
    echo "Contents of build directory (if exists):"; \
    ls -la build/ || echo "build/ directory does not exist"; \
    exit 1; \
    else \
    echo "✓ MCP build successful - build/index.js exists"; \
    ls -lh build/index.js; \
    fi

WORKDIR /app

EXPOSE 8080

ENV PYTHONPATH=/app

# Verify critical files exist before starting
RUN echo "Verifying application files..." && \
    ls -la /app/api_server.py && \
    ls -la /app/google-calendar-mcp/build/index.js && \
    echo "✓ All critical files present"

CMD ["sh", "-c", "uvicorn api_server:app --host 0.0.0.0 --port ${PORT:-8080}"]
