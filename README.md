# NeuroPilot

## Overview
- Mobile-first Flutter app with Riverpod state management
- FastAPI backend providing agent endpoints and note capture

## Setup
- Create `.env` from `.env.example` and populate required variables (do not commit secrets)
- Ensure Firebase Admin is configured if using token verification

## Backend
- Run locally:
  - `python -m uvicorn api_server:app --host 0.0.0.0 --port 8000`
- Key endpoints: see `docs/api.md`

## Flutter (Mobile)
- Run app:
  - `flutter run -d "emulator-5554" --flavor development`

## Flutter (Web preview)
- Build:
  - `flutter build web`
- Serve (choose any available port, e.g. 4173):
  - `npx serve -s frontend/flutter_neuropilot/build/web -l 4173`
- External Brain route:
  - `http://localhost:<port>/#/external` (Chat UI button uses the current origin/port)

## Security & Ignore Rules
- Sensitive configuration via environment variables
- `.gitignore` excludes build artifacts and credential files
- Use `.env.example` as the template; do not commit `.env` or service account files

## Tests
- Flutter widget and integration tests under `frontend/flutter_neuropilot/test/`