import 'link_opener.dart';

/// Stub implementation of [LinkOpener].
///
/// This implementation is used on platforms where link opening is not supported
/// or when conditional imports fall back to this stub.
///
/// Implementation Details:
/// - [open] is a no-op returning `false`.
///
/// Design Decisions:
/// - Provides a safe fallback to prevent crashes.
///
/// Behavioral Specifications:
/// - [open]: Always returns `false`.
class _StubLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async => false;
}

/// Factory function to create the stub link opener.
LinkOpener createLinkOpenerImpl() => _StubLinkOpener();