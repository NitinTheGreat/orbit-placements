import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../services/gmail_connect_service.dart';

class GmailConnectScreen extends StatefulWidget {
  const GmailConnectScreen({super.key});

  @override
  State<GmailConnectScreen> createState() => _GmailConnectScreenState();
}

class _GmailConnectScreenState extends State<GmailConnectScreen> {
  final GmailConnectService _service = GmailConnectService();

  bool _busy = false;
  String? _error;
  bool _declined = false;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _declined = false;
    });

    try {
      await _service.connect();
    } on GmailConnectDeclined {
      if (mounted) {
        setState(() {
          _busy = false;
          _declined = true;
        });
      }
      return;
    } on GmailConnectException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not connect Gmail. Please try again.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Gmail'),
        actions: [
          TextButton(
            onPressed: _busy ? null : session.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Orbit reads your placement mail',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Orbit needs read-only access to your VIT inbox to track '
                    'registrations, PPTs, shortlists, and OA invites for you. '
                    'It never sends mail and never changes anything in your '
                    'mailbox.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_declined)
                    _NoticeCard(
                      background: theme.colorScheme.errorContainer,
                      foreground: theme.colorScheme.onErrorContainer,
                      icon: Icons.block,
                      message:
                          'Gmail access was not granted. Orbit cannot track '
                          'your drives without it, so this step cannot be '
                          'skipped.',
                    ),
                  if (_error != null)
                    _NoticeCard(
                      background: theme.colorScheme.errorContainer,
                      foreground: theme.colorScheme.onErrorContainer,
                      icon: Icons.error_outline,
                      message: _error!,
                    ),
                  if (_declined || _error != null) const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _busy
                          ? 'Connecting...'
                          : (_declined || _error != null)
                          ? 'Try again'
                          : 'Connect Gmail',
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
