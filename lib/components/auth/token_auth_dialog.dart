import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class TokenAuthDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const TokenAuthDialog({super.key, required this.onSuccess});

  @override
  State<TokenAuthDialog> createState() => _TokenAuthDialogState();
}

class _TokenAuthDialogState extends State<TokenAuthDialog> {
  final _tokenController = TextEditingController();
  bool _isInstagramToken = true;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final credential = _isInstagramToken
        ? await auth.signInWithInstagramToken(token)
        : await auth.signInWithCustomToken(token);

    if (credential != null && mounted) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Acceso con Instagram / Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Instagram Token')),
              ButtonSegment(value: false, label: Text('Custom Token')),
            ],
            selected: {_isInstagramToken},
            onSelectionChanged: (selection) {
              setState(() => _isInstagramToken = selection.first);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _isInstagramToken
                  ? 'Token OAuth / Backend de Instagram'
                  : 'Firebase Custom Token',
              hintText: 'Pega aquí tu token de acceso...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              auth.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: auth.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: auth.isLoading ? null : _submit,
          child: auth.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Validar Token'),
        ),
      ],
    );
  }
}
