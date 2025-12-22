# Branch Protection Setup Guide

Since the automated script is having issues with the GitHub API, let's set up branch protection manually through the GitHub web interface.

## 🛡️ Manual Branch Protection Setup

### Step 1: Navigate to Branch Protection Settings

1. Go to your repository: https://github.com/BishalBudhathoki/alterred
2. Click on **Settings** tab
3. Click on **Branches** in the left sidebar
4. Click **Add rule** next to "Branch protection rules"

### Step 2: Configure Main Branch Protection

**Branch name pattern**: `main`

**Protect matching branches** - Enable these settings:

#### ✅ Required Status Checks
- [x] Require status checks to pass before merging
- [x] Require branches to be up to date before merging

**Status checks that are required:**
- `Security & Secrets Validation`
- `Code Quality Checks`
- `Test Coverage`
- `Deployment Readiness`

*Note: These will appear after your first workflow runs*

#### ✅ Required Pull Request Reviews
- [x] Require a pull request before merging
- [x] Require approvals: **2**
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require review from code owners

#### ✅ Additional Restrictions
- [x] Restrict pushes that create files larger than 100 MB
- [x] Require signed commits (optional but recommended)
- [ ] Allow force pushes (keep disabled)
- [ ] Allow deletions (keep disabled)

### Step 3: Configure Staging Branch Protection

**Branch name pattern**: `staging`

**Settings:**
- [x] Require status checks to pass before merging
- [x] Require branches to be up to date before merging
- Required status checks: `Security & Secrets Validation`, `Code Quality Checks`, `Test Coverage`
- [x] Require a pull request before merging
- [x] Require approvals: **1**
- [x] Dismiss stale pull request approvals when new commits are pushed
- [ ] Allow force pushes (keep disabled)

### Step 4: Configure Development Branch Protection

**Branch name pattern**: `dev`

**Settings:**
- [x] Require status checks to pass before merging
- [x] Require branches to be up to date before merging
- Required status checks: `Security & Secrets Validation`, `Code Quality Checks`
- [x] Require a pull request before merging
- [x] Require approvals: **1**
- [x] Allow force pushes (for development flexibility)

### Step 5: Create CODEOWNERS File

Create `.github/CODEOWNERS` file in your repository:

```
# Global code owners
* @BishalBudhathoki

# Deployment and infrastructure
/.github/workflows/ @BishalBudhathoki
/scripts/ @BishalBudhathoki
/Dockerfile @BishalBudhathoki
/firebase.json @BishalBudhathoki

# Security-sensitive files
/.env.example @BishalBudhathoki
/.gitignore @BishalBudhathoki
/credentials/ @BishalBudhathoki

# Backend API
/api_server.py @BishalBudhathoki
/routers/ @BishalBudhathoki
/services/ @BishalBudhathoki

# Frontend core
/frontend/flutter_neuropilot/lib/core/ @BishalBudhathoki
/frontend/flutter_neuropilot/lib/services/ @BishalBudhathoki
/frontend/flutter_neuropilot/lib/state/ @BishalBudhathoki
```

## 🧪 Testing Branch Protection

### Test the Protection Rules

1. **Create a test branch:**
   ```bash
   git checkout -b test-branch-protection
   echo "test" > test-file.txt
   git add test-file.txt
   git commit -m "test: branch protection"
   git push origin test-branch-protection
   ```

2. **Create a Pull Request:**
   - Go to GitHub and create a PR from `test-branch-protection` to `main`
   - Verify that status checks are required
   - Verify that reviews are required

3. **Test Status Checks:**
   - The branch protection workflow should run automatically
   - Check that security scans pass
   - Verify code quality checks run

## 📋 Verification Checklist

After setting up branch protection, verify:

- [ ] Cannot push directly to `main` branch
- [ ] Cannot push directly to `staging` branch  
- [ ] Pull requests require status checks to pass
- [ ] Pull requests require the specified number of reviews
- [ ] Code owners are automatically requested for review
- [ ] Status checks run on every PR
- [ ] Security scans block PRs with issues
- [ ] Force pushes are blocked (except on `dev`)

## 🔧 Troubleshooting

### Status Checks Not Appearing
- Status checks only appear after the first workflow run
- Push a commit to trigger the workflows
- Check `.github/workflows/` files are properly configured

### Reviews Not Required
- Ensure CODEOWNERS file is in `.github/CODEOWNERS`
- Check that "Require review from code owners" is enabled
- Verify the GitHub username in CODEOWNERS is correct

### Workflows Not Running
- Check workflow files have correct syntax
- Verify GitHub Actions are enabled for the repository
- Check that secrets and variables are configured

## 🎯 Next Steps

After setting up branch protection:

1. **Test the workflow** by creating a test PR
2. **Configure GitHub secrets** for deployment
3. **Set up environment-specific branches** (`dev`, `staging`)
4. **Train team members** on the new workflow
5. **Monitor security alerts** and workflow runs

## 📞 Need Help?

If you encounter issues:
- Check the [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- Review workflow logs in GitHub Actions
- Check repository settings and permissions