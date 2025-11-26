import 'link_opener_stub.dart'
    if (dart.library.html) 'link_opener_web.dart'
    if (dart.library.io) 'link_opener_mobile.dart';

/// Service interface for opening URLs.
///
/// Defines the contract for opening external links or internal routes in a new context.
///
/// Implementation Details:
/// - Uses conditional imports to select the platform-specific implementation.
///
/// Design Decisions:
/// - Abstracted to handle platform differences (e.g., `package:web` vs `url_launcher` or native intent).
/// - Returns a [Future<bool>] to indicate success/failure.
///
/// Behavioral Specifications:
/// - [open]: Attempts to open the given [url]. Returns `true` if successful, `false` otherwise.
abstract class LinkOpener {
  /// Opens the specified [url].
  ///
  /// Returns `true` if the URL was launched successfully, `false` otherwise.
  Future<bool> open(String url);
}

/// Factory function to create the platform-specific [LinkOpener].
LinkOpener createLinkOpener() => createLinkOpenerImpl();