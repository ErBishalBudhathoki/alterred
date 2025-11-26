import 'link_opener.dart';

/// Mobile implementation of [LinkOpener].
///
/// Implementation Details:
/// - Currently a placeholder returning `false`.
/// - Requires a package like `url_launcher` for actual implementation on Android/iOS.
///
/// Design Decisions:
/// - Separated to allow adding mobile-specific launching logic later without affecting web/stub.
///
/// Behavioral Specifications:
/// - [open]: Always returns `false` in this placeholder implementation.
class _MobileLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    // TODO: Implement using url_launcher or similar package.
    return false;
  }
}

/// Factory function to create the mobile link opener.
LinkOpener createLinkOpenerImpl() => _MobileLinkOpener();