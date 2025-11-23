# Mobile Connectivity & Exceptions – Implementation Notes

## Overview

- Scope: Android emulator connectivity to backend and elimination of app runtime exceptions; consistent behavior on web and Android.
- Results: Stable builds; reliable health checks and chat requests; visible error feedback; resilient client timeouts; no assertion crash at startup.

## Changes

- Android flavor support
  - Added `development` flavor to match run command.
  - Path: `frontend/flutter_neuropilot/android/app/build.gradle.kts:41–48`.

- Speech plugin and web dependency updates
  - Upgraded `speech_to_text` to `7.3.0`.
  - Bumped `web` to `^1.1.1` to satisfy transitive requirements.
  - Path: `frontend/flutter_neuropilot/pubspec.yaml`.
  - Mobile speech uses `SpeechListenOptions`.
  - Path: `frontend/flutter_neuropilot/lib/core/speech_service_mobile.dart:81–89`.

- Startup assertion fix
  - Deferred `SchedulerBinding.instance.currentFrameTimeStamp` usage to post-frame.
  - Path: `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:1068–1072`.

- API client resiliency
  - Added `_send(...)` wrapper with 10s timeout and debug logging; routed all requests through it.
  - Path: `frontend/flutter_neuropilot/lib/services/api_client.dart:140–150` (function), with call sites updated across file (e.g., `14–17`, `103–127`).

- UI error feedback
  - Orchestrator network failure shows warning snackbar.
  - Path: `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:770–779`.
  - Snackbars for JIT and proactive check-ins errors.
  - Paths: `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:482–484`, `579–582`.

## Terminal Logs – Analysis

- Terminal#122–132 (Uvicorn):
  - `GET /health` returned `200 OK` repeatedly; backend healthy and listening on `0.0.0.0:8000`.

- Terminal#3–139 (Gradle build):
  - Error: `Task 'assembleDevelopmentDebug' not found`.
  - Cause: Android flavors not defined while invoking `--flavor development`.
  - Fix: Added `development` flavor in `build.gradle.kts:41–48`.

- Terminal#196–302 (runtime):
  - Assertion: `'SchedulerBinding.currentFrameTimeStamp != null'` in `initState`.
  - Cause: Accessing frame timestamp before first frame.
  - Fix: Compute epoch base inside `addPostFrameCallback`.
  - Connectivity: `Connection refused` for `http://localhost:8000/chat/respond`.
  - Cause: Emulator’s `localhost` is not host; backend runs on host.
  - Fix: `adb reverse tcp:8000 tcp:8000` to route emulator `localhost:8000` to host.

## Implementation Details

- Android networking
  - Preserve `API_BASE_URL=localhost:8000` per project rules.
  - Use `adb reverse` instead of changing endpoints.

- Error handling
  - Centralized timeouts and error logging in `ApiClient`.
  - User-visible snackbars for orchestration/JIT/proactive flows.

- Compatibility
  - Web and Android share `ApiClient` logic; web-specific interop continues to use `package:web`.
  - No endpoint format changes; token handling is unchanged.

## Verification

- Backend
  - Confirm via `GET /health` shows `200 OK`.

- Android
  - Set port routing: `adb reverse tcp:8000 tcp:8000`.
  - Run: `flutter run -d "emulator-5554" --flavor development`.
  - Observe health pings succeed and chat requests no longer `ECONNREFUSED`.

- Web
  - Run the same flows; network timeouts produce UI feedback and logs.

## Environments

- Development
  - Use `localhost:8000` with `adb reverse` for emulators.

- Staging / Production
  - Provide `API_BASE_URL` via build/run configuration (e.g., `--dart-define API_BASE_URL=https://api.example.com`).
  - No code changes required.

## Monitoring & Observability

- Client-side
  - Timeouts and network errors logged via `debugPrint` in `ApiClient._send`.
  - Heartbeat health checks reflect connectivity in UI.

- Server-side
  - Uvicorn logs (`GET /health`) confirm liveness and connectivity.

## Checklist of Fixes

- Android flavor added (`development`) – build succeeds with provided command.
- Startup assertion resolved – epoch base set after first frame.
- Network resiliency – request timeouts, structured error handling, snackbars.
- Speech plugin updated – `SpeechListenOptions` and dependency alignment.
- Emulator connectivity – preserved endpoints; routed ports via `adb reverse`.

## References

- `frontend/flutter_neuropilot/android/app/build.gradle.kts:41–48`
- `frontend/flutter_neuropilot/pubspec.yaml`
- `frontend/flutter_neuropilot/lib/core/speech_service_mobile.dart:81–89`
- `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:1068–1072`
- `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:770–779`
- `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:482–484`
- `frontend/flutter_neuropilot/lib/screens/chat_screen.dart:579–582`
- `frontend/flutter_neuropilot/lib/services/api_client.dart:140–150`
