// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/HomeScreen.dart';
import '../screens/MapboxScreen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/map',
      name: 'mapbox',
      builder: (context, state) => const MapboxScreen(),
    ),
  ],
);