import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavigationBarComponent extends StatelessWidget {
  final int item;

  const BottomNavigationBarComponent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(

      currentIndex: item,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'viajar'),
      ],
      onTap: (menuIndex) {
        switch (menuIndex) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/mapbox');
            break;
        }
      },

    );
  }
}