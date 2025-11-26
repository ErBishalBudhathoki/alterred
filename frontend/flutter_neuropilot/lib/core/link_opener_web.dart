import 'package:web/web.dart' as web;
import 'link_opener.dart';

/// Web implementation of [LinkOpener].
///
/// Implementation Details:
/// - Uses `package:web` to interact with the browser's `window` object.
/// - Handles both relative and absolute URLs.
///
/// Design Decisions:
/// - Direct DOM manipulation via `package:web` is standard for Flutter Web interop.
/// - Opens links in a new tab (`_blank`) to preserve the app state.
///
/// Behavioral Specifications:
/// - [open]: Resolves relative paths against the current origin. Opens the target URL in a new tab. Always returns `true`.
class _WebLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    final base = web.window.location;
    final isRelative = url.startsWith('/#/');
    final target = isRelative
        ? '${base.origin}$url'
        : url;
    web.window.open(target, '_blank');
    return true;
  }
}

/// Factory function to create the web link opener.
LinkOpener createLinkOpenerImpl() => _WebLinkOpener();