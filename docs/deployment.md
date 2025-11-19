# Deployment

## Docker
- Build: `docker build -t neuropilot-api .`
- Run: `docker run -p 8000:8000 --env-file .env neuropilot-api`

## Cloud Run (example)
- Ensure Google Cloud project and Artifact Registry
- Build and push:
  - `gcloud builds submit --tag gcr.io/$PROJECT_ID/neuropilot-api`
- Deploy:
  - `gcloud run deploy neuropilot-api --image gcr.io/$PROJECT_ID/neuropilot-api --region us-central1 --allow-unauthenticated --set-env-vars "GOOGLE_API_KEY=<key>,DEFAULT_MODEL=gemini-2.5-flash"`

## Requirements
- `requirements.txt` lists Python dependencies
- `.env` must include at minimum `GOOGLE_API_KEY` and `DEFAULT_MODEL`

## Health Check
- `GET /health` returns `{ ok: true }`

## Notes
- Firebase Admin credentials must be provided via volume or env path set in `.env`