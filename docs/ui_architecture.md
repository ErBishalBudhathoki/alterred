# UI/UX Architecture (Flutter Mobile‑First)

## Technology Selection
- Primary: Flutter (mobile) with Riverpod for state; optional Flutter Web for unified UI; optional Next.js for SSR/SEO if required.

## Architecture
- Feature modules: TaskFlow, Time, Energy/Sensory, Decision, External Brain
- Core: Theme tokens, routes, API client, auth stub, i18n hooks
- Responsive: LayoutBuilder + adaptive nav; breakpoints for grid/list

## State Management
- Riverpod providers: `apiClientProvider`, `tokenProvider`, feature stores

## Secure Communication
- HTTPS; `Authorization: Bearer` support; token in secure storage on devices

## Accessibility
- High contrast themes, semantics labels, large text scaling; keyboard focus order for web

## Internationalization
- Placeholder hooks; enable `intl` and ARB files in later phase

## Documentation & Testing
- Widget structure documented; golden tests and integration tests planned