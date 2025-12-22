# Deployment Runbook

## Overview

This runbook provides step-by-step procedures for deploying the Neuropilot application across different environments.

## 🚀 Deployment Environments

### Environment Overview
| Environment | Purpose | Branch | Auto-Deploy | Manual Approval |
|-------------|---------|--------|-------------|-----------------|
| **Development** | Feature testing | `dev` | ✅ | ❌ |
| **Staging** | Pre-production validation | `staging` | ✅ | ❌ |
| **Production** | Live application | `main` | ❌ | ✅ |

## 📋 Pre-Deployment Checklist

### General Requirements
- [ ] All required secrets configured in GitHub
- [ ] Branch protection rules enabled
- [ ] CI/CD workflows passing
- [ ] Security scans completed
- [ ] Code review approved

### Environment-Specific Requirements

#### Development
- [ ] Feature branch merged to `dev`
- [ ] Basic security checks passing
- [ ] No hardcoded credentials

#### Staging
- [ ] All development tests passing
- [ ] Integration tests completed
- [ ] Performance benchmarks acceptable

#### Production
- [ ] Staging validation completed
- [ ] Manual approval obtained
- [ ] Rollback plan documented
- [ ] Monitoring alerts configured

## 🔄 Deployment Procedures

### 1. Development Deployment

**Trigger**: Push to `dev` branch

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Develop and test locally
# ... make changes ...

# 3. Push feature branch
git push origin feature/my-feature

# 4. Create PR to dev branch
gh pr create --base dev --title "Feature: My Feature"

# 5. Merge PR (triggers auto-deployment)
gh pr merge --squash
```

**Validation**:
```bash
# Check deployment status
gh workflow list --repo owner/neuropilot

# Verify service health
curl https://neuropilot-api-dev-hash.a.run.app/health

# Test frontend
curl https://neuropilot-dev.web.app
```

### 2. Staging Deployment

**Trigger**: Push to `staging` branch

```bash
# 1. Merge dev to staging
git checkout staging
git merge dev
git push origin staging

# 2. Monitor deployment
gh workflow view deploy-staging.yml --repo owner/neuropilot

# 3. Wait for smoke tests
# Deployment includes automated validation
```

**Smoke Tests** (Automated):
- Backend health check
- Frontend accessibility
- Database connectivity
- API endpoint validation
- Authentication flow

**Manual Validation**:
```bash
# Test critical user flows
curl -X POST https://neuropilot-api-staging-hash.a.run.app/chat/respond \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello", "session_id": "test"}'

# Verify Firebase integration
# Test user registration/login flow
```

### 3. Production Deployment

**Trigger**: Push to `main` branch (requires manual approval)

```bash
# 1. Merge staging to main
git checkout main
git merge staging
git push origin main

# 2. Deployment workflow starts (paused for approval)
gh workflow view deploy.yml --repo owner/neuropilot

# 3. Review deployment request
gh workflow run deploy.yml --ref main

# 4. Approve deployment (authorized personnel only)
# Navigate to GitHub Actions UI for manual approval
```

**Production Validation**:
```bash
# 1. Health check
curl https://neuropilot-api-hash.a.run.app/health

# 2. Frontend verification
curl https://neuropilot-23fb5.web.app

# 3. Monitor error rates
gcloud logging read "resource.type=cloud_run_revision" \
  --filter="severity>=ERROR" --limit=10

# 4. Check performance metrics
gcloud monitoring metrics list --filter="metric.type:run.googleapis.com"
```

## 🛠️ Manual Deployment Procedures

### Emergency Deployment

For critical hotfixes that bypass normal workflow:

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-fix main

# 2. Apply minimal fix
# ... make critical changes only ...

# 3. Test locally
./scripts/test_local.sh

# 4. Deploy directly (emergency only)
./scripts/deploy_emergency.sh --env production --reason "Critical security fix"

# 5. Create PR for review (post-deployment)
gh pr create --base main --title "Hotfix: Critical Fix"
```

### Rollback Procedures

#### Automatic Rollback
```bash
# Rollback to previous Cloud Run revision
gcloud run services update-traffic neuropilot-api \
  --to-revisions=neuropilot-api-00001-abc=100 \
  --region=australia-southeast1

# Rollback Firebase Hosting
firebase hosting:clone neuropilot-23fb5:previous neuropilot-23fb5:current
```

#### Manual Rollback
```bash
# 1. Identify last known good deployment
gh workflow list --repo owner/neuropilot --limit 10

# 2. Revert to specific commit
git revert <commit-hash>
git push origin main

# 3. Monitor rollback deployment
gh workflow view deploy.yml
```

