# Environment Setup Guide

This document outlines the multi-environment setup for the Neuropilot application.

## Environment Structure

### 🏭 Production (`main` branch)
- **GCP Project**: `neuropilot-23fb5` (main)
- **Cloud Run Service**: `neuropilot-api`
- **Firebase Project**: `neuropilot-23fb5`
- **Domain**: `neuropilot-23fb5.web.app`
- **Resources**: Full production specs (2 CPU, 2Gi RAM)

### 🧪 Staging (`staging` branch)
- **GCP Project**: `neuropilot-23fb5` (shared) or dedicated staging project
- **Cloud Run Service**: `neuropilot-api-staging`
- **Firebase Project**: Staging project or staging hosting target
- **Domain**: `neuropilot-staging.web.app`
- **Resources**: Production-like specs (2 CPU, 2Gi RAM)

### 🔧 Development (`dev`/`development` branches)
- **GCP Project**: `neuropilot-23fb5` (shared) or dedicated dev project
- **Cloud Run Service**: `neuropilot-api-dev`
- **Firebase Project**: Dev project or dev hosting target
- **Domain**: `neuropilot-dev.web.app`
- **Resources**: Minimal specs (1 CPU, 1Gi RAM, max 5 instances)

## Required GitHub Secrets

### Production Secrets (Required)
```
FIREBASE_API_KEY=AIza...
FIREBASE_APP_ID=1:848026269314:web:...
FIREBASE_MESSAGING_SENDER_ID=848026269314
FIREBASE_PROJECT_ID=neuropilot-23fb5
FIREBASE_AUTH_DOMAIN=neuropilot-23fb5.firebaseapp.com
FIREBASE_STORAGE_BUCKET=neuropilot-23fb5.firebasestorage.app
FIREBASE_MEASUREMENT_ID=G-...

GOOGLE_API_KEY=AIza...
GOOGLE_OAUTH_CLIENT_ID=848026269314-...
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-...

ENCRYPTION_KEY=<32-byte-base64-key>
ADMIN_API_TOKEN=<secure-random-token>
CALENDAR_MCP_TOKEN=<mcp-token>

FIREBASE_ADMIN_SA_JSON=<service-account-json>
ANDROID_GOOGLE_SERVICES_JSON_DEV=<dev-google-services>
ANDROID_GOOGLE_SERVICES_JSON_PROD=<prod-google-services>
```

### Environment-Specific Secrets (Optional)
If you want separate Firebase projects for each environment:

```
# Development
FIREBASE_API_KEY_DEV=AIza...
FIREBASE_PROJECT_ID_DEV=neuropilot-dev
FIREBASE_AUTH_DOMAIN_DEV=neuropilot-dev.firebaseapp.com
# ... (other Firebase configs for dev)

# Staging  
FIREBASE_API_KEY_STAGING=AIza...
FIREBASE_PROJECT_ID_STAGING=neuropilot-staging
FIREBASE_AUTH_DOMAIN_STAGING=neuropilot-staging.firebaseapp.com
# ... (other Firebase configs for staging)
```

## Required GitHub Variables

### Core Variables (Required)
```
GCP_PROJECT_ID=neuropilot-23fb5
REGION=australia-southeast1
BACKUP_BUCKET=neuropilot-backups
DEFAULT_MODEL=gemini-2.0-flash
FORCE_VERTEX_AI=true

WIF_PROVIDER=projects/848026269314/locations/global/...
WIF_SERVICE_ACCOUNT=github-actions-deployer@neuropilot-23fb5.iam.gserviceaccount.com

OAUTH_REDIRECT_URI=https://neuropilot-23fb5.web.app/auth/google
```

### Environment-Specific Variables (Optional)
```
# Development
GCP_PROJECT_ID_DEV=neuropilot-dev
FIREBASE_PROJECT_ID_DEV=neuropilot-dev
OAUTH_REDIRECT_URI_DEV=https://neuropilot-dev.web.app/auth/google

# Staging
GCP_PROJECT_ID_STAGING=neuropilot-staging  
FIREBASE_PROJECT_ID_STAGING=neuropilot-staging
OAUTH_REDIRECT_URI_STAGING=https://neuropilot-staging.web.app/auth/google
```

## Branch Protection Rules

### Automatic Checks
All branches (`main`, `staging`, `dev`, `development`) require:

1. **Security Checks** ✅
   - No hardcoded secrets
   - Proper .gitignore coverage
   - Secret configuration validation

2. **Code Quality** ⚠️
   - Flutter analysis passes
   - Python linting (warnings only)
   - No critical issues

3. **Test Coverage** ⚠️
   - Flutter tests pass
   - Python tests pass (if present)
   - Coverage reports generated

4. **Deployment Readiness** ✅ (for `main`/`staging` PRs)
   - Required deployment files exist
   - Firebase configuration valid
   - Environment variables set

### Manual Approval
- **Production** (`main`): Requires manual approval for deployment
- **Staging**: Auto-deploys with smoke tests
- **Development**: Auto-deploys with minimal validation

## Deployment Flow

```
Feature Branch
    ↓
Development Branch (dev) → Auto-deploy to dev environment
    ↓
Staging Branch → Auto-deploy to staging + smoke tests
    ↓
Main Branch → Manual approval → Deploy to production
```

## Setting Up New Environment

### 1. Create Firebase Project (Optional)
```bash
# Create new Firebase project for environment
firebase projects:create neuropilot-dev
firebase use neuropilot-dev
firebase init hosting
```

### 2. Create GCP Project (Optional)
```bash
# Create new GCP project
gcloud projects create neuropilot-dev
gcloud config set project neuropilot-dev

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable firestore.googleapis.com
```

### 3. Add GitHub Secrets
Add environment-specific secrets to GitHub repository settings.

### 4. Update Workflows
Environment-specific workflows are already created:
- `.github/workflows/deploy-dev.yml`
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/deploy.yml` (production)

### 5. Test Deployment
```bash
# Trigger deployment
git push origin dev        # Deploys to development
git push origin staging    # Deploys to staging  
git push origin main       # Deploys to production (with approval)
```

## Monitoring & Observability

Each environment includes:
- **Health Checks**: `/health` endpoint monitoring
- **Error Tracking**: 5xx error rate alerts
- **Performance**: Response time monitoring
- **Logs**: Centralized logging in Cloud Logging

## Security Considerations

1. **Secrets Rotation**: Rotate secrets regularly, especially after team changes
2. **Access Control**: Use least-privilege IAM roles
3. **Network Security**: VPC connectors for database access
4. **Audit Logging**: All deployments and access logged
5. **Branch Protection**: Required status checks prevent insecure deployments

## Troubleshooting

### Common Issues

1. **Secret Not Found**: Check GitHub secrets are set for the environment
2. **Firebase Deploy Fails**: Verify Firebase project exists and CLI is authenticated
3. **Cloud Run Deploy Fails**: Check GCP project permissions and quotas
4. **Branch Protection Blocks**: Review failed checks in GitHub Actions

### Debug Commands
```bash
# Check Cloud Run service
gcloud run services describe neuropilot-api-dev --region australia-southeast1

# Check Firebase hosting
firebase hosting:sites:list --project neuropilot-dev

# Validate secrets locally
gh secret list --repo owner/neuropilot
```