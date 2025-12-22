// Timezone utility entry point
//
// Uses conditional imports to obtain the client IANA timezone on web
// via `timezone_web.dart`, and falls back to safe stubs on mobile/IO.
//
// Returns: IANA timezone name (e.g., `Australia/Sydney`) or `UTC` fallback.
// Side effects: None.
// Conditional import to obtain IANA timezone on web; fallback elsewhere
import 'timezone_stub.dart'
    if (dart.library.html) 'timezone_web.dart'
    if (dart.library.io) 'timezone_mobile.dart';

/// Returns client IANA timezone name or `UTC` when unavailable.
String clientIanaTimezone() => getClientIanaTimezone();
