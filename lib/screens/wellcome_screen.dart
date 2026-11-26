import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';

class WellcomeScreen extends StatelessWidget {
  final VoidCallback? onContinueToApp;

  const WellcomeScreen({super.key, this.onContinueToApp});

  String _getProviderLabel(String? providerId) {
    switch (providerId) {
      case 'google.com':
        return 'Google';
      case 'facebook.com':
        return 'Facebook';
      case 'apple.com':
        return 'Apple';
      case 'twitter.com':
        return 'X (Twitter)';
      case 'password':
        return 'Correo y contraseña';
      default:
        return 'Token / Personalizado';
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    final String displayName = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!
        : 'Usuario Geesly';
    final String email = user?.email ?? 'Sin correo asociado';
    final String providerId = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId
        : 'custom';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geesly'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: auth.isLoading ? null : () => _handleSignOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar del usuario
                  Center(
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.14),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              displayName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Saludo principal
                  Text(
                    '¡Bienvenido a Geesly,\n$displayName!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu sesión está activa y lista para comenzar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tarjeta con información de la cuenta
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Nombre',
                            value: displayName,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Correo',
                            value: email,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Método de acceso',
                            value: _getProviderLabel(providerId),
                          ),
                          if (user?.uid != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.fingerprint_rounded,
                              label: 'UID',
                              value: user!.uid,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botón continuar a pantalla principal
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onContinueToApp ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresando a Geesly...'),
                              ),
                            );
                          },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text(
                        'Continuar a Geesly',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón secundario cerrar sesión
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed:
                          auth.isLoading ? null : () => _handleSignOut(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}