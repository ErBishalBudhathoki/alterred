import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

/// Service for handling OAuth flows with deep linking support
class OAuthService {
  StreamSubscription? _linkSubscription;
  Function(Uri)? _onCallbackReceived;
  late AppLinks _appLinks;

  /// Initialize OAuth service and listen for deep links (mobile only)
  void initialize({Function(Uri)? onCallback}) {
    _onCallbackReceived = onCallback;
    
    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinkListener();
    }
  }

  /// Initialize deep link listener for mobile
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

  /// Start OAuth flow by opening authorization URL
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

  /// Handle OAuth callback (for web)
  /// Returns authorization code if present
  String? handleWebCallback(Uri callbackUri) {
    return callbackUri.queryParameters['code'];
  }

  /// Extract state from callback URL
  String? extractState(Uri callbackUri) {
    return callbackUri.queryParameters['state'];
  }

  /// Extract error from callback URL
  String? extractError(Uri callbackUri) {
    return callbackUri.queryParameters['error'];
  }

  /// Dispose and clean up
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _onCallbackReceived = null;
  }
}
