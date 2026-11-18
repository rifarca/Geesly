import 'package:geolocator/geolocator.dart';

import '../models/map_location.dart';

class LocationService {
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está desactivado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('No se concedió permiso para acceder a la ubicación.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso está bloqueado. Habilitalo desde los ajustes del dispositivo.',
      );
    }
  }

  Future<MapLocation> currentLocation() async {
    await ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return MapLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Stream<MapLocation> watchLocation() async* {
    await ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(
      (position) => MapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }
}
