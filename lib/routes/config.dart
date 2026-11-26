// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:geesly/screens/auth/login_screen.dart';
import 'package:geesly/screens/auth/register_screen.dart';
import 'package:geesly/screens/home_screen.dart';
import 'package:geesly/screens/profile/profile_screen.dart';
import 'package:geesly/screens/trip_flow_screen.dart';
import 'package:geesly/screens/wellcome_screen.dart';
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

    GoRoute(
      path: '/wellcome',
      name: 'Bienvinada',
      builder: (context, state) => const WellcomeScreen(),
    ),

    GoRoute(
      path: '/login',
      name: 'Iniciar Sesion',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/register',
      name: 'Registro',
      builder: (context, state) => const RegisterScreen(),
    ),
  ],
);