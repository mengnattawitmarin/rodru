import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? error;
  const LocationResult(this.position, this.error);
}

/// Asks for location permission only when the user taps "use my location".
class LocationService {
  static Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(null, 'กรุณาเปิด GPS / บริการตำแหน่งในเครื่อง');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(null, 'ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง');
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(null, 'สิทธิ์ตำแหน่งถูกปิดถาวร เปิดได้ที่การตั้งค่าแอป');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult(pos, null);
    } catch (e) {
      final last = await Geolocator.getLastKnownPosition().catchError((_) => null);
      if (last != null) return LocationResult(last, null);
      return LocationResult(null, 'หาตำแหน่งไม่สำเร็จ: $e');
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
}
