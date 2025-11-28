# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Auth Logging**: Added comprehensive `debugPrint` logging to `AuthService` for all authentication actions.
- **Deployment Documentation**: Comprehensive guide for Firebase/GCP Cloud Run deployment in `README.md`.
- **GitHub Actions**: Automated CI/CD workflow (`.github/workflows/deploy.yml`) for backend and frontend.
- **Deployment Scripts**: `scripts/deploy_backend.sh` and `scripts/deploy_frontend.sh` for streamlined operations.
- **Error Handling**: Enhanced login and signup flows to handle `FirebaseAuthException` and provide specific user feedback.

### Changed
- **Signup Error Message**: Standardized "email-already-in-use" error message to "Email is already used".
- **Password Reset**: Updated `AuthController` and `LoginScreen` to propagate and handle password reset exceptions properly.
- **NetworkImage Usage**: Replaced `NetworkImage` with `NpAvatar` in `SettingsScreen` to fix 429 errors and improve loading state.
- **NpAvatar**: Updated `NpAvatar` to use `Image.network` with an `errorBuilder` for graceful fallback.
- **AuthController**: Updated `signInEmail` and `signUpEmail` to propagate exceptions for UI handling instead of returning booleans.
- **README.md**: Reorganized into clear Development and Deployment sections.

### Fixed
- **Duplicate Email**: Fixed issue where users wouldn't get a clear error when signing up with an existing email.
- **Password Reset Failures**: Resolved silent failures in password reset flow by propagating exceptions.
- **Login Errors**: Resolved silent failures in login/signup by catching and displaying Firebase exceptions (e.g., user-not-found, wrong-password).
- **NetworkImage 429**: Fixed 429 errors when loading Google profile images by using a robust avatar component with fallback.
- **Development Scripts**: Updated `scripts/run_local.sh` and `scripts/android_dev_run.sh` usage in documentation.
