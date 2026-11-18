import 'package:flutter/material.dart';
import 'package:geesly/routes/config.dart';
import 'package:provider/provider.dart';
import 'core/mapbox/mapbox_config.dart';
import 'providers/map_provider.dart';
import 'screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxConfig.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MapProvider(),
      child: const GeeslyApp(),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),


    );
  }
}
