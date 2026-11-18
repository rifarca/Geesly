import 'package:flutter/material.dart';

import '../components/BottomNavigationBarComponent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Text("Home"),
        ),
      ),      bottomNavigationBar: BottomNavigationBarComponent(item: 1)
    );
  }
}