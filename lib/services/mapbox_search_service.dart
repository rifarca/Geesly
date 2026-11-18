
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/mapbox/mapbox_config.dart';
import '../models/map_location.dart';
import '../models/map_search_result.dart';

class MapboxSearchService {
  MapboxSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // Se conserva para no tener que cambiar el provider que ya lo invoca.
  // Geocoding v6 no utiliza session_token.
  void startSession() {}

  /// Busca direcciones y devuelve nombre, dirección y coordenadas.
  Future<List<MapSearchResult>> suggest(
    String query, {
    MapLocation? proximity,
  }) async {
    final text = query.trim();
    if (text.length < 3) return [];

    final uri = Uri.https(
      'api.mapbox.com',
      '/search/geocode/v6/forward',
      {
        'q': text,
        'access_token': MapboxConfig.accessToken,
        'autocomplete': 'true',
        'language': 'es',
        'country': 'PY',
        'limit': '6',
        if (proximity != null)
          'proximity':
              '${proximity.longitude},${proximity.latitude}',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    final body = _decodeResponse(response);

    final features = body['features'] as List<dynamic>? ?? [];

    return features
        .map((feature) => _parseFeature(
              feature as Map<String, dynamic>,
            ))
        .where((result) => result.location != null)
        .toList();
  }

  /// Recupera un resultado por su Mapbox ID.
  /// En Geocoding v6 se puede consultar un feature usando su ID.
  Future<MapSearchResult> retrieve(String mapboxId) async {
    final uri = Uri.https(
      'api.mapbox.com',
      '/search/geocode/v6/forward',
      {
        'q': mapboxId,
        'access_token': MapboxConfig.accessToken,
        'language': 'es',
        'limit': '1',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    final body = _decodeResponse(response);
    final features = body['features'] as List<dynamic>? ?? [];

    if (features.isEmpty) {
      throw Exception('No se pudo recuperar la dirección seleccionada.');
    }

    return _parseFeature(
      features.first as Map<String, dynamic>,
    );
  }

  /// Convierte coordenadas en una dirección legible.
  ///
  /// Se utiliza cuando el usuario toca directamente el mapa.
  Future<MapSearchResult> reverseGeocode(
    MapLocation location,
  ) async {
    final uri = Uri.https(
      'api.mapbox.com',
      '/search/geocode/v6/reverse',
      {
        'longitude': location.longitude.toString(),
        'latitude': location.latitude.toString(),
        'access_token': MapboxConfig.accessToken,
        'language': 'es',
        'limit': '1',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    final body = _decodeResponse(response);
    final features = body['features'] as List<dynamic>? ?? [];

    // Aunque Mapbox no encuentre una dirección exacta,
    // conservamos las coordenadas para permitir calcular la ruta.
    if (features.isEmpty) {
      return MapSearchResult(
        id: _coordinateId(location),
        name: 'Punto seleccionado',
        address: _coordinateDescription(location),
        location: location,
      );
    }

    final result = _parseFeature(
      features.first as Map<String, dynamic>,
      locationOverride: location,
    );

    return result;
  }

  MapSearchResult _parseFeature(
    Map<String, dynamic> feature, {
    MapLocation? locationOverride,
  }) {
    final properties =
        feature['properties'] as Map<String, dynamic>? ?? {};

    final coordinates =
        properties['coordinates'] as Map<String, dynamic>?;

    final geometry =
        feature['geometry'] as Map<String, dynamic>?;

    final geometryCoordinates =
        geometry?['coordinates'] as List<dynamic>?;

    final longitude = coordinates?['longitude'] as num? ??
        (geometryCoordinates != null &&
                geometryCoordinates.length >= 2
            ? geometryCoordinates[0] as num
            : null);

    final latitude = coordinates?['latitude'] as num? ??
        (geometryCoordinates != null &&
                geometryCoordinates.length >= 2
            ? geometryCoordinates[1] as num
            : null);

    final location = locationOverride ??
        (longitude != null && latitude != null
            ? MapLocation(
                longitude: longitude.toDouble(),
                latitude: latitude.toDouble(),
              )
            : null);

    final name = (
      properties['name_preferred'] ??
      properties['name'] ??
      'Lugar'
    ).toString();

    final fullAddress =
        properties['full_address']?.toString();

    final placeFormatted =
        properties['place_formatted']?.toString();

    final address = (fullAddress != null &&
            fullAddress.trim().isNotEmpty)
        ? fullAddress
        : (placeFormatted != null &&
                placeFormatted.trim().isNotEmpty)
            ? '$name, $placeFormatted'
            : name;

    return MapSearchResult(
      id: (
        properties['mapbox_id'] ??
        feature['id'] ??
        'geocode-${location?.latitude}-${location?.longitude}'
      ).toString(),
      name: name,
      address: address,
      location: location,
    );
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      final message = decoded is Map
          ? decoded['message']?.toString()
          : null;

      throw Exception(
        message ?? 'Mapbox respondió con error ${response.statusCode}.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('La respuesta de Mapbox no es válida.');
    }

    return decoded;
  }

  String _coordinateId(MapLocation location) {
    return 'point-${location.latitude}-${location.longitude}';
  }

  String _coordinateDescription(MapLocation location) {
    return 'Dirección no disponible. '
        'Lat: ${location.latitude.toStringAsFixed(6)}, '
        'Lon: ${location.longitude.toStringAsFixed(6)}';
  }

  void dispose() {
    _client.close();
  }
}
