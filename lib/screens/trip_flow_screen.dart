import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/trip_box.dart';
import 'map_screen_step_1.dart';
import 'map_screen_step_2.dart';
import 'map_screen_step_3.dart';

class TripFlowScreen extends StatelessWidget {
  final TripBox? tripBox;

  const TripFlowScreen({
    super.key,
    this.tripBox,
  });

  @override
  Widget build(BuildContext context) {
    final box = tripBox;

    if (box != null) {
      return ChangeNotifierProvider<TripBox>.value(
        value: box,
        child: const _TripFlowView(),
      );
    }

    return ChangeNotifierProvider<TripBox>(
      create: (_) => TripBox(),
      child: const _TripFlowView(),
    );
  }
}

class _TripFlowView extends StatelessWidget {
  const _TripFlowView();

  @override
  Widget build(BuildContext context) {
    return Consumer<TripBox>(
      builder: (context, tripBox, _) {
        final Widget activeStepWidget;

        switch (tripBox.step) {
          case TripStep.step1Places:
            activeStepWidget = MapScreenStep1(
              key: const ValueKey('trip-step-1'),
              onNextStep: () {
                debugPrint(
                  'Paso 1 -> Paso 2 | Origen: ${tripBox.origin?.label}, '
                  'Destino: ${tripBox.destination?.label}',
                );
              },
            );
            break;

          case TripStep.step2RouteVehicle:
            activeStepWidget = MapScreenStep2(
              key: const ValueKey('trip-step-2'),
              onBackToStep1: () {
                debugPrint('Paso 2 -> Paso 1 (editar lugares)');
              },
              onNextStep3: () {
                debugPrint(
                  'Paso 2 -> Paso 3 | Vehículo: ${tripBox.selectedVehicle?.name}',
                );
              },
            );
            break;

          case TripStep.step3FindingDriver:
            activeStepWidget = MapScreenStep3(
              key: const ValueKey('trip-step-3'),
              onBackToStep2: () {
                debugPrint('Paso 3 -> Paso 2 (cambiar vehículo)');
              },
              onCancelTrip: () {
                debugPrint('Paso 3 -> Paso 1 (viaje cancelado y box reseteado)');
              },
            );
            break;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleAndroidBackButton(context, tripBox);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: activeStepWidget,
          ),
        );
      },
    );
  }

  void _handleAndroidBackButton(BuildContext context, TripBox tripBox) {
    switch (tripBox.step) {
      case TripStep.step3FindingDriver:
        tripBox.backToStep2();
        break;
      case TripStep.step2RouteVehicle:
        tripBox.backToStep1();
        break;
      case TripStep.step1Places:
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
        break;
    }
  }
}
