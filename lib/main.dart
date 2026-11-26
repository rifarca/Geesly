import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geesly/firebase_options.dart';
import 'package:geesly/providers/auth_provider.dart';
import 'package:geesly/routes/config.dart';
import 'package:provider/provider.dart';
import 'core/mapbox/mapbox_config.dart';
import 'providers/map_provider.dart';
import 'state/trip_box.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  MapboxConfig.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TripBox()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: GeeslyApp(),
    ),
  );
}

class GeeslyApp extends StatelessWidget {
  const GeeslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'Geesly',
      debugShowCheckedModeBanner: false,
    );
  }
}