## 📊 Monitoring & Validation

### Health Checks

**Backend Health**:
```bash
# Basic health
curl https://api-url/health

# Detailed health (authenticated)
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api-url/health/detailed
```

**Frontend Health**:
```bash
# Accessibility check
curl -I https://frontend-url

# Performance check
curl -w "@curl-format.txt" -o /dev/null -s https://frontend-url
```

### Performance Monitoring

**Response Time**:
```bash
# Average response time (last 1 hour)
gcloud monitoring metrics list \
  --filter="metric.type=run.googleapis.com/request_latencies"
```

**Error Rates**:
```bash
# 5xx error count (last 1 hour)
gcloud logging read "resource.type=cloud_run_revision" \
  --filter="httpRequest.status>=500" \
  --format="value(timestamp,httpRequest.status)"
```

**Resource Usage**:
```bash
# CPU and memory utilization
gcloud monitoring metrics list \
  --filter="metric.type=run.googleapis.com/container/cpu/utilizations"
```

## 🚨 Troubleshooting

### Common Deployment Issues

#### 1. Secret Not Found
**Symptoms**: Deployment fails with "Secret not found" error

**Resolution**:
```bash
# Check GitHub secrets
gh secret list --repo owner/neuropilot

# Verify secret values (don't log actual values)
gh secret set FIREBASE_API_KEY --body "new-value"
```

#### 2. Build Failures
**Symptoms**: Docker build or Flutter build fails

**Resolution**:
```bash
# Check build logs
gh workflow view deploy.yml --log

# Test build locally
docker build -t test-build .
cd frontend/flutter_neuropilot && flutter build web
```

#### 3. Service Unreachable
**Symptoms**: Deployed service returns 502/503 errors

**Resolution**:
```bash
# Check Cloud Run service status
gcloud run services describe neuropilot-api --region=australia-southeast1

# View service logs
gcloud logs read "resource.type=cloud_run_revision" --limit=50

# Check service configuration
gcloud run services describe neuropilot-api --format=export
```

#### 4. Firebase Deployment Fails
**Symptoms**: Frontend deployment fails or serves old version

**Resolution**:
```bash
# Check Firebase project access
firebase projects:list

# Verify hosting configuration
firebase hosting:sites:list --project neuropilot-23fb5

# Clear hosting cache
firebase hosting:channel:delete preview --project neuropilot-23fb5
```

### Emergency Procedures

#### Service Down
1. **Immediate**: Check service status and logs
2. **Short-term**: Rollback to last known good version
3. **Long-term**: Investigate root cause and implement fix

#### Security Incident
1. **Immediate**: Revoke compromised credentials
2. **Short-term**: Deploy security patches
3. **Long-term**: Review and improve security procedures

#### Data Loss
1. **Immediate**: Stop all write operations
2. **Short-term**: Restore from latest backup
3. **Long-term**: Implement additional backup procedures

## 📞 Escalation Procedures

### Contact Information
- **On-call Engineer**: +1-XXX-XXX-XXXX
- **DevOps Team**: devops@neuropilot.com
- **Security Team**: security@neuropilot.com
- **Product Owner**: product@neuropilot.com

### Escalation Matrix
| Severity | Response Time | Escalation |
|----------|---------------|------------|
| **Critical** (Service down) | 15 minutes | On-call → DevOps Lead → CTO |
| **High** (Degraded performance) | 1 hour | DevOps Team → Engineering Manager |
| **Medium** (Non-critical issues) | 4 hours | Assigned Engineer → Team Lead |
| **Low** (Enhancement requests) | 24 hours | Product Team → Engineering Team |

## 📚 Additional Resources

### Documentation
- [Environment Setup Guide](ENVIRONMENT_SETUP.md)
- [Security Best Practices](SECURITY.md)
- [Monitoring Guide](MONITORING.md)
- [API Documentation](API.md)

### Tools & Dashboards
- **GitHub Actions**: [Workflow Dashboard](https://github.com/owner/neuropilot/actions)
- **Google Cloud Console**: [Cloud Run Services](https://console.cloud.google.com/run)
- **Firebase Console**: [Hosting Dashboard](https://console.firebase.google.com)
- **Monitoring**: [Cloud Monitoring](https://console.cloud.google.com/monitoring)

### Runbook Updates
This runbook should be updated whenever:
- New deployment procedures are added
- Environment configurations change
- Security requirements are modified
- Incident response procedures are updated

**Last Updated**: December 2024
**Next Review**: March 2025