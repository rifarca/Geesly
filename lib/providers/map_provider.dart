import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../components/BoltMarkerPainter.dart';
import '../models/map_location.dart';
import '../models/map_marker.dart';
import '../models/map_route.dart';
import '../models/map_search_result.dart';
import '../services/location_service.dart';
import '../services/mapbox_directions_service.dart';
import '../services/mapbox_search_service.dart';


class MapProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final MapboxSearchService _searchService = MapboxSearchService();
  final MapboxDirectionsService _directionsService = MapboxDirectionsService();

  MapboxMap? _map;

  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _routeManager;

  Future<void>? _initializationFuture;

  bool mapReady = false;
  bool loading = false;

  MapLocation? currentLocation;
  String? _originStreetName;

  MapLocation? selectedDestination;
  MapSearchResult? selectedDestinationDetails;
  MapRoute? currentRoute;

  final List<MapMarker> markers = [];
  List<MapSearchResult> searchResults = [];

  String? error;
  String? _activeSearchQuery;
  int _searchGeneration = 0;

  String? _placeName;
  String? _placeAddress;

  // Podés configurar assets customizados para origen y destino (opcional)
  final String? originAssetIcon = 'assets/ic_origin.png';
  final String? destinationAssetIcon = 'assets/ic_destination.png';

  String? get placeName => _placeName;
  String? get placeAddress => _placeAddress;
  String? get originStreetName => _originStreetName;
  bool get hasSelectedDestination => selectedDestination != null;
  double? get routeDistance => null;

  Future<void> onMapCreated(MapboxMap map) async {
    _map = map;
    mapReady = false;
    _pointManager = null;
    _routeManager = null;

    try {
      await _initializeAnnotations();
      mapReady = true;
      error = null;
    } catch (e) {
      mapReady = false;
      error = _friendlyError(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _initializeAnnotations() async {
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    final map = _map;
    if (map == null) {
      throw StateError('El mapa todavía no está disponible.');
    }

    final future = _createAnnotationManagers(map);
    _initializationFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _createAnnotationManagers(MapboxMap map) async {
    final pointManager = await map.annotations.createPointAnnotationManager();
    final routeManager = await map.annotations
        .createPolylineAnnotationManager();

    if (!identical(_map, map)) return;

    _pointManager = pointManager;
    _routeManager = routeManager;
  }

  Future<void> _ensureMapReady() async {
    if (_map == null) {
      throw StateError('El mapa no está disponible.');
    }

    if (_pointManager != null && _routeManager != null) {
      return;
    }

    await _initializeAnnotations();

    if (_pointManager == null || _routeManager == null) {
      throw StateError(
        'No se pudieron inicializar los administradores del mapa.',
      );
    }

    mapReady = true;
  }

  Future<void> goToCurrentLocation() async {
    await _run(() async {
      await _ensureMapReady();

      final location = await _locationService.currentLocation();
      currentLocation = location;
      _originStreetName = await _resolveStreetName(location);

      await _moveCamera(location, zoom: 15);

      await _map!.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    });
  }

  Future<String> _resolveStreetName(MapLocation location) async {
    try {
      final res = await _searchService.reverseGeocode(location);
      if (res.name.trim().isNotEmpty) return res.name.trim();
      if (res.address.trim().isNotEmpty) return res.address.trim();
    } catch (_) {
      // Si falla reverseGeocode, usamos etiqueta por defecto sin cortar el flujo
    }
    return 'Tu ubicación';
  }

  Future<void> _moveCamera(MapLocation location, {double zoom = 15}) async {
    final map = _map;
    if (map == null) {
      throw StateError('El mapa no está disponible.');
    }

    final coordinate = Point(
      coordinates: Position(location.longitude, location.latitude),
    );

    await map.flyTo(
      CameraOptions(center: coordinate, zoom: zoom),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _fitRouteBounds(
    MapLocation origin,
    MapLocation destination,
  ) async {
    final map = _map;
    if (map == null) return;

    final points = [
      Point(coordinates: Position(origin.longitude, origin.latitude)),
      Point(coordinates: Position(destination.longitude, destination.latitude)),
    ];

    final camera = await map.cameraForCoordinates(
      points,
      MbxEdgeInsets(top: 140, left: 60, bottom: 260, right: 60),
      null,
      null,
    );

    await map.flyTo(camera, MapAnimationOptions(duration: 300));
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    final generation = ++_searchGeneration;

    if (trimmed.length < 3) {
      searchResults = [];
      error = null;
      _activeSearchQuery = null;
      notifyListeners();
      return;
    }

    try {
      if (_activeSearchQuery == null) {
        _searchService.startSession();
      }

      _activeSearchQuery = trimmed;

      final results = await _searchService.suggest(
        trimmed,
        proximity: currentLocation,
      );

      if (generation != _searchGeneration) return;

      searchResults = results;
      error = null;
    } catch (e) {
      if (generation != _searchGeneration) return;

      searchResults = [];
      error = _friendlyError(e);
    }

    if (generation == _searchGeneration) {
      notifyListeners();
    }
  }

  Future<void> selectSearchResult(MapSearchResult suggestion) async {
    _searchGeneration++;

    await _run(() async {
      await _ensureMapReady();

      final result = suggestion.location != null
          ? suggestion
          : await _searchService.retrieve(suggestion.id);

      final location = result.location;
      if (location == null) {
        throw Exception('El resultado no contiene coordenadas válidas.');
      }

      await _setSelectedDestination(result, location);
    });
  }

  Future<void> selectMapCoordinate({
    required double latitude,
    required double longitude,
  }) async {
    _searchGeneration++;

    await _run(() async {
      await _ensureMapReady();

      final location = MapLocation(latitude: latitude, longitude: longitude);
      final result = await _searchService.reverseGeocode(location);

      await _setSelectedDestination(result, location);
    });
  }

  Future<void> _setSelectedDestination(
    MapSearchResult result,
    MapLocation location,
  ) async {
    await _routeManager?.deleteAll();
    await _pointManager?.deleteAll();

    currentRoute = null;
    markers.clear();

    selectedDestination = location;
    selectedDestinationDetails = result;

    _placeName = result.name.trim().isNotEmpty
        ? result.name.trim()
        : 'Ubicación seleccionada';

    _placeAddress = result.address.trim().isNotEmpty
        ? result.address.trim()
        : 'Dirección no disponible';

    final marker = MapMarker(
      id: result.id,
      title: _placeName!,
      description: _placeAddress!,
      location: location,
    );

    await addBoltMarker(
      marker: marker,
      isOrigin: false,
      assetIconPath: destinationAssetIcon,
    );

    searchResults = [];
    _activeSearchQuery = null;

    await _moveCamera(location, zoom: 16);
  }

  /// Dibuja un marcador estilo Bolt (píldora con calle + ícono customizado).
  Future<void> addBoltMarker({
    required MapMarker marker,
    required bool isOrigin,
    String? assetIconPath,
  }) async {
    await _ensureMapReady();

    final manager = _pointManager;
    if (manager == null) {
      throw StateError('El administrador de marcadores no está disponible.');
    }

    final Uint8List markerBytes = await BoltMarkerPainter.buildMarkerBytes(
      streetName: marker.title,
      isOrigin: isOrigin,
      assetIconPath: assetIconPath,
    );

    final coordinate = Point(
      coordinates: Position(
        marker.location.longitude,
        marker.location.latitude,
      ),
    );

    await manager.create(
      PointAnnotationOptions(
        geometry: coordinate,
        image: markerBytes,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );

    markers.removeWhere((item) => item.id == marker.id);
    markers.add(marker);
    notifyListeners();
  }

  /// Calcula la ruta y coloca los marcadores estilo Bolt de origen y destino.
  Future<void> calculateRoute({String profile = 'driving'}) async {
    await _run(() async {
      await _ensureMapReady();

      final destination = selectedDestination;
      if (destination == null) {
        throw Exception(
          'Primero buscá una dirección o seleccioná un punto en el mapa.',
        );
      }

      currentLocation ??= await _locationService.currentLocation();
      final origin = currentLocation!;

      _originStreetName ??= await _resolveStreetName(origin);
      final String destStreet =
          (_placeName != null && _placeName!.trim().isNotEmpty)
          ? _placeName!
          : await _resolveStreetName(destination);

      final route = await _directionsService.getRoute(
        origin: origin,
        destination: destination,
        profile: profile,
      );

      if (route.coordinates.length < 2) {
        throw Exception('La ruta no contiene coordenadas suficientes.');
      }

      currentRoute = route;

      await _drawRoute(route);
      await _drawOriginAndDestinationMarkers(
        origin: origin,
        originStreet: _originStreetName!,
        destination: destination,
        destinationStreet: destStreet,
      );
      await _fitRouteBounds(origin, destination);
    });
  }

  Future<void> _drawOriginAndDestinationMarkers({
    required MapLocation origin,
    required String originStreet,
    required MapLocation destination,
    required String destinationStreet,
  }) async {
    await _pointManager?.deleteAll();
    markers.clear();

    await addBoltMarker(
      marker: MapMarker(
        id: 'route_origin',
        title: originStreet,
        description: 'Origen',
        location: origin,
      ),
      isOrigin: true,
      assetIconPath: originAssetIcon,
    );

    await addBoltMarker(
      marker: MapMarker(
        id: 'route_destination',
        title: destinationStreet,
        description: _placeAddress ?? 'Destino',
        location: destination,
      ),
      isOrigin: false,
      assetIconPath: destinationAssetIcon,
    );
  }

  Future<void> _drawRoute(MapRoute route) async {
    await _ensureMapReady();

    final manager = _routeManager;
    if (manager == null) {
      throw StateError('El administrador de rutas no está disponible.');
    }

    final List<Position> coordinates = route.coordinates.map((point) {
      return Position(point.longitude, point.latitude);
    }).toList();

    if (coordinates.length < 2) {
      throw Exception('No hay suficientes coordenadas para dibujar la ruta.');
    }

    await manager.deleteAll();

    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineColor: 0xFF2563EB,
        lineWidth: 5,
      ),
    );
  }

  Future<void> clearRoute() async {
    await _run(() async {
      await _ensureMapReady();

      await _routeManager?.deleteAll();
      await _pointManager?.deleteAll();

      currentRoute = null;
      selectedDestination = null;
      selectedDestinationDetails = null;
      _placeName = null;
      _placeAddress = null;

      markers.clear();
      searchResults = [];
      _activeSearchQuery = null;
      _searchGeneration++;
    });
  }

  Future<void> clearMarkers() async {
    await _run(() async {
      await _ensureMapReady();
      await _pointManager?.deleteAll();
      markers.clear();
    });
  }

  void clearSearch() {
    _searchGeneration++;
    searchResults = [];
    _activeSearchQuery = null;
    error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (loading) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      await action();
    } catch (e, stackTrace) {
      debugPrint('MapProvider error: $e');
      debugPrintStack(stackTrace: stackTrace);
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object exception) {
    return exception
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _searchGeneration++;
    _searchService.dispose();
    _directionsService.dispose();
    super.dispose();
  }

  Future<void> selectCenterCoordinate({required Size mapSize}) async {
    if (_map == null || !mapReady) {
      error = 'El mapa todavía no está inicializado';
      notifyListeners();
      return;
    }

    if (mapSize.width <= 0 || mapSize.height <= 0) {
      error = 'No se pudieron obtener las dimensiones del mapa';
      notifyListeners();
      return;
    }

    try {
      final double middleX = mapSize.width / 2;
      final double middleY = mapSize.height / 2;

      final point = await _map!.coordinateForPixel(
        ScreenCoordinate(x: middleX, y: middleY),
      );

      final position = point.coordinates;
      final latitude = position.lat.toDouble();
      final longitude = position.lng.toDouble();

      await selectMapCoordinate(latitude: latitude, longitude: longitude);
    } catch (e) {
      error = 'Error al obtener las coordenadas: $e';
      debugPrint(error);
      notifyListeners();
    }
  }
}
