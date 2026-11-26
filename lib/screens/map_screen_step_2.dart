import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:geesly/components/MenuNeoGlassNavigationBar.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../providers/map_provider.dart';
import '../components/vehicle_selection.dart';
import '../state/trip_box.dart';

class MapScreenStep2 extends StatefulWidget {
  final VoidCallback? onBackToStep1;
  final VoidCallback? onNextStep3;

  const MapScreenStep2({
    super.key,
    this.onBackToStep1,
    this.onNextStep3,
  });

  @override
  State<MapScreenStep2> createState() => _MapScreenStep2State();
}

class _MapScreenStep2State extends State<MapScreenStep2> {
  final PanelController _panelController = PanelController();
  MapboxMap? _mapboxMap;

  bool _routeRequested = false;

  static const double _panelHeightClosed = 320;
  double _panelHeightOpen = 460;

  double _fabHeight = 245;
  static const double _initialFabHeight = 245;

  @override
  void initState() {
    super.initState();
    _fabHeight = _initialFabHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _traceRouteFromTripBox();
    });
  }

  Future<void> _traceRouteFromTripBox() async {
    if (!mounted) return;

    final tripBox = context.read<TripBox>();
    final mapProvider = context.read<MapProvider>();

    final origin = tripBox.origin;
    final destination = tripBox.destination;

    if (origin == null || destination == null) {
      _handleBackToStep1(tripBox);
      return;
    }

    setState(() => _routeRequested = true);

    await mapProvider.calculateRoute(profile: 'driving');

    if (!mounted) return;

    final double distanceKm = _resolveDistanceKm(mapProvider, origin, destination);
    final double durationMin = _resolveDurationMinutes(mapProvider, distanceKm);

    tripBox.setRouteCalculation(
      distanceKm: distanceKm,
      durationMinutes: durationMin,
    );

    if (_panelController.isAttached) {
      _panelController.open();
    }
  }

  double _resolveDistanceKm(
    MapProvider mapProvider,
    TripCoordinates origin,
    TripCoordinates destination,
  ) {
    final dynamic providerDistance = _tryGetRouteDistance(mapProvider);
    if (providerDistance is num && providerDistance > 0) {
      return providerDistance.toDouble();
    }

    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(destination.lat - origin.lat);
    final double dLng = _degToRad(destination.lng - origin.lng);

    final double sinDLat = _sin(dLat / 2);
    final double sinDLng = _sin(dLng / 2);
    final double haversineA = sinDLat * sinDLat +
        _cos(_degToRad(origin.lat)) *
            _cos(_degToRad(destination.lat)) *
            sinDLng *
            sinDLng;
    final double c = 2 * _atan2(_sqrt(haversineA), _sqrt(1 - haversineA));
    final double straightKm = earthRadiusKm * c;

    return (straightKm * 1.25).clamp(0.5, 500.0);
  }

  double _resolveDurationMinutes(MapProvider mapProvider, double distanceKm) {
    final dynamic providerDuration = _tryGetRouteDuration(mapProvider);
    if (providerDuration is num && providerDuration > 0) {
      return providerDuration.toDouble();
    }
    return ((distanceKm / 28.0) * 60).clamp(2.0, 600.0);
  }

  dynamic _tryGetRouteDistance(MapProvider provider) {
    try {
      return (provider as dynamic).routeDistanceKm ??
          (provider as dynamic).routeDistance;
    } catch (_) {
      return null;
    }
  }

  dynamic _tryGetRouteDuration(MapProvider provider) {
    try {
      return (provider as dynamic).routeDurationMinutes ??
          (provider as dynamic).routeDuration;
    } catch (_) {
      return null;
    }
  }

  double _degToRad(double deg) => deg * 0.017453292519943295;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);

  double _taylorSin(double x) {
    double term = x;
    double sum = x;
    for (int i = 1; i <= 6; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      sum += term;
    }
    return sum;
  }

  double _sqrt(double val) {
    if (val <= 0) return 0;
    double guess = val / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + val / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atan(double z) {
    if (z.abs() <= 1) {
      double term = z;
      double sum = z;
      for (int i = 1; i <= 8; i++) {
        term *= -z * z;
        sum += term / (2 * i + 1);
      }
      return sum;
    }
    return (z > 0 ? 1.5707963267948966 : -1.5707963267948966) - _atan(1 / z);
  }

  List<VehicleOption> _buildVehicleOptions(TripBox tripBox) {
    final double distanceKm = tripBox.distanceKm ?? 3.0;
    final double etaBaseMin = (tripBox.durationMinutes ?? 10.0).clamp(2.0, 90.0);

    const double baseMoto = 4500;
    const double perKmMoto = 1800;

    const double baseEcon = 6500;
    const double perKmEcon = 3200;

    const double basePrem = 11000;
    const double perKmPrem = 5500;

    final double priceMoto = baseMoto + (distanceKm * perKmMoto);
    final double priceEcon = baseEcon + (distanceKm * perKmEcon);
    final double pricePrem = basePrem + (distanceKm * perKmPrem);

    final String etaMoto = '${(etaBaseMin * 0.75).round().clamp(1, 99)} min';
    final String etaEcon = '${etaBaseMin.round().clamp(1, 99)} min';
    final String etaPrem = '${(etaBaseMin * 1.1).round().clamp(1, 99)} min';

    return [
      VehicleOption(
        id: 'moto',
        name: 'Moto',
        subtitle: 'Más rápido entre el tráfico · ${distanceKm.toStringAsFixed(1)} km',
        eta: etaMoto,
        price: priceMoto,
        capacity: 1,
        icon: Icons.two_wheeler_rounded,
        isPromo: true,
      ),
      VehicleOption(
        id: 'economico',
        name: 'Económico',
        subtitle: 'Auto estándar · ${distanceKm.toStringAsFixed(1)} km',
        eta: etaEcon,
        price: priceEcon,
        capacity: 4,
        icon: Icons.directions_car_filled_rounded,
      ),
      VehicleOption(
        id: 'premium',
        name: 'Premium',
        subtitle: 'Mayor confort y espacio · ${distanceKm.toStringAsFixed(1)} km',
        eta: etaPrem,
        price: pricePrem,
        capacity: 4,
        icon: Icons.local_taxi_rounded,
      ),
    ];
  }

  Future<void> _onMapCreated(
    MapboxMap mapboxMap,
    MapProvider mapProvider,
    TripBox tripBox,
  ) async {
    _mapboxMap = mapboxMap;
    await mapProvider.onMapCreated(mapboxMap);
    if (!mounted) return;

    if (tripBox.origin != null) {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(tripBox.origin!.lng, tripBox.origin!.lat),
          ),
          zoom: 12.5,
        ),
      );
    }

    if (!_routeRequested) {
      await _traceRouteFromTripBox();
    }
  }

  void _handleBackToStep1(TripBox tripBox) {
    tripBox.backToStep1();
    widget.onBackToStep1?.call();
  }

  void _handleConfirmVehicle(TripBox tripBox, VehicleOption vehicle) {
    tripBox.confirmVehicleAndSearchDriver(vehicle);
    widget.onNextStep3?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    _panelHeightOpen = (screenHeight * 0.62).clamp(420.0, 560.0);

    return Consumer2<MapProvider, TripBox>(
      builder: (context, mapProvider, tripBox, _) {
        final options = _buildVehicleOptions(tripBox);

        return Scaffold(
          bottomNavigationBar: MenuNeoGlassNagivationBar(selectedItem: 1),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('geesly-map-step-2'),
                  onMapCreated: (mapboxMap) {
                    _onMapCreated(mapboxMap, mapProvider, tripBox);
                  },
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
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: _buildStepHeadeBanner(context, tripBox),
              ),
              SlidingUpPanel(
                controller: _panelController,
                maxHeight: _panelHeightOpen,
                minHeight: _panelHeightClosed,
                parallaxEnabled: true,
                parallaxOffset: 0.1,
                backdropEnabled: false,
                panelSnapping: true,
                defaultPanelState: PanelState.OPEN,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                body: const SizedBox.expand(),
                panelBuilder: (_) {
                  return VehicleSelectionWidget(
                    options: options,
                    currencySymbol: 'Gs.',
                    initialSelectedId: tripBox.selectedVehicle?.id ?? 'economico',
                    onVehicleSelected: (vehicle) {},
                    onConfirmPressed: (selectedVehicle) {
                      _handleConfirmVehicle(tripBox, selectedVehicle);
                    },
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
                bottom: _fabHeight,
                child: SafeArea(
                  child: FloatingActionButton(
                    heroTag: 'step2-recenter-fab',
                    elevation: 5,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: mapProvider.loading
                        ? null
                        : () => _traceRouteFromTripBox(),
                    child: const Icon(Icons.alt_route, size: 23),
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

  Widget _buildStepHeadeBanner(BuildContext context, TripBox tripBox) {
    final theme = Theme.of(context);
    final originLabel = tripBox.origin?.label ?? 'Origen';
    final destLabel = tripBox.destination?.label ?? 'Destino';
    final kmText = tripBox.distanceKm != null
        ? '${tripBox.distanceKm!.toStringAsFixed(1)} km'
        : 'Calculando...';
    final minText = tripBox.durationMinutes != null
        ? '${tripBox.durationMinutes!.round()} min'
        : '';

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cambiar origen o destino',
              onPressed: () => _handleBackToStep1(tripBox),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paso 2 de 3 · $kmText${minText.isNotEmpty ? ' · $minText' : ''}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$originLabel → $destLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
