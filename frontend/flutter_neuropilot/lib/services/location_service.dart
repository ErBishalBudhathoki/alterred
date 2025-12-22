import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Service to handle location permissions and retrieval.
///
/// This service is responsible for:
/// 1. Checking and requesting location permissions.
/// 2. Getting the current position.
/// 3. Reverse geocoding to determine the country code (ISO 3166-1 alpha-2).
///
/// It prioritizes GPS/device location but gracefully handles failures by returning null
/// (allowing the app to fall back to locale or IP-based detection).
class LocationService {
  /// Determines the current country code.
  ///
  /// Returns the ISO 3166-1 alpha-2 country code (e.g., 'US', 'AU') if successful.
  /// Returns null if permission denied, service disabled, or geocoding fails.
  Future<String?> getCurrentCountryCode() async {
    try {
      // 1. Check if location services are enabled.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      // 2. Check and request permissions.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'Location permissions are permanently denied, we cannot request permissions.');
        return null;
      }

      // 3. Get current position.
      // High accuracy might take longer, using balanced for country detection is enough.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // City/Country level is fine
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 4. Reverse geocode to get country code.
      // We pass localeIdentifier to ensure we get results in English/System locale if needed,
      // but ISO code is standard.
      try {
        if (kIsWeb) {
          // Geocoding on web requires Google Maps API key which might not be configured.
          // Return null to fall back to IP geolocation.
          return null;
        }

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final code = placemarks.first.isoCountryCode;
          if (code != null) {
            debugPrint('Detected country code from location: $code');
            return code;
          }
        }
      } catch (e) {
        debugPrint('Geocoding failed: $e');
        // Fallback to coordinates-based API if needed, but for now return null
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return null;
  }

  /// Checks if the app has location permission and service enabled.
  Future<bool> hasPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  /// Requests location permission.
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }
}
