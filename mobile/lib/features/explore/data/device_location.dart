import 'package:geolocator/geolocator.dart';

import 'place_lookup.dart';

/// The device's position through geolocator. Permission is asked only here,
/// when the user taps "Vị trí của tôi", never on opening the map.
class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation();

  @override
  bool get supported => true;

  @override
  Future<DeviceFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceFixFailed();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const DeviceFixDenied();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return DeviceFixFound(position.latitude, position.longitude);
    } catch (_) {
      return const DeviceFixFailed();
    }
  }
}
