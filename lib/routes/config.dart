// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:geesly/screens/home_screen.dart';
import 'package:geesly/screens/profile/profile_screen.dart';
import 'package:geesly/screens/trip_flow_screen.dart';
import 'package:go_router/go_router.dart';



final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/trip',
      name: 'Viajar',
      builder: (context, state) => const TripFlowScreen(),
    ),
    
    GoRoute(
      path: '/profile',
      name: 'Perfil',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);