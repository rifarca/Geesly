import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../providers/map_provider.dart';

class MapScreenPosition extends StatefulWidget {
   MapScreenPosition({super.key});

  @override
  State<MapScreenPosition> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreenPosition> {
  // ============================================================
  // CONTROLADORES
  // ============================================================

  final GlobalKey _mapKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final PanelController _panelController = PanelController();

  Timer? _debounce;

  // Configuración del viaje y estimación de combustible.
  String _selectedVehicle = 'car';
  final TextEditingController _consumptionController = TextEditingController(
    text: '8',
  );
  final TextEditingController _fuelPriceController = TextEditingController(
    text: '7500',
  );

  // ============================================================
  // CONFIGURACIÓN DEL PANEL
  // ============================================================

  static const double _panelHeightClosed = 175;
  double _panelHeightOpen = 0;

  double _fabHeight = 140;

  static const double _initialFabHeight = 140;

  // ============================================================
  // COORDENADAS INICIALES: PIRIBEBUY
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
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    _searchController.text = provider.placeAddress.toString();
    _searchFocusNode.unfocus();
    _calculateRoute(provider);
    _openPanel();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Destino seleccionado en el mapa'),
          duration: Duration(seconds: 2),
        ),
      );
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

    _searchController.clear();
    provider.clearSearch();

    _searchFocusNode.unfocus();
  }

  // ============================================================
  // MAPBOX
  // ============================================================
  /*
  Future<void> _onMapCreated(
    MapboxMap mapboxMap,
    MapProvider provider,
  ) async {
    await provider.onMapCreated(mapboxMap);

    if (!mounted) return;

    // Posición inicial del mapa.
    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _initialLongitude,
            _initialLatitude,
          ),
        ),
        zoom: 13,
      ),
    );
    
  }
*/
  Future<void> _onMapCreated(MapboxMap mapboxMap, MapProvider provider) async {
    await provider.onMapCreated(mapboxMap);

    if (!mounted) return;

    // Registrar la interacción para seleccionar destinos tocando el mapa.
    mapboxMap.addInteraction(
      TapInteraction.onMap((gesture) {
        unawaited(_onMapTap(gesture, provider));
      }),
    );

    // Posición inicial del mapa.
    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(_initialLongitude, _initialLatitude),
        ),
        zoom: 13,
      ),
    );
  }
  // ============================================================
  // ABRIR PANEL
  // ============================================================

  void _openPanel() {
    if (_panelController.isAttached) {
      _panelController.open();
    }
  }

  // ============================================================
  // BOTÓN DE UBICACIÓN
  // ============================================================

  Future<void> _goToCurrentLocation(MapProvider provider) async {
    await provider.goToCurrentLocation();
  }

  //============================================================
  // OBTENER  COORDENADAS DESDE EL CENTRO DEL MAPA
  //============================================================

  Widget getVisibleRegion(
    MapProvider provider,
    MapboxMap? _mapboxMap,
    BuildContext context,
  ) {
    return TextButton(
      child: Text('Get Visible Region'),
      onPressed: () async {
        if (_mapboxMap != null) {
          _mapboxMap.getCameraState().then((currentCameraOptions) async {
            if (currentCameraOptions != null) {
              CameraOptions cameraOptions = CameraOptions(
                center: currentCameraOptions.center,
                padding: currentCameraOptions.padding,
                zoom: currentCameraOptions.zoom,
                bearing: currentCameraOptions.bearing,
                pitch: currentCameraOptions.pitch,
              );
              var visibleRegion = await _mapboxMap
                  ?.coordinateBoundsForCameraUnwrapped(cameraOptions);

              if (visibleRegion != null) {
                // Extract coordinates
                double north = visibleRegion.northeast.coordinates.lat
                    .toDouble();
                double east = visibleRegion.northeast.coordinates.lng
                    .toDouble();
                double south = visibleRegion.southwest.coordinates.lat
                    .toDouble();
                double west = visibleRegion.southwest.coordinates.lng
                    .toDouble();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "North: $north, East: $east, South: $south, West: $west",
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                    duration: Duration(seconds: 2),
                  ),
                );

                print("North: $north, East: $east, South: $south, West: $west");
              }
            }
          });
        }
      },
    );
  }

  // ============================================================

  // SELECCIONAR DIRECCIÓN
  // ============================================================

  Future<void> _selectDestination(MapProvider provider, dynamic item) async {
    _debounce?.cancel();

    await provider.selectSearchResult(item);

    if (!mounted) return;

    _searchController.text = item.name;
    _searchFocusNode.unfocus();

    // Contraer panel después de seleccionar destino.
    if (_panelController.isAttached) {
      _panelController.close();
    }
  }

  // ============================================================
  // CALCULAR RUTA
  // ============================================================

  Future<void> _calculateRoute(MapProvider provider) async {
    _searchFocusNode.unfocus();

    await provider.calculateRoute(
      profile: _selectedVehicle == 'bicycle'
          ? 'cycling'
          : _selectedVehicle == 'walking'
          ? 'walking'
          : 'driving',
    );

    if (!mounted) return;

    if (provider.currentRoute != null && _panelController.isAttached) {
      _panelController.close();
    }
  }

  Future<void> _confirmCenterLocation() async {
    final provider = context.read<MapProvider>();

    // Obtener el tamaño real del mapa.
    final renderObject = _mapKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final Size mapSize = renderObject.size as Size;

    // Obtener las coordenadas del centro de la cámara.
    await provider.selectCenterCoordinate(mapSize: mapSize);
  }

  // ============================================================
  // CONSTRUIR PANTALLA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    _panelHeightOpen = screenHeight * 0.80;

    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: Stack(
            alignment: Alignment.center,
            children: [
              MapWidget(key: _mapKey,  onMapCreated: (mapboxMap) {
                    _onMapCreated(mapboxMap, provider);
                  },),

              // Marcador fijo en el centro de la pantalla.
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 35),
                  child: Icon(
                    Icons.location_on,
                    size: 48,
                    color: Colors.red,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PANEL INFERIOR
  // ============================================================

  Widget _buildPanel(
    BuildContext context,
    MapProvider provider,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Material(
        color: theme.colorScheme.surface,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Indicador de panel.
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

            // Encabezado.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donde querés ir?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encontrá lugares y planificá tu recorrido',
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

            // ==================================================
            // BUSCADOR
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildSearchBox(context, provider),
            ),

            // ==================================================
            // RESULTADOS DE BÚSQUEDA
            // ==================================================
            if (provider.searchResults.isNotEmpty)
              _buildSearchResults(provider),

            const SizedBox(height: 18),

            // ==================================================
            // VEHÍCULO Y COSTOS
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildTripSettings(context),
            ),

            const SizedBox(height: 22),

            // ==================================================
            // ACCIONES RÁPIDAS
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Accesos rápidos',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _quickAction(
                      context,
                      icon: Icons.my_location,
                      label: 'Mi ubicación',
                      color: Colors.blue,
                      onTap: provider.loading
                          ? null
                          : () => _goToCurrentLocation(provider),
                    ),
                  ),
                  Expanded(
                    child: _quickAction(
                      context,
                      icon: Icons.route,
                      label: 'Calcular ruta',
                      color: Colors.green,
                      onTap:
                          provider.loading ||
                              provider.selectedDestination == null
                          ? null
                          : () => _calculateRoute(provider),
                    ),
                  ),
                  Expanded(
                    child: _quickAction(
                      context,
                      icon: Icons.delete_outline,
                      label: 'Limpiar',
                      color: Colors.orange,
                      onTap: provider.loading
                          ? null
                          : () {
                              provider.clearRoute();
                              provider.clearMarkers();
                              _clearSearch(provider);
                            },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // INFORMACIÓN DEL DESTINO
            // ==================================================
            if (provider.selectedDestination != null)
              _buildDestinationCard(context, provider),

            // ==================================================
            // INFORMACIÓN DE RUTA
            // ==================================================
            if (provider.currentRoute != null)
              _buildRouteCard(context, provider),

            const SizedBox(height: 30),

            // Información inferior.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geesly · Explorá nuevos lugares',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUSCADOR
  // ============================================================

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
        controller: _searchController,
        focusNode: _searchFocusNode,
        onTap: _openPanel,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar dirección o lugar',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () => _clearSearch(provider),
                  icon: const Icon(Icons.close),
                )
              : const Icon(Icons.tune, size: 21),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULTADOS DE BÚSQUEDA
  // ============================================================

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
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 55),
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

  // ============================================================
  // ACCIONES RÁPIDAS
  // ============================================================

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONFIGURACIÓN DEL VIAJE
  // ============================================================

  Widget _buildTripSettings(BuildContext context) {
    final theme = Theme.of(context);
    final isMotorized =
        _selectedVehicle == 'car' || _selectedVehicle == 'motorcycle';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: theme.colorScheme.primary),
              const SizedBox(width: 9),
              Text(
                'Configurar viaje',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedVehicle,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Medio de transporte',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.commute),
            ),
            items: const [
              DropdownMenuItem(value: 'car', child: Text('Automóvil')),
              DropdownMenuItem(value: 'motorcycle', child: Text('Motocicleta')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedVehicle = value;
                if (value == 'motorcycle') {
                  _consumptionController.text = '3';
                } else if (value == 'car') {
                  _consumptionController.text = '8';
                }
              });
            },
          ),
          if (isMotorized) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _consumptionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Consumo',
                      suffixText: 'L/100 km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _fuelPriceController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Precio combustible',
                      prefixText: 'Gs. ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _selectedVehicle == 'car'
                  ? 'Consumo de referencia: 8 litros cada 100 km.'
                  : 'Consumo de referencia: 3 litros cada 100 km.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Este medio no genera costo de combustible.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double? _numberFromController(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return double.tryParse(value);
  }

  String _formatGuaranies(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return 'Gs. ${buffer.toString()}';
  }

  // ============================================================
  // TARJETA DE DESTINO
  // ============================================================

  Widget _buildDestinationCard(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Destino seleccionado',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    provider.clearRoute();
                    _clearSearch(provider);
                  },
                  icon: const Icon(Icons.close),
                  tooltip: 'Quitar destino',
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.loading
                    ? null
                    : () => _calculateRoute(provider),
                icon: const Icon(Icons.directions),
                label: const Text('Calcular ruta desde mi ubicación'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA DE RUTA
  // ============================================================

  Widget _buildRouteCard(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);
    final route = provider.currentRoute!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ruta calculada',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar ruta',
                  onPressed: provider.loading ? null : provider.clearRoute,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _routeInformation(
                    context,
                    icon: Icons.straighten,
                    label: 'Distancia',
                    value: route.distanceText,
                  ),
                ),
                Expanded(
                  child: _routeInformation(
                    context,
                    icon: Icons.schedule,
                    label: 'Duración',
                    value: route.durationText,
                  ),
                ),
              ],
            ),

            if (_selectedVehicle == 'car' ||
                _selectedVehicle == 'motorcycle') ...[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),
              _buildFuelEstimate(context, provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFuelEstimate(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);
    final distanceKm =
        provider.currentLocation != null && provider.currentRoute != null
        ? provider.currentRoute!.distanceMeters / 1000
        : null;
    final consumption = _numberFromController(_consumptionController);
    final fuelPrice = _numberFromController(_fuelPriceController);

    final valid =
        distanceKm != null &&
        consumption != null &&
        fuelPrice != null &&
        distanceKm >= 0 &&
        consumption > 0 &&
        fuelPrice >= 0;

    final liters = valid ? distanceKm * consumption / 100 : null;
    final total = valid ? liters! * fuelPrice : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_gas_station, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Costo estimado del viaje',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!valid)
          Text(
            'Verificá la distancia, el consumo y el precio del combustible.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Combustible estimado', style: theme.textTheme.bodyMedium),
              Text('${liters!.toStringAsFixed(2)} litros'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Precio por litro', style: theme.textTheme.bodyMedium),
              Text(_formatGuaranies(fuelPrice)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total aproximado en combustible',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatGuaranies(total!),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Estimación orientativa. No incluye peajes, estacionamiento '
            'ni variaciones de consumo por tráfico o condiciones del camino.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _routeInformation(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(MapProvider provider) {
    return Material(
      elevation: 5,
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                provider.clearSearch();
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
