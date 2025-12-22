/// Mobile fallback for IANA timezone detection.
/// Returns `UTC` to avoid invalid names when JS Intl is unavailable.
String getClientIanaTimezone() {
  try {
    // Mobile builds do not have JS Intl; use safe fallback
    return 'UTC';
  } catch (_) {
    return 'UTC';
  }
}
