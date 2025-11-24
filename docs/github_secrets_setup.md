# GitHub Secrets Setup Guide

Follow these steps to configure the required secrets for your GitHub Actions deployment workflow.

## How to Add Secrets

1. Go to your GitHub repository: `https://github.com/BishalBudhathoki/alterred`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. For each secret below:
   - Enter the **Name** (exactly as shown)
   - Copy and paste the **Value**
   - Click **Add secret**

---

## Required Secrets

### Backend API Secret

| Secret Name | Value |
|------------|-------|
| `GOOGLE_API_KEY` | `AIzaSyBuyejVvfdIm1Jr7Ihd-9uZ6oKFTyIlnus` |

### Firebase Configuration Secrets

| Secret Name | Value |
|------------|-------|
| `FIREBASE_API_KEY` | `AIzaSyBP0AFK0v-tubKMb7NQdQNOqCb6rEmZVIw` |
| `FIREBASE_APP_ID` | `1:848026269314:web:496ec795532a3b8363269b` |
| `FIREBASE_MESSAGING_SENDER_ID` | `848026269314` |
| `FIREBASE_PROJECT_ID` | `neuropilot-23fb5` |
| `FIREBASE_AUTH_DOMAIN` | `neuropilot-23fb5.firebaseapp.com` |
| `FIREBASE_STORAGE_BUCKET` | `neuropilot-23fb5.firebasestorage.app` |
| `FIREBASE_MEASUREMENT_ID` | `G-RXLZ8BVQT2` |

---

## After Adding Secrets

Once all secrets are added:

1. Go to **Actions** tab in your repository
2. Find the failed deployment workflow run
3. Click **Re-run jobs** → **Re-run all jobs**

OR simply push a new commit to trigger a fresh deployment:

```bash
git commit --allow-empty -m "Trigger deployment with secrets"
git push origin main
```

---

## Verification

After the workflow completes successfully:

- ✅ Backend API should respond without "Missing key inputs" errors
- ✅ Frontend should load past the splash screen
- ✅ Firebase authentication should work
- ✅ Chat functionality should work with Gemini API

---

> **Note**: These secrets are only used for production deployment. Your local development uses the [.env](file:///Users/pratikshatiwari/Documents/trae_projects/altered/.env) file instead.
