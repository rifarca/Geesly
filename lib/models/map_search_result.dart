import 'map_location.dart';

class MapSearchResult {
  const MapSearchResult({
    required this.id,
    required this.name,
    required this.address,
    this.location,
  });

  final String id;
  final String name;
  final String address;
  final MapLocation? location;
}
