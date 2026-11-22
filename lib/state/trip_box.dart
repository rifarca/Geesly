import 'package:flutter/material.dart';
import '../components/vehicle_selection.dart';

enum TripStep {
  step1Places,
  step2RouteVehicle,
  step3FindingDriver,
}

enum PlaceTarget {
  origin,
  destination,
}

class TripCoordinates {
  final double lat;
  final double lng;
  final String label;

  const TripCoordinates({
    required this.lat,
    required this.lng,
    required this.label,
  });

  TripCoordinates copyWith({
    double? lat,
    double? lng,
    String? label,
  }) {
    return TripCoordinates(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
    );
  }
}

class TripBox extends ChangeNotifier {
  TripStep _step = TripStep.step1Places;
  PlaceTarget _activeTarget = PlaceTarget.destination;

  TripCoordinates? _origin;
  TripCoordinates? _destination;

  double? _distanceKm;
  double? _durationMinutes;
  VehicleOption? _selectedVehicle;

  TripStep get step => _step;
  PlaceTarget get activeTarget => _activeTarget;
  TripCoordinates? get origin => _origin;
  TripCoordinates? get destination => _destination;
  double? get distanceKm => _distanceKm;
  double? get durationMinutes => _durationMinutes;
  VehicleOption? get selectedVehicle => _selectedVehicle;

  bool get canProceedToStep2 => _origin != null && _destination != null;

  void setActiveTarget(PlaceTarget target) {
    if (_activeTarget == target) return;
    _activeTarget = target;
    notifyListeners();
  }

  void setOrigin(TripCoordinates value) {
    _origin = value;
    _distanceKm = null;
    _durationMinutes = null;
    notifyListeners();
  }

  void setDestination(TripCoordinates value) {
    _destination = value;
    _distanceKm = null;
    _durationMinutes = null;
    notifyListeners();
  }

  void clearOrigin() {
    _origin = null;
    _distanceKm = null;
    _durationMinutes = null;
    notifyListeners();
  }

  void clearDestination() {
    _destination = null;
    _distanceKm = null;
    _durationMinutes = null;
    notifyListeners();
  }

  void setPlaceForActiveTarget(TripCoordinates value) {
    if (_activeTarget == PlaceTarget.origin) {
      setOrigin(value);
      _activeTarget = PlaceTarget.destination;
    } else {
      setDestination(value);
    }
    notifyListeners();
  }

  void goToStep2() {
    if (!canProceedToStep2) return;
    _step = TripStep.step2RouteVehicle;
    notifyListeners();
  }

  void setRouteCalculation({
    required double distanceKm,
    required double durationMinutes,
  }) {
    _distanceKm = distanceKm;
    _durationMinutes = durationMinutes;
    notifyListeners();
  }

  void confirmVehicleAndSearchDriver(VehicleOption vehicle) {
    _selectedVehicle = vehicle;
    _step = TripStep.step3FindingDriver;
    notifyListeners();
  }

  void backToStep2() {
    _step = TripStep.step2RouteVehicle;
    notifyListeners();
  }

  void backToStep1() {
    _distanceKm = null;
    _durationMinutes = null;
    _selectedVehicle = null;
    _step = TripStep.step1Places;
    notifyListeners();
  }

  void resetAll() {
    _origin = null;
    _destination = null;
    _distanceKm = null;
    _durationMinutes = null;
    _selectedVehicle = null;
    _activeTarget = PlaceTarget.destination;
    _step = TripStep.step1Places;
    notifyListeners();
  }
}
