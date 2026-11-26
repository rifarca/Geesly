import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SocialAuthSection extends StatelessWidget {
  final VoidCallback onSuccess;
  final VoidCallback onInstagramOrTokenPressed;

  const SocialAuthSection({
    super.key,
    required this.onSuccess,
    required this.onInstagramOrTokenPressed,
  });

  Future<void> _handleSocial(
    BuildContext context,
    Future<dynamic> Function() action,
  ) async {
    final credential = await action();
    if (credential != null && context.mounted) {
      onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.isLoading;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'O continúa con',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _SocialButton(
              label: 'Google',
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              borderColor: Colors.grey.shade300,
              onPressed: isLoading
                  ? null
                  : () => _handleSocial(context, auth.signInWithGoogle),
            ),
            _SocialButton(
              label: 'Facebook',
              icon: Icons.facebook_rounded,
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              onPressed: isLoading
                  ? null
                  : () => _handleSocial(context, auth.signInWithFacebook),
            ),
            _SocialButton(
              label: 'Apple',
              icon: Icons.apple_rounded,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              onPressed: isLoading
                  ? null
                  : () => _handleSocial(context, auth.signInWithApple),
            ),
            _SocialButton(
              label: 'X',
              icon: Icons.alternate_email_rounded,
              backgroundColor: const Color(0xFF0F1419),
              foregroundColor: Colors.white,
              onPressed: isLoading
                  ? null
                  : () => _handleSocial(context, auth.signInWithX),
            ),
            _SocialButton(
              label: 'Instagram / Token',
              icon: Icons.vpn_key_rounded,
              backgroundColor: const Color(0xFFE1306C),
              foregroundColor: Colors.white,
              onPressed: isLoading ? null : onInstagramOrTokenPressed,
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: foregroundColor),
        label: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor ?? backgroundColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
