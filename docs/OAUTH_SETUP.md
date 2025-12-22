# Multi-User OAuth and API Key Setup Guide

## Overview
This guide will help you set up per-user Google Calendar OAuth and custom Gemini API keys.

## Prerequisites
1. Google Cloud Project with Calendar API enabled
2. OAuth 2.0 credentials configured
3. Firebase project set up

## Setup Steps

### 1. Generate Encryption Key

Run the helper script to generate an encryption key:

```bash
python scripts/generate_encryption_key.py
```

Copy the output and add it to your `.env` file.

### 2. Configure Google Cloud OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** > **Credentials**
3. Click **Create Credentials** > **OAuth 2.0 Client ID**
4. Choose **Web application**
5. Add authorized redirect URI:
   - For local development: `http://localhost:8000/auth/google/calendar/callback`
   - For production: `https://yourdomain.com/auth/google/calendar/callback`
6. Copy the **Client ID** and **Client Secret**

### 3. Update Environment Variables

Edit `.env` and fill in the OAuth values:

```bash
ENCRYPTION_KEY=<paste_generated_key>
GOOGLE_OAUTH_CLIENT_ID=<paste_client_id>
GOOGLE_OAUTH_CLIENT_SECRET=<paste_client_secret>
OAUTH_REDIRECT_URI=http://localhost:8000/auth/google/calendar/callback
```

### 4. Update Firestore Security Rules

Add these rules to `firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...
    
    // User settings (readable/writable by owner)
    match /users/{userId}/settings/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // OAuth tokens (server-only access)
    match /users/{userId}/oauth_tokens/{document=**} {
      allow read, write: if false;  // Only accessible via server SDK
    }
  }
}
```

Deploy the rules:

```bash
firebase deploy --only firestore:rules
```

### 5. Test the Setup

1. Start the backend:
   ```bash
   uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
   ```

2. Test endpoints (use a tool like curl or Postman):
   ```bash
   # Get OAuth authorization URL
   curl http://localhost:8000/auth/google/calendar
   
   # Check calendar status
   curl http://localhost:8000/auth/google/calendar/status
   ```

## User Flow

### Connecting Calendar

1. User opens Settings in the app
2. Clicks "Connect Google Calendar"
3. Redirected to Google consent screen
4. After approval, redirected back with tokens
5. Tokens stored encrypted in Firestore

### Using Custom API Key

1. User opens Settings
2. Enters their Gemini API key
3. Key is validated and stored encrypted
4. Chat uses their key instead of system default

## Security Notes

- ✅ All tokens and keys are encrypted at rest using Fernet symmetric encryption
- ✅ OAuth tokens are never exposed to the client
- ✅ Token refresh is handled automatically
- ✅ Users can revoke access at any time
- ⚠️ Keep `ENCRYPTION_KEY` secure and never commit to git
- ⚠️ Backup the encryption key - if lost, all stored credentials become inaccessible

## Troubleshooting

### "ENCRYPTION_KEY not set" error
Run the key generation script and add it to `.env`

### "OAuth credentials not configured" error
Check that `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET` are set in `.env`

### Calendar not connecting
1. Verify OAuth redirect URI matches in both Google Cloud Console and `.env`
2. Check that Google Calendar API is enabled in your project
3. Ensure user has granted calendar permissions

### API key validation fails
1. Check that the key is valid on [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Verify the key has proper permissions
3. Check for quota limits

## Migration from Single OAuth

Existing users will continue to use the system default `GOOGLE_OAUTH_CREDENTIALS` until they opt-in to personal OAuth by connecting their calendar in settings.
