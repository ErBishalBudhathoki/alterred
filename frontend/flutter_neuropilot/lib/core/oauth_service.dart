import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

/// Service for handling OAuth flows with deep linking support.
///
/// Manages the initiation of OAuth flows via external browsers and listens for
/// callback redirects via deep links (on mobile).
///
/// Implementation Details:
/// - Uses `url_launcher` to open the authorization URL.
/// - Uses `app_links` to listen for deep link callbacks on mobile.
/// - Web handling is typically done via standard URL redirects, so deep link listeners are skipped on web.
///
/// Design Decisions:
/// - Separated deep link logic from the main UI code to keep `main.dart` or screens clean.
/// - [initialize] accepts a callback to decouple the service from specific state management solutions.
///
/// Behavioral Specifications:
/// - [initialize]: Sets up deep link listeners if running on mobile.
/// - [startOAuthFlow]: Launches the provided URL in an external application (mobile) or default mode (web).
/// - [dispose]: Cancels any active stream subscriptions to prevent memory leaks.
class OAuthService {
  StreamSubscription? _linkSubscription;
  Function(Uri)? _onCallbackReceived;
  late AppLinks _appLinks;

  /// Initialize OAuth service and listen for deep links (mobile only).
  ///
  /// [onCallback] is invoked whenever a deep link is received.
  void initialize({Function(Uri)? onCallback}) {
    _onCallbackReceived = onCallback;

    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinkListener();
    }
  }

  /// Initialize deep link listener for mobile.
  ///
  /// Listens for both the initial link (if app launched via link) and subsequent links
  /// (if app was already running).
  void _initDeepLinkListener() {
    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (_onCallbackReceived != null) {
        _onCallbackReceived!(uri);
      }
    }, onError: (err) {
      // Handle errors
      debugPrint('Deep link error: $err');
    });

    // Handle initial link when app starts from a deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && _onCallbackReceived != null) {
        _onCallbackReceived!(uri);
      }
    });
  }

  /// Start OAuth flow by opening authorization URL.
  ///
  /// Returns `true` if the URL was successfully launched, `false` otherwise.
  Future<bool> startOAuthFlow(String authorizationUrl) async {
    final uri = Uri.parse(authorizationUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } else {
      return false;
    }
  }

  /// Handle OAuth callback (for web).
  ///
  /// Returns authorization code if present in the [callbackUri] query parameters.
  String? handleWebCallback(Uri callbackUri) {
    return callbackUri.queryParameters['code'];
  }

  /// Extract state from callback URL.
  ///
  /// Used to verify the integrity of the OAuth flow.
  String? extractState(Uri callbackUri) {
    return callbackUri.queryParameters['state'];
  }

  /// Extract error from callback URL.
  ///
  /// Returns the error message if the OAuth flow failed.
  String? extractError(Uri callbackUri) {
    return callbackUri.queryParameters['error'];
  }

  /// Dispose and clean up.
  ///
  /// Cancels the deep link subscription and clears callbacks.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _onCallbackReceived = null;
  }
}
