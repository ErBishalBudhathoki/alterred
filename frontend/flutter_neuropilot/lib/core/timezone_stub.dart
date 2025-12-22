/// Stub fallback for non-web builds.
/// Returns `UTC` to keep header values valid when IANA lookup is not possible.
String getClientIanaTimezone() {
  try {
    // Fallback for non-web: return UTC to avoid invalid names
    return 'UTC';
  } catch (_) {
    return 'UTC';
  }
}
