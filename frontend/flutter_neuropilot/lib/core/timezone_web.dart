// Web timezone utility
//
// Attempts to read the browser's IANA timezone via
// `Intl.DateTimeFormat().resolvedOptions().timeZone`.
// Returns `UTC` when unavailable or on error.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Returns IANA timezone name or `UTC` fallback on web.
String getClientIanaTimezone() {
  try {
    final hasIntl = globalContext.hasProperty('Intl'.toJS).toDart;
    if (!hasIntl) return 'UTC';
    final intl = globalContext.getProperty<JSObject>('Intl'.toJS);
    final hasCtor = intl.hasProperty('DateTimeFormat'.toJS).toDart;
    if (!hasCtor) return 'UTC';
    final dfCtor = intl.getProperty<JSFunction>('DateTimeFormat'.toJS);
    final df = dfCtor.callAsConstructorVarArgs<JSObject>();
    final ro = df.callMethod('resolvedOptions'.toJS) as JSObject;
    final tzAny = ro.getProperty<JSAny>('timeZone'.toJS);
    final tz = tzAny.dartify()?.toString();
    if (tz != null && tz.isNotEmpty) return tz;
    return 'UTC';
  } catch (_) {
    return 'UTC';
  }
}
