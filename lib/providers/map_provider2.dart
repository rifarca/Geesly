
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_location.dart';
import '../models/map_marker.dart';
import '../models/map_route.dart';
import '../models/map_search_result.dart';
import '../services/location_service.dart';
import '../services/mapbox_directions_service.dart';
import '../services/mapbox_search_service.dart';

class MapProvider extends ChangeNotifier {
  // ============================================================
  // SERVICIOS
  // ============================================================

  final LocationService _locationService = LocationService();
  final MapboxSearchService _searchService = MapboxSearchService();
  final MapboxDirectionsService _directionsService =
      MapboxDirectionsService();

  // ============================================================
  // MAPBOX
  // ============================================================

  MapboxMap? _map;

  CircleAnnotationManager? _markerManager;
  PolylineAnnotationManager? _routeManager;

  Future<void>? _initializationFuture;

  bool mapReady = false;
  bool loading = false;

  // ============================================================
  // ESTADO
  // ============================================================

  MapLocation? currentLocation;
  MapLocation? selectedDestination;
  MapRoute? currentRoute;

  final List<MapMarker> markers = [];

  List<MapSearchResult> searchResults = [];

  String? error;
  String? _activeSearchQuery;

  int _searchGeneration = 0;

  // ============================================================
  // INICIALIZAR MAPA
  // ============================================================

  Future<void> onMapCreated(MapboxMap map) async {
    _map = map;

    mapReady = false;
    _markerManager = null;
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
    final markerManager =
        await map.annotations.createCircleAnnotationManager();

    final routeManager =
        await map.annotations.createPolylineAnnotationManager();

    // Evita asignar administradores de un mapa anterior.
    if (!identical(_map, map)) return;

    _markerManager = markerManager;
    _routeManager = routeManager;
  }

  Future<void> _ensureMapReady() async {
    if (_map == null) {
      throw StateError('El mapa no está disponible.');
    }

    if (_markerManager != null && _routeManager != null) {
      return;
    }

    await _initializeAnnotations();

    if (_markerManager == null || _routeManager == null) {
      throw StateError(
        'No se pudieron inicializar los administradores del mapa.',
      );
    }

    mapReady = true;
  }

  // ============================================================
  // UBICACIÓN ACTUAL
  // ============================================================

