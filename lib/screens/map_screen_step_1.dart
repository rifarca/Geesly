import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geesly/components/MenuNeoGlassNavigationBar.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../providers/map_provider.dart';
import '../state/trip_box.dart';

class MapScreenStep1 extends StatefulWidget {
  final VoidCallback? onNextStep;

  const MapScreenStep1({
    super.key,
    this.onNextStep,
  });

  @override
  State<MapScreenStep1> createState() => _MapScreenStep1State();
}

class _MapScreenStep1State extends State<MapScreenStep1> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  final PanelController _panelController = PanelController();

  Timer? _debounce;
  MapboxMap? _mapboxMap;

  bool _isSelectingByCenter = false;

  static const double _panelHeightClosed = 235;
  double _panelHeightOpen = 0;

  double _fabHeight = 250;
  static const double _initialFabHeight = 250;

  static const double _initialLatitude = -25.4783;
  static const double _initialLongitude = -57.0544;

  @override
  void initState() {
    super.initState();
    _fabHeight = _initialFabHeight;

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus && mounted) {
        context.read<TripBox>().setActiveTarget(PlaceTarget.origin);
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus && mounted) {
        context.read<TripBox>().setActiveTarget(PlaceTarget.destination);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateFromBoxOrInitLocation();
    });
  }

  Future<void> _hydrateFromBoxOrInitLocation() async {
    final tripBox = context.read<TripBox>();
    final mapProvider = context.read<MapProvider>();

    if (tripBox.origin != null) {
      _originController.text = tripBox.origin!.label;
    } else {
      await _useCurrentLocationAsOrigin(mapProvider, tripBox, moveCamera: true);
    }

    if (tripBox.destination != null && mounted) {
      _destinationController.text = tripBox.destination!.label;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocationAsOrigin(
    MapProvider mapProvider,
    TripBox tripBox, {
    bool moveCamera = false,
  }) async {
    if (moveCamera || mapProvider.currentLocation == null) {
      await mapProvider.goToCurrentLocation();
    }

    final loc = mapProvider.currentLocation;
    if (loc != null && mounted) {
      final lat = (loc.latitude as num).toDouble();
      final lng = (loc.longitude as num).toDouble();

      const label = 'Mi ubicación actual';
      tripBox.setOrigin(TripCoordinates(lat: lat, lng: lng, label: label));
      _originController.text = label;
    }
  }

  Future<void> _saveCoordinateToTripBox({
    required double lat,
    required double lng,
    required String label,
    required TripBox tripBox,
  }) async {
    final coord = TripCoordinates(lat: lat, lng: lng, label: label);

    if (tripBox.activeTarget == PlaceTarget.origin) {
      tripBox.setOrigin(coord);
      _originController.text = label;
      tripBox.setActiveTarget(PlaceTarget.destination);
    } else {
      tripBox.setDestination(coord);
      _destinationController.text = label;
    }
  }

  Future<void> _onMapTap(
    MapContentGestureContext gesture,
    MapProvider mapProvider,
    TripBox tripBox,
  ) async {
    final position = gesture.point.coordinates;
    final lat = position.lat.toDouble();
    final lng = position.lng.toDouble();

    await mapProvider.selectMapCoordinate(latitude: lat, longitude: lng);
    if (!mounted) return;

    final resolvedLabel = (mapProvider.placeAddress != null &&
            mapProvider.placeAddress!.toString().trim().isNotEmpty)
        ? mapProvider.placeAddress.toString()
        : 'Punto (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

    _debounce?.cancel();
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    await _saveCoordinateToTripBox(
      lat: lat,
      lng: lng,
      label: resolvedLabel,
      tripBox: tripBox,
    );

    _openPanel();
  }

  Future<void> _onMapCreated(
    MapboxMap mapboxMap,
    MapProvider mapProvider,
    TripBox tripBox,
  ) async {
    _mapboxMap = mapboxMap;
    await mapProvider.onMapCreated(mapboxMap);
    if (!mounted) return;

    mapboxMap.addInteraction(
      TapInteraction.onMap((gesture) {
        unawaited(_onMapTap(gesture, mapProvider, tripBox));
      }),
    );

    if (tripBox.origin != null) {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(tripBox.origin!.lng, tripBox.origin!.lat),
          ),
          zoom: 13.5,
        ),
      );
    } else if (mapProvider.currentLocation == null) {
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

  void _startCenterCapture(PlaceTarget target, TripBox tripBox) {
    tripBox.setActiveTarget(target);
    if (_panelController.isAttached) {
      _panelController.close();
    }
    setState(() {
      _isSelectingByCenter = true;
    });
  }

  Future<void> _confirmCenterLocation(
    MapProvider mapProvider,
    TripBox tripBox,
  ) async {
    if (_mapboxMap == null) return;

    final cameraState = await _mapboxMap!.getCameraState();
    final coords = cameraState.center.coordinates;
    final lng = coords.lng.toDouble();
    final lat = coords.lat.toDouble();

    await mapProvider.selectMapCoordinate(latitude: lat, longitude: lng);
    if (!mounted) return;

    final label = (mapProvider.placeAddress != null &&
            mapProvider.placeAddress!.trim().isNotEmpty)
        ? mapProvider.placeAddress!
        : 'Ubicación central';

    await _saveCoordinateToTripBox(
      lat: lat,
      lng: lng,
      label: label,
      tripBox: tripBox,
    );

    setState(() {
      _isSelectingByCenter = false;
    });

    _openPanel();
  }

  void _onSearchChanged(String value, MapProvider mapProvider) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      mapProvider.search(value);
    });
  }

  Future<void> _selectSearchResult(
    MapProvider mapProvider,
    TripBox tripBox,
    dynamic item,
  ) async {
    _debounce?.cancel();
    await mapProvider.selectSearchResult(item);
    if (!mounted) return;

    final selectedDest = mapProvider.selectedDestination;
    final double? lat = (selectedDest?.latitude as num?)?.toDouble() ??
        (item.latitude as num?)?.toDouble();
    final double? lng = (selectedDest?.longitude as num?)?.toDouble() ??
        (item.longitude as num?)?.toDouble();

    if (lat != null && lng != null) {
      final String name = (item.name ?? 'Lugar seleccionado').toString();
      await _saveCoordinateToTripBox(
        lat: lat,
        lng: lng,
        label: name,
        tripBox: tripBox,
      );
    }

    mapProvider.clearSearch();
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();
  }

  void _openPanel() {
    if (_panelController.isAttached) {
      _panelController.open();
    }
  }

  void _goToNextStep(TripBox tripBox) {
    if (!tripBox.canProceedToStep2) return;
    tripBox.goToStep2();
    widget.onNextStep?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    _panelHeightOpen = screenHeight * 0.78;

    return Consumer2<MapProvider, TripBox>(
      builder: (context, mapProvider, tripBox, _) {
        return Scaffold(
          bottomNavigationBar: MenuNeoGlassNagivationBar(selectedItem: 1),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('geesly-map-step-1'),
                  onMapCreated: (mapboxMap) {
                    _onMapCreated(mapboxMap, mapProvider, tripBox);
                  },
                ),
              ),
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
                    onPressed: () =>
                        _confirmCenterLocation(mapProvider, tripBox),
                    icon: const Icon(Icons.check, color: Colors.greenAccent),
                    label: Text(
                      tripBox.activeTarget == PlaceTarget.origin
                          ? 'Fijar como origen'
                          : 'Fijar como destino',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
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
                    return _buildStep1Panel(
                      context,
                      mapProvider,
                      tripBox,
                      scrollController,
                    );
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
              Positioned(
                right: 18,
                bottom: _isSelectingByCenter ? 40 : _fabHeight,
                child: SafeArea(
                  child: FloatingActionButton(
                    heroTag: 'step1-gps-fab',
                    elevation: 5,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: mapProvider.loading
                        ? null
                        : () => _useCurrentLocationAsOrigin(
                              mapProvider,
                              tripBox,
                              moveCamera: true,
                            ),
                    child: const Icon(Icons.my_location, size: 23),
                  ),
                ),
              ),
              if (mapProvider.loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep1Panel(
    BuildContext context,
    MapProvider mapProvider,
    TripBox tripBox,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                children: [
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paso 1 de 3 · Origen y destino',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '¿A dónde vamos?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.edit_location_alt,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          tripBox.activeTarget == PlaceTarget.origin
                              ? 'Editando origen'
                              : 'Editando destino',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPlaceField(
                    context: context,
                    controller: _originController,
                    focusNode: _originFocusNode,
                    hint: 'Selecciona el origen',
                    icon: Icons.trip_origin,
                    iconColor: Colors.blue,
                    isActive: tripBox.activeTarget == PlaceTarget.origin,
                    onTap: () {
                      tripBox.setActiveTarget(PlaceTarget.origin);
                      _openPanel();
                    },
                    onChanged: (val) => _onSearchChanged(val, mapProvider),
                    onClear: () {
                      _originController.clear();
                      tripBox.clearOrigin();
                    },
                    onPickCenter: () =>
                        _startCenterCapture(PlaceTarget.origin, tripBox),
                  ),
                  const SizedBox(height: 10),
                  _buildPlaceField(
                    context: context,
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    hint: 'Selecciona el destino',
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    isActive: tripBox.activeTarget == PlaceTarget.destination,
                    onTap: () {
                      tripBox.setActiveTarget(PlaceTarget.destination);
                      _openPanel();
                    },
                    onChanged: (val) => _onSearchChanged(val, mapProvider),
                    onClear: () {
                      _destinationController.clear();
                      tripBox.clearDestination();
                    },
                    onPickCenter: () =>
                        _startCenterCapture(PlaceTarget.destination, tripBox),
                  ),
                  if (mapProvider.searchResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: mapProvider.searchResults.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 52),
                        itemBuilder: (context, index) {
                          final item = mapProvider.searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              radius: 17,
                              child: Icon(Icons.place_outlined, size: 18),
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
                            trailing: const Icon(Icons.chevron_right),
                            onTap: mapProvider.loading
                                ? null
                                : () => _selectSearchResult(
                                      mapProvider,
                                      tripBox,
                                      item,
                                    ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildSavedCoordsSummary(context, tripBox),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: tripBox.canProceedToStep2
                        ? () => _goToNextStep(tripBox)
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Continuar al trazado y tarifas',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required VoidCallback onPickCenter,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onTap: onTap,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: iconColor),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 20),
                ),
              IconButton(
                tooltip: 'Fijar con el centro del mapa',
                onPressed: onPickCenter,
                icon: const Icon(Icons.location_pin, size: 20),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCoordsSummary(BuildContext context, TripBox tripBox) {
    final theme = Theme.of(context);
    final orig = tripBox.origin;
    final dest = tripBox.destination;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coordenadas guardadas en TripBox',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            orig != null
                ? 'Origen: ${orig.label} (${orig.lat.toStringAsFixed(4)}, ${orig.lng.toStringAsFixed(4)})'
                : 'Origen: pendiente',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            dest != null
                ? 'Destino: ${dest.label} (${dest.lat.toStringAsFixed(4)}, ${dest.lng.toStringAsFixed(4)})'
                : 'Destino: pendiente',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
