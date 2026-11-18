import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'; 
import '../components/BottomNavigationBarComponent.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; 
import 'package:sliding_up_panel/sliding_up_panel.dart';

class MapboxScreen extends StatefulWidget {
  const MapboxScreen({super.key});

  @override
  State<MapboxScreen> createState() => _MapboxScreenState();
}

class _MapboxScreenState extends State<MapboxScreen> {
  final double _initFabHeight = 120.0;
  double _fabHeight = 0;
  double _panelHeightOpen = 0;
  double _panelHeightClosed = 95.0;

  // Coordenadas exactas de Piribebuy, Paraguay
  final LatLng _piribebuyCoords = const LatLng(-25.4783, -57.0544);

  // Controlador para interactuar con flutter_map
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fabHeight = _initFabHeight;
  }

  // Widget del mapa configurado con OpenStreetMap apuntando a Piribebuy
  Widget _body() {
     final MapWidget mapWidget =
        MapWidget(key: ValueKey("mapWidget"), onMapCreated: _onMapCreated);

    final List<Widget> listViewChildren = <Widget>[];

    listViewChildren.addAll(
      <Widget>[
        _getPermission(),
        _show(),
        _hide(),
        _switchLocationPuck2D(),
        _switchLocationPuck3D_duck(),
        _switchLocationPuck3D_car(),
        _switchPuckScale(),
        _showBearing(),
        _hideBearing(),
        _showAccuracy(),
        _hideAccuracy(),
        _showPulsing(),
        _hidePulsing(),
        _switchAccuracyColor(),
        _switchPulsingColor(),
        _switchAccuracyBorderColor(),
        _getSettings(),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 400,
              child: mapWidget),
        ),
        Expanded(
          child: ListView(
            children: listViewChildren,
          ),
        )
      ],
    );
  
  }

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * .80;

    return Scaffold(
      bottomNavigationBar: BottomNavigationBarComponent(item: 1),
      body: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          SlidingUpPanel(
            maxHeight: _panelHeightOpen,
            minHeight: _panelHeightClosed,
            parallaxEnabled: true,
            parallaxOffset: .5,
            body: _body(), 
            panelBuilder: (sc) => _panel(sc),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18.0),
              topRight: Radius.circular(18.0),
            ),
            onPanelSlide: (double pos) => setState(() {
              _fabHeight =
                  pos * (_panelHeightOpen - _panelHeightClosed) +
                  _initFabHeight;
            }),
          ),

          // El botón flotante (FAB)
          Positioned(
            right: 20.0,
            bottom: _fabHeight,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                // Centra el mapa de nuevo en Piribebuy al hacer clic
                _mapController.move(_piribebuyCoords, 14.0);
              },
              child: Icon(
                Icons.gps_fixed,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          Positioned(
            top: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).padding.top,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Título flotante encima del SlidingUpPanel
          Positioned(
            top: 52.0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 18.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, .25),
                    blurRadius: 16.0,
                  ),
                ],
              ),
              child: const Text(
                "SlidingUpPanel Example",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(ScrollController sc) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(
        controller: sc,
        children: <Widget>[
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment:  MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18.0),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                "Explore Piribebuy",
                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 24.0),
              ),
            ],
          ),
          const SizedBox(height: 36.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _button("Popular", Icons.favorite, Colors.blue),
              _button("Food", Icons.restaurant, Colors.red),
              _button("Events", Icons.event, Colors.amber),
              _button("More", Icons.more_horiz, Colors.green),
            ],
          ),
          const SizedBox(height: 36.0),
          Container(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text("Images", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    CachedNetworkImage(
                      imageUrl:
                          "https://fineartamerica.com",
                      height: 120.0,
                      width: (MediaQuery.of(context).size.width - 48) / 2 - 2,
                      fit: BoxFit.cover,
                    ),
                    CachedNetworkImage(
                      imageUrl:
                          "https://pixabay.com",
                      width: (MediaQuery.of(context).size.width - 48) / 2 - 2,
                      height: 120.0,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36.0),
          Container(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("About", style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 12.0),
                Text(
                  "Piribebuy es una histórica ciudad de Paraguay, ubicada en el Departamento de Cordillera, conocida por su rica historia durante la Guerra de la Triple Alianza y sus hermosos arroyos naturales...",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, IconData icon, Color color) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8.0),
        Text(label, style: const TextStyle(fontSize: 12.0)),
      ],
    );
  }


  final colors = [Colors.amber, Colors.black, Colors.blue];

  MapboxMap? mapboxMap;
  int _accuracyColor = 0;
  int _pulsingColor = 0;
  int _accuracyBorderColor = 0;
  double _puckScale = 10.0;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }




  @override
  void dispose() {
    super.dispose();
  }

  Widget _show() {
    return TextButton(
      child: Text('show location'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(enabled: true));
      },
    );
  }

  Widget _hide() {
    return TextButton(
      child: Text('hide location'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(enabled: false));
      },
    );
  }

  Widget _showBearing() {
    return TextButton(
      child: Text('show location bearing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(
            LocationComponentSettings(puckBearingEnabled: true));
      },
    );
  }

  Widget _hideBearing() {
    return TextButton(
      child: Text('hide location bearing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(
            LocationComponentSettings(puckBearingEnabled: false));
      },
    );
  }

  Widget _showPulsing() {
    return TextButton(
      child: Text('show pulsing'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(pulsingEnabled: true));
      },
    );
  }

  Widget _hidePulsing() {
    return TextButton(
      child: Text('hide pulsing'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(pulsingEnabled: false));
      },
    );
  }

  Widget _showAccuracy() {
    return TextButton(
      child: Text('show accuracy'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(showAccuracyRing: true));
      },
    );
  }

  Widget _hideAccuracy() {
    return TextButton(
      child: Text('hide accuracy'),
      onPressed: () {
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(showAccuracyRing: false));
      },
    );
  }

  Widget _switchAccuracyBorderColor() {
    return TextButton(
      child: Text('switch accuracy border color'),
      onPressed: () {
        _accuracyBorderColor++;
        _accuracyBorderColor %= colors.length;
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            accuracyRingBorderColor: colors[_accuracyBorderColor].toARGB32()));
      },
    );
  }

  Widget _switchAccuracyColor() {
    return TextButton(
      child: Text('switch accuracy color'),
      onPressed: () {
        _pulsingColor++;
        _pulsingColor %= colors.length;
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            accuracyRingColor: colors[_pulsingColor].toARGB32()));
      },
    );
  }

  Widget _switchPulsingColor() {
    return TextButton(
      child: Text('switch pulsing color'),
      onPressed: () {
        _accuracyColor++;
        _accuracyColor %= colors.length;
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            pulsingColor: colors[_accuracyColor].toARGB32()));
      },
    );
  }

  Widget _switchLocationPuck2D() {
    return TextButton(
      child: Text('switch to 2d puck'),
      onPressed: () async {
        final ByteData bytes =
            await rootBundle.load('assets/symbols/custom-icon.png');
        final Uint8List list = bytes.buffer.asUint8List();

        mapboxMap?.location.updateSettings(LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            locationPuck: LocationPuck(
                locationPuck2D: DefaultLocationPuck2D(
                    topImage: list, shadowImage: Uint8List.fromList([])))));
      },
    );
  }

  Widget _switchLocationPuck3D_duck() {
    return TextButton(
      child: Text('switch to 3d puck with duck model'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri:
                        "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _switchLocationPuck3D_car() {
    return TextButton(
      child: Text('switch to 3d puck with car model'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri: "asset://assets/sportcar.glb",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _switchPuckScale() {
    return TextButton(
      child: Text('scale 3d puck'),
      onPressed: () {
        _puckScale /= 2;
        if (_puckScale < 1) {
          _puckScale = 10.0;
        }
        print("Scale : $_puckScale");
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri:
                        "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _getPermission() {
    return TextButton(
      child: Text('get location permission'),
      onPressed: () async {
        var status = await Geolocator.requestPermission();
        print("Location granted : $status");
      },
    );
  }

  Widget _getSettings() {
    return TextButton(
      child: Text('get settings'),
      onPressed: () {
        mapboxMap?.location.getSettings().then(
            (value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("""
                  Location settings : 
                    enabled : ${value.enabled}, 
                    puckBearingEnabled : ${value.puckBearingEnabled}
                    puckBearing : ${value.puckBearing}
                    pulsing : ${value.pulsingEnabled}
                    pulsing radius : ${value.pulsingMaxRadius}
                    pulsing color : ${value.pulsingColor}
                    accuracy :  ${value.showAccuracyRing},
                    accuracy color :  ${value.accuracyRingColor}
                    accuracyRingBorderColor : ${value.accuracyRingBorderColor}
                    """
                      .trim()),
                  backgroundColor: Theme.of(context).primaryColor,
                  duration: Duration(seconds: 2),
                )));
      },
    );
  }
}
