import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxConfig {
  MapboxConfig._();

  static const accessToken =
      "pk.eyJ1IjoicmlmYXJjYSIsImEiOiJjbWpyb2VncWY0ZDYwM2Vvd3lmaWp4M3lpIn0.QqYIceUri_BUkPBvS_kdwQ";

  static void initialize() {
    if (accessToken.isEmpty) {
      throw StateError(
        'Falta ACCESS_TOKEN. Ejecutá Flutter con --dart-define=ACCESS_TOKEN=pk...',
      );
    }
    MapboxOptions.setAccessToken(accessToken);
  }
}
