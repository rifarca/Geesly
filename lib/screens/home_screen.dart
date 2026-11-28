import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geesly/components/MenuNeoGlassNavigationBar.dart';
import 'package:geesly/providers/auth_provider.dart';
import 'package:geesly/screens/auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreMap;

  const HomeScreen({super.key, this.onExploreMap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _redirecting = false;

  void _enforceAuthentication(BuildContext context, AuthProvider auth) {
    if (!auth.isAuthenticated && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              onAuthenticated: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      });
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final primary = Theme.of(context).colorScheme.primary;

    // Si no ha iniciado sesión ni se ha registrado, bloquea el acceso y redirige
    if (!auth.isAuthenticated) {
      _enforceAuthentication(context, auth);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = auth.user;
    final String firstName = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!.trim().split(' ').first
        : 'viajero';

    return Scaffold(
      bottomNavigationBar: MenuNeoGlassNagivationBar(selectedItem: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.explore_rounded, color: primary, size: 30),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Geesly',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: () => _handleSignOut(context),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),

            const SizedBox(height: 35),

            Text(
              '¡Hola, $firstName!',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              '¿A dónde quieres ir hoy?',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 28),

            // Acceso al mapa
            InkWell(
              onTap: widget.onExploreMap ?? () {},
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Explorar destinos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Encuentra lugares, descubre rutas '
                      'y comienza tu próximo viaje.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Text(
                          'Comenzar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Descubre Geesly',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.location_on_outlined,
                    title: 'Lugares',
                    subtitle: 'Explora sitios',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.route_outlined,
                    title: 'Rutas',
                    subtitle: 'Planifica viajes',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.navigation_outlined,
                    title: 'Navegación',
                    subtitle: 'Encuentra caminos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.explore_outlined,
                    title: 'Aventuras',
                    subtitle: 'Nuevos destinos',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
