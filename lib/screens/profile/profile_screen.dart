
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 15),

          CircleAvatar(
            radius: 48,
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.person_rounded,
              size: 52,
              color: primary,
            ),
          ),

          const SizedBox(height: 15),

          const Center(
            child: Text(
              'Mi cuenta',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              'Bienvenido a Geesly',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),

          const SizedBox(height: 35),

          _ProfileOption(
            icon: Icons.person_outline,
            title: 'Información personal',
            onTap: () {},
          ),

          _ProfileOption(
            icon: Icons.favorite_border,
            title: 'Lugares favoritos',
            onTap: () {},
          ),

          _ProfileOption(
            icon: Icons.history,
            title: 'Historial de viajes',
            onTap: () {},
          ),

          _ProfileOption(
            icon: Icons.settings_outlined,
            title: 'Configuración',
            onTap: () {},
          ),

          _ProfileOption(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            onTap: () {},
          ),

          _ProfileOption(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            color: Colors.red,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ??
        Theme.of(context).colorScheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: Icon(icon, color: foreground),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
