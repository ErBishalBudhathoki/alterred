## Current State Summary
- Design tokens exist in `lib/core/design_tokens.dart` (colors, spacing, radii, typography, elevation).
- Theme configured with Material 3 in `lib/core/theme.dart` and applied in `lib/main.dart`.
- Implemented components: `NpButton`, `NpCard`, `NpTextField` in `lib/core/components/`.
- Localization wired (`en`, `hi`), with locale switching persisted; delegates set in `lib/main.dart`.
- Accessibility: no `Semantics`/focus traversal usage detected.
- Widgetbook/catalog: not present.
- Tests and CI/CD: no test files or workflows present.

Key references:
- `lib/core/theme.dart:5-14`, `lib/core/theme.dart:16-22`
- `lib/core/design_tokens.dart:4-25`
- `lib/core/components/np_button.dart:4-12`, `lib/core/components/np_card.dart:11-22`, `lib/core/components/np_text_field.dart:12-25`
- `lib/main.dart:20-34`, `lib/screens/home_screen.dart:13-31`

## Component Gaps
- Missing UI primitives commonly needed per design system guidelines:
  - App bar wrapper, list tile, divider
  - Dialog, snackbar/toast wrappers, bottom sheet
  - Chips and badges (status/quantity)
  - Avatar
  - Progress indicators (linear/circular)
  - Form controls: switch, checkbox, radio
  - Tabs/segmented control
  - Loading/disabled states for buttons

## Implementation Plan
### Phase 1: Core Primitives
- Create token-aware wrappers under `lib/core/components/`:
  - `np_app_bar.dart`: title style, actions spacing, elevation/radius from tokens
  - `np_list_tile.dart`: consistent spacing, typography, tap states
  - `np_divider.dart`: thickness/color from tokens
  - `np_progress.dart`: linear/circular, success/warning/error variants
  - `np_avatar.dart`: circle avatar with initials, token radii

### Phase 2: Feedback & Overlays
- `np_dialog.dart`: confirm/info dialogs with primary/secondary button styles
- `np_snackbar.dart`: success/warning/error styles; a11y `Semantics(liveRegion: true)`
- `np_bottom_sheet.dart`: token spacing, rounded corners, drag handle

### Phase 3: Selection & Chips
- `np_chip.dart`: filter/input/selectable chips, success/warning/error styles
- `np_badge.dart`: number/status badges; attachable to icons/buttons
- Tabs/segmented control: `np_tabs.dart` using `TabBar` with token colors and radii

### Phase 4: Form Controls & Button States
- `np_switch.dart`, `np_checkbox.dart`, `np_radio.dart`: token colors and focus outlines
- Extend `NpButton` to include `disabled` and `loading` states (spinner + semantics)

## Accessibility
- Add `Semantics` wrappers with labels/roles to interactive components (cards, buttons, chips, list tiles, dialogs).
- Ensure focus order using `FocusTraversalGroup` where grouped controls exist.
- Respect scalable text by avoiding hard-coded sizes beyond theme; prefer `Theme.of(context).textTheme`.
- Contrast: use `onPrimary`/`onSurface` tokens; add simple pre-checks for custom combinations.

## Internationalization
- All new components accept externalized strings; use `AppLocalizations` in screens only.
- RTL readiness: avoid directional assumptions; rely on Flutter `Directionality`; verify with simulated RTL locale.

## Integration
- Follow existing patterns: stateless wrappers, Material components, tokens from `DesignTokens`.
- No new state management; integrate into existing screens minimally and non-invasively.
- Navigation wiring via `core/routes.dart` when components introduce new flows (e.g., bottom sheets/dialog demos).

## Testing
- Unit/UI: add golden tests for components (buttons, chips, dialogs, list tiles) and interaction tests for semantics and focus.
- Integration: simple flow tests for settings and home grid navigation using `flutter_test`.
- Device matrix: validate on Android emulator; plan iOS simulator runs.

## CI/CD
- Add GitHub Actions for `flutter analyze`, tests, and build artifacts for development flavor.
- Retain existing environment base URL and token handling; no IP/host changes.

## Deliverables
- New components in `lib/core/components/*` with token-consistent styles and accessibility.
- Screen updates to adopt components where appropriate.
- Tests for new components and basic navigation.
- CI workflow files for analyze/test/build.
- Notes documenting any deviations (e.g., tokens remain in Dart instead of JSON) with rationale.

## Assumptions & Decisions
- Tokens remain in Dart for now; JSON migration can be scoped later if desired.
- Widgetbook not integrated; a gallery route can serve as internal catalog initially.
- No web work; mobile-only validation on Android/iOS simulators.

Please confirm this plan. Once approved, I will implement, validate on emulator `emulator-5554` with `--flavor development`, add tests, and prepare the CI workflow.