import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../components/MenuNeoGlassNavigationBar.dart';
import '../../providers/map_provider_2.dart';
import '../../components/vehicle_selection.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ============================================================
  // CONTROLADORES
  // ============================================================

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  final PanelController _panelController = PanelController();

  Timer? _debounce;

  // Instancia de MapboxMap para interactuar con la cámara
  MapboxMap? _mapboxMap;

  // Estado para controlar la selección por el centro de la cámara
  bool _isSelectingByCenter = false;

  // Configuración del viaje y estimación.
  final String _selectedVehicle = 'car';
  final TextEditingController _consumptionController = TextEditingController(
    text: '8',
  );
  final TextEditingController _fuelPriceController = TextEditingController(
    text: '7500',
  );

  // ============================================================
  // CONFIGURACIÓN DEL PANEL
  // ============================================================

  static double _panelHeightClosed = 300;
  double _panelHeightOpen = 0;

  double _fabHeight = 180;
  static const double _initialFabHeight = 295;

  // ============================================================
  // COORDENADAS INICIALES: PIRIBEBUY (Respaldo si falla GPS)
  // ============================================================

  static const double _initialLatitude = -25.4783;
  static const double _initialLongitude = -57.0544;

  // ============================================================
  // CICLO DE VIDA
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fabHeight = _initialFabHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentLocation();
    });
  }

  Future<void> _initCurrentLocation() async {
    final provider = context.read<MapProvider>();
    await _goToCurrentLocation(provider);

    if (provider.currentLocation != null && mounted) {
      _originController.text = 'Mi ubicación actual';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _consumptionController.dispose();
    _fuelPriceController.dispose();
    super.dispose();
  }

  Future<void> _onMapTap(
    MapContentGestureContext gesture,
    MapProvider provider,
  ) async {
    final position = gesture.point.coordinates;

    await provider.selectMapCoordinate(
      latitude: position.lat.toDouble(),
      longitude: position.lng.toDouble(),
    );

    if (!mounted || provider.selectedDestination == null) return;

    _debounce?.cancel();
    _destinationController.text = provider.placeAddress.toString();
    _destinationFocusNode.unfocus();
    await _calculateRoute(provider);
    _openPanel();
  }

  // ============================================================
  // BÚSQUEDA CON DEBOUNCE
  // ============================================================

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      context.read<MapProvider>().search(value);
    });
  }

  void _clearSearch(MapProvider provider) {
    _debounce?.cancel();
    _destinationController.clear();
    provider.clearSearch();
    provider.clearRoute();
    _destinationFocusNode.unfocus();
  }

  // ============================================================
  // MAPBOX
  // ============================================================

  Future<void> _onMapCreated(MapboxMap mapboxMap, MapProvider provider) async {
    _mapboxMap = mapboxMap;
    await provider.onMapCreated(mapboxMap);

    if (!mounted) return;

    mapboxMap.addInteraction(
      TapInteraction.onMap((gesture) {
        unawaited(_onMapTap(gesture, provider));
      }),
    );

    if (provider.currentLocation == null) {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(_initialLongitude, _initialLatitude),
          ),
          zoom: 13,
        ),
      );
    }
  }

  void _openPanel() {
    if (_panelController.isAttached) {
      _panelController.open();
    }
  }

  Future<void> _goToCurrentLocation(MapProvider provider) async {
    await provider.goToCurrentLocation();
    if (provider.currentLocation != null && mounted) {
      setState(() {
        _originController.text = 'Mi ubicación actual';
      });
    }
  }

  Future<void> _startCenterCapture() async {
    if (_panelController.isAttached) {
      _panelController.close();
    }
    setState(() {
      _isSelectingByCenter = true;
    });
  }

  Future<void> _confirmCenterLocation(MapProvider provider) async {
    if (_mapboxMap == null) return;

    final cameraState = await _mapboxMap!.getCameraState();
    final coordinates = cameraState.center.coordinates;
    final lng = coordinates[0]!.toDouble();
    final lat = coordinates[1]!.toDouble();

    await provider.selectMapCoordinate(latitude: lat, longitude: lng);

    if (!mounted) return;

    setState(() {
      _isSelectingByCenter = false;
      _destinationController.text =
          provider.placeAddress ?? 'Ubicación central';
    });

    await _calculateRoute(provider);
    //_openPanel();
    // context.push('/travel-step-2');
  }

  Future<void> _selectDestination(MapProvider provider, dynamic item) async {
    _debounce?.cancel();
    await provider.selectSearchResult(item);

    if (!mounted) return;

    _destinationController.text = item.name;
    _destinationFocusNode.unfocus();

    await _calculateRoute(provider);
  }

  // ============================================================
  // CALCULAR RUTA
  // ============================================================

  Future<void> _calculateRoute(MapProvider provider) async {
    _destinationFocusNode.unfocus();
    _originFocusNode.unfocus();

    await provider.calculateRoute(profile: 'driving');

    if (!mounted) return;

    if (provider.currentRoute != null && _panelController.isAttached) {
      _panelController.open();
    }
  }

  // ============================================================
  // GENERAR OPCIONES DE VEHÍCULOS SEGÚN DISTANCIA DE LA RUTA
  // ============================================================

  List<VehicleOption> _getAvailableVehicles(MapProvider provider) {
    // Distancia en kilómetros obtenida de la ruta de Mapbox (por defecto 5 km si es null)
    final double distanceKm = provider.routeDistance ?? 5.0;

    // Tarifas base estimadas por kilómetro (ej. en Guaraníes Gs.)
    final double baseMoto = 4500;
    final double perKmMoto = 1800;

    final double baseEcon = 6000;
    final double perKmEcon = 3200;

    final double basePrem = 10000;
    final double perKmPrem = 5500;

    final double priceMoto = baseMoto + (distanceKm * perKmMoto);
    final double priceEcon = baseEcon + (distanceKm * perKmEcon);
    final double pricePrem = basePrem + (distanceKm * perKmPrem);

    return [
      VehicleOption(
        id: 'moto',
        name: 'Moto',
        subtitle: 'Viaje rápido, esquiva el tráfico',
        eta: '2 min',
        price: priceMoto,
        capacity: 1,
        icon: Icons.two_wheeler_rounded,
        isPromo: true,
      ),
      VehicleOption(
        id: 'economico',
        name: 'Económico',
        subtitle: 'Autos cómodos para el día a día',
        eta: '4 min',
        price: priceEcon,
        capacity: 4,
        icon: Icons.directions_car_filled_rounded,
      ),
      VehicleOption(
        id: 'premium',
        name: 'Premium',
        subtitle: 'Vehículos de alta gama y confort',
        eta: '6 min',
        price: pricePrem,
        capacity: 4,
        icon: Icons.local_taxi_rounded,
      ),
    ];
  }

  // ============================================================
  // CONSTRUIR PANTALLA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    _panelHeightOpen = screenHeight * 0.5;

    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: Text('Eliga un destino')),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              // ==================================================
              // MAPA MAPBOX
              // ==================================================
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('geesly-map'),
                  onMapCreated: (mapboxMap) {
                    _onMapCreated(mapboxMap, provider);
                  },
                ),
              ),

              // ==================================================
              // MIRA CENTRAL
              // ==================================================
              if (_isSelectingByCenter)
                const Center(
                  child: Icon(
                    Icons.center_focus_strong,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                ),

              if (_isSelectingByCenter)
                Positioned(
                  bottom: 110,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      _confirmCenterLocation(provider);
                      setState() {
                        _panelHeightClosed = 340;
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.greenAccent),
                    label: const Text(
                      'Confirmar ubicación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // ==================================================
              // CAPA SUPERIOR BLUR
              // ==================================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: MediaQuery.of(context).padding.top,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),

              // ==================================================
              // PANEL INFERIOR DESLIZABLE
              // ==================================================
              if (!_isSelectingByCenter)
                SlidingUpPanel(
                  controller: _panelController,
                  maxHeight: _panelHeightOpen,
                  minHeight: _panelHeightClosed,
                  parallaxEnabled: true,
                  parallaxOffset: 0.12,
                  backdropEnabled: false,
                  panelSnapping: true,
                  defaultPanelState: PanelState.CLOSED,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  body: const SizedBox.expand(),
                  panelBuilder: (scrollController) {
                    return _buildPanel(context, provider, scrollController);
                  },
                  onPanelSlide: (position) {
                    if (!mounted) return;
                    setState(() {
                      _fabHeight =
                          position * (_panelHeightOpen - _panelHeightClosed) +
                          _initialFabHeight;
                    });
                  },
                ),

              // ==================================================
              // BOTÓN GPS
              // ==================================================
              Positioned(
                right: 18,
                bottom: _isSelectingByCenter ? 40 : _fabHeight,
                child: SafeArea(
                  child: FloatingActionButton(
                    heroTag: 'geesly-current-location',
                    elevation: 5,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: provider.loading
                        ? null
                        : () => _goToCurrentLocation(provider),
                    child: const Icon(Icons.my_location, size: 23),
                  ),
                ),
              ),

              // ==================================================
              // INDICADOR DE CARGA
              // ==================================================
              if (provider.loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
          bottomNavigationBar: MenuNeoGlassNagivationBar(selectedItem: 1),
        );
      },
    );
  }

  // ============================================================
  // PANEL INFERIOR (CAMBIA SEGÚN SI HAY RUTA TRAZADA)
  // ============================================================

  Widget _buildPanel(
    BuildContext context,
    MapProvider provider,
    ScrollController scrollController,
  ) {
    // Si ya se calculó la ruta, mostramos directamente el selector de vehículos
    /*if (provider.currentRoute != null) {
      context.push('/travel-step-2');
      return VehicleSelectionWidget(
        options: _getAvailableVehicles(provider),
        currencySymbol: 'Gs.',
        onVehicleSelected: (vehicle) {
          debugPrint('Vehículo seleccionado: ${vehicle.name}');
        },
        onConfirmPressed: (selectedVehicle) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Buscando conductor para ${selectedVehicle.name}...',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    }*/

    // Si aún no hay ruta, mostramos la interfaz normal de búsqueda y configuración
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Material(
        color: theme.colorScheme.surface,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planificá tu ruta',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configura tu origen y destino',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.explore_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _buildOriginBox(context, provider),
                  const SizedBox(height: 10),
                  _buildSearchBox(context, provider),
                ],
              ),
            ),

            if (provider.searchResults.isNotEmpty)
              _buildSearchResults(provider),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUSCADORES Y RESULTADOS
  // ============================================================

  Widget _buildOriginBox(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: _originController,
        focusNode: _originFocusNode,
        onTap: _openPanel,
        decoration: InputDecoration(
          hintText: 'Origen (ej. Mi ubicación)',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: const Icon(Icons.trip_origin, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: _destinationController,
        focusNode: _destinationFocusNode,
        onTap: _openPanel,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Destino (buscar lugar)',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: const Icon(Icons.location_on, color: Colors.red),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_destinationController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () => _clearSearch(provider),
                  icon: const Icon(Icons.close),
                ),
              IconButton(
                tooltip: 'Buscar por el centro del mapa',
                onPressed: () {
                  _startCenterCapture();
                  // context.push('/travel-step-2');
                },
                icon: const Icon(Icons.location_pin),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(MapProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.searchResults.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 55),
          itemBuilder: (context, index) {
            final item = provider.searchResults[index];
            return ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 18,
                child: Icon(Icons.location_on_outlined, size: 19),
              ),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: provider.loading
                  ? null
                  : () => _selectDestination(provider, item),
            );
          },
        ),
      ),
    );
  }
}
