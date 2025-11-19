# Authentication

## Overview
API endpoints can derive `user_id` from Firebase Auth JWT when provided via `Authorization: Bearer <token>`. If no token is present, identity falls back to the environment user or explicit query parameters.

## Technical Specs
- `services/auth.py` reads the `Authorization` header and verifies ID token if `firebase_admin` is available
- Fallback to `os.getenv('USER')` when token verification is unavailable

## Configuration
- `.env` must configure Firebase Admin credentials via `FIREBASE_SERVICE_ACCOUNT_PATH` for production

## Testing Procedures
- Call endpoints with and without `Authorization` header to observe identity scoping

## Known Limitations
- Full Firebase Auth integration requires service account setup and client-side login; this stub provides optional verification for API requests