  Future<void> goToCurrentLocation() async {
    await _run(() async {
      await _ensureMapReady();

      final location = await _locationService.currentLocation();

      currentLocation = location;

      await _moveCamera(
        location,
        zoom: 15,
      );

      await _map!.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
        ),
      );
    });
  }

  // ============================================================
  // MOVER CÁMARA
  // ============================================================

  Future<void> _moveCamera(
    MapLocation location, {
    double zoom = 15,
  }) async {
    final map = _map;

    if (map == null) {
      throw StateError('El mapa no está disponible.');
    }

    // Coordenada geográfica de destino.
    final coordinate = Point(
      coordinates: Position(
        location.longitude,
        location.latitude,
      ),
    );

    await map.flyTo(
      CameraOptions(
        center: coordinate,
        zoom: zoom,
      ),
      MapAnimationOptions(
        duration: 800,
      ),
    );
  }

  // ============================================================
  // BUSCAR DIRECCIONES
  // ============================================================

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

      // Ignora respuestas de búsquedas anteriores.
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

  // ============================================================
  // SELECCIONAR RESULTADO
  // ============================================================

  Future<void> selectSearchResult(
    MapSearchResult suggestion,
  ) async {
    // Invalida búsquedas pendientes.
    _searchGeneration++;

    await _run(() async {
      await _ensureMapReady();

      final result = await _searchService.retrieve(
        suggestion.id,
      );

      final location = result.location;

      if (location == null) {
        throw Exception(
          'El resultado no contiene coordenadas.',
        );
      }

      selectedDestination = location;

      final marker = MapMarker(
        id: result.id,
        title: result.name,
        description: result.address,
        location: location,
      );

      await addMarker(marker);

      await _moveCamera(
        location,
        zoom: 16,
      );

      searchResults = [];
      _activeSearchQuery = null;
    });
  }

  // ============================================================
  // AGREGAR MARCADOR
  // ============================================================

  Future<void> addMarker(MapMarker marker) async {
    await _ensureMapReady();

    final manager = _markerManager;

    if (manager == null) {
      throw StateError(
        'El administrador de marcadores no está disponible.',
      );
    }

    // Crear la coordenada del marcador.
    final coordinate = Point(
      coordinates: Position(
        marker.location.longitude,
        marker.location.latitude,
      ),
    );

    await manager.create(
      CircleAnnotationOptions(
        geometry: coordinate,
        circleRadius: 10,
        circleColor: 0xFF10B981,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ),
    );

    markers.removeWhere(
      (item) => item.id == marker.id,
    );

    markers.add(marker);

    notifyListeners();
  }

  // ============================================================
  // CALCULAR RUTA
  // ============================================================

  Future<void> calculateRoute({
    String profile = 'driving',
  }) async {
    await _run(() async {
      await _ensureMapReady();

      if (selectedDestination == null) {
        throw Exception(
          'Primero buscá y seleccioná un destino.',
        );
      }

      currentLocation ??=
          await _locationService.currentLocation();

      final route = await _directionsService.getRoute(
        origin: currentLocation!,
        destination: selectedDestination!,
        profile: profile,
      );

      if (route.coordinates.length < 2) {
        throw Exception(
          'La ruta no contiene coordenadas suficientes.',
        );
      }

      currentRoute = route;

      await _drawRoute(route);
    });
  }

  // ============================================================
  // DIBUJAR RUTA
  // ============================================================

  Future<void> _drawRoute(MapRoute route) async {
    await _ensureMapReady();

    final manager = _routeManager;

    if (manager == null) {
      throw StateError(
        'El administrador de rutas no está disponible.',
      );
    }

    // IMPORTANTE:
    // LineString recibe List<Position>, no List<Point>.
    final List<Position> coordinates =
        route.coordinates.map((point) {
      return Position(
        point.longitude,
        point.latitude,
      );
    }).toList();

    if (coordinates.length < 2) {
      throw Exception(
        'No hay suficientes coordenadas para dibujar la ruta.',
      );
    }

    await manager.deleteAll();

    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: coordinates,
        ),
        lineColor: 0xFF2563EB,
        lineWidth: 5,
      ),
    );
  }

  // ============================================================
  // LIMPIAR RUTA
  // ============================================================

  Future<void> clearRoute() async {
    await _run(() async {
      await _ensureMapReady();

      await _routeManager?.deleteAll();

      currentRoute = null;
      selectedDestination = null;
      searchResults = [];

      _activeSearchQuery = null;
      _searchGeneration++;
    });
  }

  // ============================================================
  // LIMPIAR MARCADORES
  // ============================================================

  Future<void> clearMarkers() async {
    await _run(() async {
      await _ensureMapReady();

      await _markerManager?.deleteAll();

      markers.clear();
    });
  }

  // ============================================================
  // LIMPIAR BÚSQUEDA
  // ============================================================

  void clearSearch() {
    _searchGeneration++;

    searchResults = [];
    _activeSearchQuery = null;
    error = null;

    notifyListeners();
  }

  // ============================================================
  // MANEJO DE OPERACIONES
  // ============================================================

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    // Evita operaciones simultáneas.
    if (loading) return;

    loading = true;
    error = null;

    notifyListeners();

    try {
      await action();
    } catch (e, stackTrace) {
      debugPrint('MapProvider error: $e');
      debugPrintStack(
        stackTrace: stackTrace,
      );

      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ERRORES
  // ============================================================

  String _friendlyError(Object exception) {
    return exception
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  // ============================================================
  // LIBERAR RECURSOS
  // ============================================================

  @override
  void dispose() {
    _searchGeneration++;

    _searchService.dispose();
    _directionsService.dispose();

    super.dispose();
  }
}
