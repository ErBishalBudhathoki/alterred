FROM python:3.11-slim

# Install Node.js (required for google-calendar-mcp)
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Build the Google Calendar MCP
WORKDIR /app/google-calendar-mcp
RUN npm ci && npm run build

WORKDIR /app

EXPOSE 8080

CMD ["sh", "-c", "uvicorn api_server:app --host 0.0.0.0 --port ${PORT:-8080}"]
