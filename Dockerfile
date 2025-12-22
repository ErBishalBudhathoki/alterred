FROM python:3.11-slim

# Install Node.js and curl (required for google-calendar-mcp and health checks)
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs graphviz curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and install Python requirements first (for better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Build the Google Calendar MCP with comprehensive error checking
WORKDIR /app/google-calendar-mcp

# Verify package.json exists before attempting build
RUN if [ ! -f package.json ]; then \
    echo "ERROR: google-calendar-mcp/package.json not found!"; \
    echo "Contents of google-calendar-mcp directory:"; \
    ls -la; \
    exit 1; \
    fi

# Install dependencies and build with better error handling
RUN echo "Installing MCP dependencies..." && \
    npm ci --quiet 2>&1 | tee npm-install.log && \
    echo "Building MCP server..." && \
    npm run build 2>&1 | tee npm-build.log

# Verify the build succeeded by checking for the output file
RUN if [ ! -f build/index.js ]; then \
    echo "ERROR: MCP build failed - build/index.js not found!"; \
    echo "Contents of google-calendar-mcp directory:"; \
    ls -la; \
    echo "Contents of build directory (if exists):"; \
    ls -la build/ || echo "build/ directory does not exist"; \
    echo "NPM install log:"; \
    cat npm-install.log || echo "No install log found"; \
    echo "NPM build log:"; \
    cat npm-build.log || echo "No build log found"; \
    exit 1; \
    else \
    echo "✓ MCP build successful - build/index.js exists"; \
    ls -lh build/index.js; \
    fi

WORKDIR /app

# Expose the port
EXPOSE 8080

# Set Python path
ENV PYTHONPATH=/app

# Verify critical files exist before starting
RUN echo "Verifying application files..." && \
    ls -la /app/api_server.py && \
    ls -la /app/google-calendar-mcp/build/index.js && \
    echo "✓ All critical files present"

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# Use exec form and add better error handling
CMD ["sh", "-c", "echo 'Starting server on port ${PORT:-8080}...' && exec uvicorn api_server:app --host 0.0.0.0 --port ${PORT:-8080} --log-level info"]
