import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/mapbox/mapbox_config.dart';
import '../models/map_location.dart';
import '../models/map_route.dart';

class MapboxDirectionsService {
  MapboxDirectionsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<MapRoute> getRoute({
    required MapLocation origin,
    required MapLocation destination,
    String profile = 'driving',
  }) async {
    const profiles = {
      'driving',
      'driving-traffic',
      'walking',
      'cycling',
    };
    if (!profiles.contains(profile)) {
      throw ArgumentError.value(profile, 'profile', 'Perfil no soportado');
    }

    final coords =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/$profile/$coords',
      {
        'access_token': MapboxConfig.accessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'language': 'es',
      },
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 20),
        );
    if (response.statusCode != 200) {
      throw Exception('No se pudo calcular la ruta (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw Exception('No se encontró una ruta para esos puntos.');
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    return MapRoute(
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      coordinates: coordinates.map((coordinate) {
        final pair = coordinate as List<dynamic>;
        return MapLocation(
          longitude: (pair[0] as num).toDouble(),
          latitude: (pair[1] as num).toDouble(),
        );
      }).toList(),
    );
  }

  void dispose() => _client.close();
}
