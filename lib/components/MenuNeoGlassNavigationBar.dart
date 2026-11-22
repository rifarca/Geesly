
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:neo_glass_navigation_bar/neo_glass_navigation_bar.dart';


class MenuNeoGlassNagivationBar extends StatefulWidget {
  MenuNeoGlassNagivationBar({super.key, required this.selectedItem});

  int selectedItem;

  @override
  State<MenuNeoGlassNagivationBar> createState() =>
      _MenuNeoGlassNagivationBarState();
}

class _MenuNeoGlassNagivationBarState
    extends State<MenuNeoGlassNagivationBar> {
  @override
  void initState() {
    super.initState();
//Future.microtask(_loadProviders);
  }
/*
  Future<void> _loadProviders({bool forceRefresh = false}) async {
   final configProvider = context.read<ConfigProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    final itemsProvider = context.read<ItemsProvider>();

    await itemsProvider.loadItemsFavorites(
      favoritesProvider.skus,
      forceRefresh: forceRefresh,
    );

    await configProvider.load();
  }
*/
  void _onItemTapped(int index) {
    if (widget.selectedItem == index) return;

    setState(() {
      widget.selectedItem = index;
    });

    switch (index) {
      case 0:
        context.go('/');
        break;

      case 1:
        context.push('/trip');
        break;

      case 2:
        context.push('/profile');
        break;

     
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha automáticamente los cambios de favoritos
  //  final favoritesProvider = context.watch<FavoritesProvider>();

    // Escucha cambios del ThemeMode
   // context.watch<ConfigProvider>();

  //  final favoritesCount = favoritesProvider.count;
   // final haveFavorites = favoritesCount > 0;

    // El brillo efectivo del tema (System, Dark o Light)
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return NeoGlassNavigationBar(
     
      currentIndex: widget.selectedItem,
      selectedItemColor: const Color(0xFF10B981),
      unselectedItemColor: isDark
          ? const Color.fromARGB(253, 255, 255, 255)
          : const Color(0xFF131313),
     
      
     
      onTap: _onItemTapped,
      items: [
        NeoGlassNavItem(
          activeIcon: CupertinoIcons.house_fill,
          icon: CupertinoIcons.house, 
          label: '', 

        ),
       
        NeoGlassNavItem(
          activeIcon: CupertinoIcons.compass_fill,
          icon: CupertinoIcons.compass,
        label: "Viajar"
        ),

       /* CrystalNavigationBarItem(
          icon: CupertinoIcons.heart_fill,
          unselectedIcon: CupertinoIcons.heart,
          badge: Badge(
            isLabelVisible: haveFavorites,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            label: Text(
              favoritesCount.toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),*/
        NeoGlassNavItem(
          activeIcon: CupertinoIcons.person,
          icon: CupertinoIcons.person_2,
          label: 'Perfil'
        ),
      ],
    );
  }
}
