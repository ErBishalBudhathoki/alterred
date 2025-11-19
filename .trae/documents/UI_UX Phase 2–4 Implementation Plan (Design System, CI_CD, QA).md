## Design System
- Create tokens JSON (colors, typography, spacing, radii, elevations) and generate `tokens.dart` used by `NeuroPilotTheme`.
- Integrate Widgetbook: add dev dependency, create `widgetbook.dart`, document components (buttons, inputs, tiles) with accessibility notes and variants.
- Add ARB files and `intl` scaffolding for i18n; locale switcher; RTL support hooks.

## State & Security
- Riverpod feature stores with typed models and error handling; retry/backoff on API calls.
- Secure token storage (Keychain/Keystore) and interceptor injecting `Authorization` in `ApiClient`.
- Deep links and guarded routes; responsive wrappers for tablet/desktop.

## CI/CD
- GitHub Actions:
  - `mobile.yml`: `flutter analyze`, unit/golden/integration tests, build (debug/release), artifact upload; Fastlane stubs for signing.
  - `backend.yml`: Python lint/tests, docker build/push, Cloud Run deploy on main.
  - `frontend-web.yml` (optional): Flutter Web build (or Next.js if added), deploy to Cloud Run/Vercel.
- Env configs: dev/staging/prod base URLs; feature flags; secrets via GitHub Actions.

## QA & Monitoring
- Automated UI tests:
  - Golden tests for core widgets; `integration_test` for flows (TaskFlow atomize, countdown creation, decision reduce).
- Cross-device/browser matrix docs and scripts (Firebase Test Lab/BrowserStack, Chrome/Firefox/Safari/Edge).
- Performance monitoring setup: Crashlytics, Firebase Performance; Web Vitals (if web channel used).
- UX review cadence: heuristic checklist, a11y audits, usability sessions; telemetry events.

## Docs
- Add `docs/design_system.md` (tokens, components, guidelines), `docs/ci_cd.md` (workflows, environments), `docs/testing_strategy.md` (matrix, golden/integration tests), `docs/accessibility.md` and `docs/i18n.md`.

## Deliverables
- Tokens JSON + `tokens.dart`; Widgetbook catalog; ARB i18n files.
- CI/CD workflows; environment configs; Fastlane stubs.
- Automated UI tests and testing strategy documentation.

## Sequence
1) Tokens + `tokens.dart` + Widgetbook + ARB scaffolding
2) Riverpod stores and secure token handling, responsive wrappers
3) GitHub Actions workflows and environment setup
4) Automated UI tests; device/browser matrix; monitoring hooks
5) Docs added/updated for each step