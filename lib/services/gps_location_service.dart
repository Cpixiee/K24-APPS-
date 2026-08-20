import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:apps_k24/services/api_service.dart';

class GpsLocationService {
  /// Check GPS permissions & request from Android OS if needed
  static Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Location services are disabled on device.');
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GPS] Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Location permissions are permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[GPS] Error checking permission: $e');
      return false;
    }
  }

  /// Get real hardware GPS coordinates from HP Driver
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return position;
    } catch (e) {
      debugPrint('[GPS] Error getting position: $e');
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        return lastPos;
      } catch (_) {
        return null;
      }
    }
  }

  /// Send real hardware location update to backend API
  static Future<bool> sendLocationUpdate() async {
    try {
      final pos = await getCurrentPosition();
      if (pos != null) {
        debugPrint('[GPS] Sending REAL location update: ${pos.latitude}, ${pos.longitude}');
        final ok = await ApiService.updateDriverLocation(pos.latitude, pos.longitude);
        return ok;
      }
    } catch (e) {
      debugPrint('[GPS] sendLocationUpdate error: $e');
    }
    return false;
  }
}
