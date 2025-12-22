# Git Tracking Guide

This document explains what files and directories should be tracked in version control and what should be ignored.

## ✅ Files That SHOULD Be Tracked

### Core Application Code
- `*.py` - Python source files (agents, services, routers, etc.)
- `*.dart` - Flutter/Dart source files
- `*.ts`, `*.js` - TypeScript/JavaScript files
- `*.yaml`, `*.yml` - Configuration files (except sensitive ones)
- `*.json` - Package and configuration files (except sensitive ones)

### Documentation
- `README.md` - Main project documentation
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history
- `CODE_OF_CONDUCT.md` - Community guidelines
- `docs/` - All documentation in the docs directory
- `APP_DATA_FLOW_DOCUMENTATION.md` - Application data flow

### Configuration
- `.env.example` - Example environment variables (NO SECRETS)
- `requirements.txt` - Python dependencies
- `pubspec.yaml` - Flutter dependencies
- `package.json` - Node.js dependencies
- `Dockerfile` - Container configuration
- `firebase.json` - Firebase configuration

### CI/CD & Workflows
- `.github/workflows/` - GitHub Actions workflows
- `scripts/` - Deployment and utility scripts (except local dev scripts)

### Project Structure
- `agents/` - AI agent implementations
- `services/` - Backend services
- `routers/` - API routers
- `orchestration/` - Orchestration logic
- `frontend/flutter_neuropilot/lib/` - Flutter source code
- `tests/` - Test files

## ❌ Files That Should NOT Be Tracked

### Environment & Secrets
- `.env` - Environment variables with secrets
- `.env.local`, `.env.*.local` - Local environment files
- `credentials/` - Any credentials directory
- `*.pem`, `*.key`, `*.p12` - Private keys
- `firebase-service-account.json` - Service account keys
- `google-services.json` - Firebase config with secrets

### Build Artifacts
- `build/`, `dist/` - Build output directories
- `__pycache__/` - Python bytecode cache
- `*.pyc`, `*.pyo`, `*.pyd` - Python compiled files
- `.dart_tool/` - Dart tool cache
- `node_modules/` - Node.js dependencies
- `.flutter-plugins*` - Flutter plugin cache

### IDE & Editor Files
- `.idea/` - IntelliJ IDEA files
- `.vscode/settings.json` - VS Code settings (user-specific)
- `*.swp`, `*.swo` - Vim swap files
- `.DS_Store` - macOS Finder metadata

### Test & Coverage
- `test-results/` - Test result files
- `coverage/` - Coverage reports
- `.pytest_cache/` - Pytest cache
- `.nyc_output/` - NYC coverage cache

### Cache Directories
- `.cache/` - General cache
- `.hypothesis/` - Hypothesis testing cache
- `.kiro/` - Kiro AI cache
- `.trae/` - Trae cache
- `.ruff_cache/` - Ruff linter cache
- `.mypy_cache/` - MyPy type checker cache

### Development Tools Config
- `.pre-commit-config.yaml` - Pre-commit hooks (user-specific)
- `.ruff.toml` - Ruff configuration (user-specific)
- `mypy.ini` - MyPy configuration (user-specific)
- `pytest.ini` - Pytest configuration (user-specific)

### Large Binary Files
- `voice_models/` - Voice model files (too large)
- `fonts/` - Font files (should be downloaded)
- `bin/` - Binary executables
- `backend/` - Backend binaries

### Temporary Documentation
- `*_COMPLETION_REPORT.md` - Temporary completion reports
- `*_IMPLEMENTATION.md` - Temporary implementation docs
- `ADHD_User_Guide.md` - Temporary user guide
- `REALTIME_VOICE_MODE.md` - Temporary feature docs
- `VOICE_SETUP.md` - Temporary setup docs
- `ORCHESTRATION_*.md` - Temporary orchestration docs
- `neuropilot_quickstart.md` - Temporary quickstart
- `neuropilot_tech_stack.md` - Temporary tech stack
- `task.md`, `issues.md` - Temporary task tracking

### UI Development
- `UI2WORK/` - UI work-in-progress directory

## 🔍 How to Check What's Tracked

### View all tracked files
```bash
git ls-files
```

### View untracked files
```bash
git status --porcelain | grep "^??"
```

### View ignored files
```bash
git status --ignored
```

### Check if a specific file is tracked
```bash
git ls-files | grep "filename"
```

## 🧹 Cleaning Up Tracked Files

### Remove file from tracking (keep local copy)
```bash
git rm --cached <file>
```

### Remove directory from tracking (keep local copy)
```bash
git rm -r --cached <directory>
```

### Remove file from tracking and delete
```bash
git rm <file>
```

## 📝 Best Practices

1. **Never commit secrets**: Always use environment variables or secret management
2. **Keep .gitignore updated**: Add new patterns as needed
3. **Review before committing**: Use `git status` and `git diff` before committing
4. **Use .env.example**: Provide example environment variables without secrets
5. **Document configuration**: Explain what environment variables are needed
6. **Separate concerns**: Keep development files separate from production code
7. **Use branch protection**: Require reviews and checks before merging

## 🚨 If You Accidentally Commit Secrets

1. **Immediately rotate the secret**: Change the password/key/token
2. **Remove from history**: Use `git filter-branch` or BFG Repo-Cleaner
3. **Force push**: `git push --force` (coordinate with team)
4. **Notify team**: Alert team members about the incident
5. **Review security**: Check if the secret was accessed

### Quick fix for recent commit
```bash
# Remove file from last commit
git rm --cached <file-with-secret>
git commit --amend --no-edit

# Force push (be careful!)
git push --force
```

## 📚 Additional Resources

- [Git Documentation](https://git-scm.com/doc)
- [GitHub .gitignore Templates](https://github.com/github/gitignore)
- [Security Best Practices](../docs/SECURITY.md)
- [Contributing Guidelines](../CONTRIBUTING.md)