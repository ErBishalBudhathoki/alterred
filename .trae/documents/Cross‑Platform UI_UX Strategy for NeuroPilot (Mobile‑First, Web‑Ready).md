## Technology Selection
- Mobile‑First Frameworks (primary):
  1) Flutter
  - Pros: Single codebase for iOS/Android; strong performance; rich widget ecosystem; excellent dev tooling; maturing Flutter Web; easy theming;
  - Cons: Web SEO and accessibility require extra care; some enterprise web patterns more mature in React.
  2) React Native
  - Pros: JavaScript ecosystem; reuse logic with React Web; good community; many UI libs
  - Cons: Performance/complex UI can require native modules; platform divergence risk.
- Web Frameworks (complementary):
  1) Flutter Web (same codebase as mobile)
  - Pros: Maximal reuse; consistent UI/UX; shared design system
  - Cons: Larger bundles; SEO/accessibility require attention.
  2) React (Next.js)
  - Pros: Best‑in‑class web tooling; SSR/SEO; robust a11y patterns; huge ecosystem
  - Cons: Separate codebases; need shared design tokens/components.
- Recommendation: Mobile‑first with Flutter (Riverpod/Bloc for state); enable Flutter Web for a unified architecture; if web requires SSR/SEO or complex integrations, add a React (Next.js) frontend that shares a design system and TypeScript API SDK with Flutter.

## Architecture Design
- Clean architecture with feature modules:
  - Core: UI design system (tokens, themes), networking client, auth, analytics, i18n
  - Features: TaskFlow, Time Perception, Energy/Sensory, Decision Support, External Brain, Settings
- Responsive design:
  - Flutter: LayoutBuilder/MediaQuery + breakpoints; adaptive navigation (bottom tabs → side nav on wide screens)
  - Web (Flutter Web or React): CSS breakpoints or responsive wrappers; keyboard nav and focus management
- Shared design system:
  - Central tokens (color, typography, spacing), components library, motion patterns, accessibility rules

## Implementation Requirements
- Component‑based architecture:
  - Flutter: reusable widgets per feature; atomic/molecule/organism hierarchy
  - React (optional): functional components + Storybook; design tokens via CSS variables or Theme UI
- State management:
  - Flutter: Riverpod (or Bloc) + immutable models; feature stores; side effects encapsulated
  - Web: TanStack Query/RTK Query for API caching + global store (Redux or Zustand)
- Secure communication:
  - HTTPS only; Bearer JWT via Firebase Auth; refresh token handling; secure storage (Keychain/Keystore)
  - Align to backend: FastAPI endpoints; Authorization header validated server‑side
- Accessibility:
  - Flutter: semantics labels, large text scaling, high contrast themes
  - Web: WCAG 2.1 AA; semantic HTML; aria attributes; keyboard/focus order; color contrast
- Internationalization:
  - Flutter: `flutter_intl` or `intl` with ARB files; locale switching; RTL support
  - Web: i18next/FormatJS; lazy‑loaded locales; dynamic direction

## Development Process
- Version control strategy:
  - Trunk‑based with short‑lived feature branches; PRs with code + docs + tests; feature flags for risky features
- CI/CD:
  - GitHub Actions:
    - Mobile: flutter test, integration tests, build pipelines; Fastlane for signing; deploy to TestFlight/Play Console
    - Web: lint, unit/integration tests (Playwright/Cypress), build and deploy to Cloud Run/Vercel
  - Environments: development/staging/production; separate API base URLs via env configs
- Design system guidelines:
  - Figma library → exported tokens (JSON); align component anatomy; accessibility checklists
- Documentation:
  - Architecture overview; component docs (Storybook/Widgetbook); API client docs; i18n/a11y guidelines; testing and deployment playbooks

## Quality Assurance
- Cross‑browser/device testing:
  - Browsers: Chrome/Firefox/Safari/Edge; Devices: iOS/Android (simulators + Firebase Test Lab/BrowserStack)
- Performance monitoring:
  - Sentry/Crashlytics; Firebase Performance; Web Vitals (web)
- UX review process:
  - Heuristic reviews; usability tests; accessibility audits; analytics‑driven iteration
- Automated UI testing:
  - Flutter: golden tests; integration tests (flutter_driver/integration_test)
  - Web: Playwright/Cypress; snapshot testing with Storybook

## Rollout Phases
1) Foundation: Flutter app scaffolding; design tokens; API SDK; auth; routing; baseline screens for TaskFlow/Time/Decision
2) Web channel: Flutter Web build; or Next.js app with shared design tokens + TS SDK
3) Observability: integrate Sentry/Crashlytics/Performance; dashboards; alerts
4) QA hardening: a11y audits; i18n; performance budgets; device matrix
5) CI/CD + docs: pipelines; automated tests; component docs complete

## Notes
- Mobile‑first priority maintained; web is a complementary channel
- Backend compatibility: FastAPI endpoints already defined; Authorization header supported; secure token storage required on clients
- Long‑term maintainability: shared design system + API SDK; modular features; comprehensive CI/CD