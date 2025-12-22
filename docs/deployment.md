# Deployment

## Pre-Deployment Validation

Before deploying, run the validation script to check for common issues:

```bash
# Validate deployment readiness
python test_deployment_fix.py

# This script checks:
# - Dockerfile syntax and build requirements
# - Python import integrity (api_server.py)
# - Requirements.txt package availability  
# - Deployment workflow YAML structure
```

## Docker

### Building the Container
```bash
# Build the Docker image
docker build -t neuropilot-api .

# The build process includes:
# - Python dependencies installation with caching optimization
# - Google Calendar MCP compilation with enhanced error handling
# - Build verification and comprehensive logging
```

### Running the Container
```bash
# Run with environment file
docker run -p 8080:8080 --env-file .env neuropilot-api

# Run with individual environment variables
docker run -p 8080:8080 \
  -e GOOGLE_API_KEY=your_key \
  -e DEFAULT_MODEL=gemini-2.0-flash \
  neuropilot-api

# Run with custom port
docker run -p 3000:3000 -e PORT=3000 --env-file .env neuropilot-api
```

### Health Check
The Docker container includes a built-in health check that:
- Runs every 30 seconds
- Has a 10-second timeout
- Allows 5 seconds for startup
- Retries up to 3 times before marking as unhealthy

```bash
# Check container health status
docker ps  # Shows health status in STATUS column

# View health check logs
docker inspect --format='{{json .State.Health}}' <container_id>
```

The health check endpoint:
- `GET /health` returns `{ "ok": true }`
- Available at `http://localhost:${PORT}/health`

## Cloud Run Deployment

### Prerequisites
- Google Cloud project with required APIs enabled
- Artifact Registry or Container Registry configured
- Proper IAM permissions for deployment

### Build and Deploy
```bash
# Build and push to Google Container Registry
gcloud builds submit --tag gcr.io/$PROJECT_ID/neuropilot-api

# Deploy to Cloud Run
gcloud run deploy neuropilot-api \
  --image gcr.io/$PROJECT_ID/neuropilot-api \
  --region australia-southeast1 \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "GOOGLE_API_KEY=<key>,DEFAULT_MODEL=gemini-2.0-flash"
```

### Environment Variables
Cloud Run deployment requires these environment variables:
- `GOOGLE_API_KEY`: Gemini API key
- `DEFAULT_MODEL`: AI model (e.g., `gemini-2.0-flash`)
- `PORT`: Container port (automatically set by Cloud Run, defaults to 8080)
- `FIREBASE_PROJECT_ID`: Firebase project identifier
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account JSON (for Cloud Speech/TTS APIs)
- Additional variables as needed (see `.env.example`)

## Requirements

### System Dependencies
- Docker (for containerized deployment)
- Python 3.10+ (for local development)
- Node.js 18+ (for MCP server compilation)

### Application Dependencies
- `requirements.txt`: Python dependencies with version pinning
  - Core AI: `google-genai`, `google-generativeai`, `google-cloud-aiplatform`
  - Voice Services: `google-cloud-speech`, `google-cloud-texttospeech`
  - Web Framework: `fastapi`, `uvicorn`
  - Firebase: `firebase-admin`
- `google-calendar-mcp/package.json`: MCP server dependencies
- `.env` file with required configuration

### Minimum Environment Configuration
```env
GOOGLE_API_KEY=your_gemini_api_key
DEFAULT_MODEL=gemini-2.0-flash
FIREBASE_PROJECT_ID=your_firebase_project
PORT=8080
```

## Troubleshooting

### Build Issues
If the Docker build fails:

1. **Run Pre-Deployment Validation**: 
   ```bash
   python test_deployment_fix.py
   ```
   This will identify common issues before attempting the build.

2. **MCP Build Failure**: Check the build logs for Node.js/npm errors
   ```bash
   # The Dockerfile now captures detailed logs
   docker build -t neuropilot-api . 2>&1 | tee build.log
   ```

2. **Missing Dependencies**: Ensure all required files are present
   ```bash
   # Verify critical files exist
   ls -la requirements.txt
   ls -la google-calendar-mcp/package.json
   ```

3. **Permission Issues**: Check Docker daemon permissions
   ```bash
   # On Linux, ensure user is in docker group
   sudo usermod -aG docker $USER
   ```

### Runtime Issues
If the container fails to start:

1. **Port Conflicts**: Ensure the port is available
   ```bash
   # Check if port is in use
   lsof -i :8080
   ```

2. **Environment Variables**: Verify all required variables are set
   ```bash
   # Check container environment
   docker exec <container_id> env | grep -E "(GOOGLE_API_KEY|DEFAULT_MODEL)"
   ```

3. **Health Check Failures**: Monitor the health endpoint
   ```bash
   # Test health endpoint directly
   curl -f http://localhost:8080/health
   ```

## Production Considerations

### Security
- Never include secrets in the Docker image
- Use environment variables or secret management systems
- Regularly update base images and dependencies
- Enable security scanning in CI/CD pipelines

### Performance
- The Dockerfile is optimized for layer caching
- Python requirements are installed before copying application code
- Consider using multi-stage builds for smaller production images

### Monitoring
- Health checks are automatically configured
- Monitor container logs for build and runtime issues
- Set up alerting for health check failures
- Use structured logging for better observability

## Notes
- Firebase Admin credentials must be provided via environment variables or mounted volumes
- The container runs on port 8080 by default (configurable via PORT environment variable)
- MCP server compilation happens during Docker build with comprehensive error reporting
- All critical files are verified before container startup