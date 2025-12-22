# Neuropilot Troubleshooting Guide

This guide covers common issues encountered during development and deployment of the Neuropilot system.

## Calendar Integration

### Issue: "Redirect URI mismatch"
**Symptoms:** Error 400: `redirect_uri_mismatch` during Google Calendar OAuth.
**Cause:** The redirect URI configured in Google Cloud Console does not match the one being used by the application.
**Solution:**
1.  Go to [Google Cloud Console > credentials](https://console.cloud.google.com/apis/credentials).
2.  Ensure your OAuth 2.0 Client ID has the following Authorized redirect URIs:
    -   `http://localhost:8000/auth/google/calendar/callback` (Local Development)
    -   `https://<your-project-id>.web.app/auth/google/calendar/callback` (Production)
3.  Update your `.env` file to match:
    ```env
    OAUTH_REDIRECT_URI=http://localhost:8000/auth/google/calendar/callback
    ```

### Issue: "Calendar agent cannot list events"
**Symptoms:** Agent says "I can't access your calendar" even after linking.
**Cause:** Token expiration or missing scopes.
**Solution:**
1.  Check the `users/{uid}` document in Firestore. Ensure `tokens.google_calendar` exists.
2.  If tokens exist but are old, try re-linking in Settings.
3.  Verify the backend has `offline` access type to get a refresh token.

## Voice & Audio

### Issue: "No audio output from Piper"
**Symptoms:** Text is generated but no sound plays.
**Cause:** Missing voice model files or `piper` binary executable issues.
**Solution:**
1.  Run `python scripts/setup_voice.py` to download models.
2.  Ensure `voice_models/en_US-lessac-medium.onnx` exists.
3.  If on Mac, ensure the `piper` binary in `bin/piper` is executable (`chmod +x bin/piper/piper`).

### Issue: "Voice recognition cuts off too early"
**Cause:** Silence detection threshold is too aggressive.
**Solution:**
-   Adjust `silence_threshold` in `services/voice_manager.py` (default is usually around 500-1000ms).

## Deployment

### Issue: "Cloud Run service does not exist"
**Symptoms:** GitHub Actions failure during Firebase deploy.
**Cause:** Firebase Hosting tries to rewrite to a Cloud Run service that hasn't finished deploying yet.
**Solution:**
-   First deploy the backend independently: `./scripts/deploy_backend.sh`.
-   Once the service `neuropilot-api` is active in Cloud Run console, re-run the frontend deployment.

### Issue: "Build failed: Function converted via 'toJS' contains invalid types"
**Symptoms:** Flutter web build error (WASM related).
**Solution:**
-   This is often due to `js_interop` issues in dependent packages.
-   Ensure you are using the latest `flutter_tts` and related packages.
-   Try building without WASM if persistent: `flutter build web --release --no-wasm`.

## Timer & State

### Issue: "Timer progress bar stuck"
**Cause:** The client and server clocks might be out of sync, or the stream connection was lost.
**Solution:**
-   The app uses `DateTime.now()` on the client. Ensure device time is set to automatic.
-   Refresh the page/app to reconnect the `BackendHealthNotifier`.

## Still stuck?
Check the `issues.md` file in the root directory for a log of active and resolved development issues.
