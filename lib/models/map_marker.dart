import 'map_location.dart';

class MapMarker {
  const MapMarker({
    required this.id,
    required this.title,
    required this.location,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final MapLocation location;
}
