import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geesly/components/MenuNeoGlassNavigationBar.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../providers/map_provider.dart';
import '../state/trip_box.dart';

class MapScreenStep3 extends StatefulWidget {
  final VoidCallback? onBackToStep2;
  final VoidCallback? onCancelTrip;

  const MapScreenStep3({
    super.key,
    this.onBackToStep2,
    this.onCancelTrip,
  });

  @override
  State<MapScreenStep3> createState() => _MapScreenStep3State();
}

class _MapScreenStep3State extends State<MapScreenStep3>
    with SingleTickerProviderStateMixin {
  final PanelController _panelController = PanelController();
  late final AnimationController _radarController;

  Timer? _searchTimer;
  int _elapsedSeconds = 0;
  bool _driverFound = false;

  static const double _panelHeightClosed = 240;
  double _panelHeightOpen = 390;

  double _fabHeight = 255;
  static const double _initialFabHeight = 255;

  @override
  void initState() {
    super.initState();
    _fabHeight = _initialFabHeight;

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startSearchingDriver();
  }

  void _startSearchingDriver() {
    _searchTimer?.cancel();
    _elapsedSeconds = 0;
    _driverFound = false;

    if (!_radarController.isAnimating) {
      _radarController.repeat();
    }

    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 6) {
          _driverFound = true;
          _radarController.stop();
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  String _formatGuaranies(double price) {
    final intVal = price.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Gs. ${intVal.replaceAllMapped(reg, (Match m) => '${m[1]}.')}';
  }

  void _handleChangeVehicle(TripBox tripBox) {
    _searchTimer?.cancel();
    tripBox.backToStep2();
    widget.onBackToStep2?.call();
  }

  void _handleCancelTrip(TripBox tripBox) {
    _searchTimer?.cancel();
    tripBox.resetAll();
    widget.onCancelTrip?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    _panelHeightOpen = (screenHeight * 0.52).clamp(360.0, 440.0);

    return Consumer2<MapProvider, TripBox>(
      builder: (context, mapProvider, tripBox, _) {
        final vehicle = tripBox.selectedVehicle;

        return Scaffold(
          bottomNavigationBar: MenuNeoGlassNagivationBar(selectedItem: 1),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('geesly-map-step-3'),
                  onMapCreated: (mapboxMap) async {
                    await mapProvider.onMapCreated(mapboxMap);
                    if (tripBox.origin != null) {
                      await mapboxMap.setCamera(
                        CameraOptions(
                          center: Point(
                            coordinates: Position(
                              tripBox.origin!.lng,
                              tripBox.origin!.lat,
                            ),
                          ),
                          zoom: 13,
                        ),
                      );
                    }
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
                child: _buildStatusBanner(context, tripBox),
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
                panelBuilder: (scrollController) {
                  return _buildStep3Panel(
                    context,
                    tripBox,
                    vehicle,
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
                bottom: _fabHeight,
                child: SafeArea(
                  child: FloatingActionButton(
                    heroTag: 'step3-retry-fab',
                    elevation: 5,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: _startSearchingDriver,
                    child: const Icon(Icons.refresh, size: 23),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(BuildContext context, TripBox tripBox) {
    final theme = Theme.of(context);
    final originLabel = tripBox.origin?.label ?? 'Origen';
    final destLabel = tripBox.destination?.label ?? 'Destino';

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _driverFound
                  ? 'Paso 3 de 3 · ¡Conductor asignado!'
                  : 'Paso 3 de 3 · Buscando conductor (${_elapsedSeconds}s)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _driverFound ? Colors.green.shade700 : theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
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
    );
  }

  Widget _buildStep3Panel(
    BuildContext context,
    TripBox tripBox,
    dynamic vehicle,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);
    final String vehicleName = vehicle?.name ?? 'Vehículo';
    final double price = (vehicle?.price as num?)?.toDouble() ?? 0;
    final IconData vehicleIcon = vehicle?.icon ?? Icons.directions_car_filled_rounded;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!_driverFound)
                              AnimatedBuilder(
                                animation: _radarController,
                                builder: (context, _) {
                                  return Transform.scale(
                                    scale: 0.7 + (_radarController.value * 0.45),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.colorScheme.primary.withValues(
                                          alpha: (1 - _radarController.value) * 0.35,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _driverFound
                                    ? Colors.green.shade100
                                    : theme.colorScheme.primaryContainer,
                              ),
                              child: Icon(
                                _driverFound ? Icons.check_circle : vehicleIcon,
                                color: _driverFound
                                    ? Colors.green.shade800
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverFound
                                  ? 'Driver en camino'
                                  : 'Conectando con $vehicleName...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _driverFound
                                  ? 'Carlos Benítez · Toyota Corolla · Llega en 3 min'
                                  : 'Verificando disponibilidad cerca de tu origen',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _summaryRow(
                          context,
                          label: 'Categoría',
                          value: vehicleName,
                        ),
                        const SizedBox(height: 6),
                        _summaryRow(
                          context,
                          label: 'Distancia estimada',
                          value: tripBox.distanceKm != null
                              ? '${tripBox.distanceKm!.toStringAsFixed(1)} km'
                              : '—',
                        ),
                        const SizedBox(height: 6),
                        _summaryRow(
                          context,
                          label: 'Tarifa estimada',
                          value: _formatGuaranies(price),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleChangeVehicle(tripBox),
                        style: OutlinedButton.styleFrom(
                     //    minimumSize: Size( width: double.infinity, height: 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cambiar vehículo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleCancelTrip(tripBox),
                        style: ElevatedButton.styleFrom(
                        //  minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar viaje'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
