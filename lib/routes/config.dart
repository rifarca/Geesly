// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/map/map_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/travel',
      name: 'Viajar',
      builder: (context, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/locate-in-map',
      name: 'Donde quieres ir?',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);