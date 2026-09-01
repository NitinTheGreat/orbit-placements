import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
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
          _error =
              'Gmail did not finish connecting. Check your connection and '
              'try again.';
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
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : session.signOut,
            child: const Text('Sign out'),
          ),
          const SizedBox(width: OrbitSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            OrbitSpacing.xl,
            OrbitSpacing.sm,
            OrbitSpacing.xl,
            OrbitSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colors.accentWash,
                      borderRadius: BorderRadius.circular(OrbitRadius.card),
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 25,
                      color: colors.accentInk,
                    ),
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  Text(
                    'Let Orbit read your placement mail',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: OrbitSpacing.sm),
                  Text(
                    'Orbit watches your VIT inbox for drive announcements, '
                    'shortlists, and OA invites, so you never have to dig '
                    'through mail to find out what changed.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  const _Assurance(
                    icon: Icons.visibility_outlined,
                    text: 'Read-only. Orbit never sends or deletes mail.',
                  ),
                  const _Assurance(
                    icon: Icons.filter_alt_outlined,
                    text: 'Only placement mail is used. Nothing else is read.',
                  ),
                  const _Assurance(
                    icon: Icons.lock_outline,
                    text: 'You can disconnect from Google at any time.',
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  if (_declined) ...[
                    const OrbitNotice(
                      title: 'Orbit needs this to work',
                      message:
                          'Without inbox access there is nothing to track, so '
                          'this step cannot be skipped. Grant access to '
                          'continue.',
                      icon: Icons.block_outlined,
                    ),
                    const SizedBox(height: OrbitSpacing.lg),
                  ],
                  if (_error != null) ...[
                    OrbitNotice(
                      title: 'Could not connect',
                      message: _error!,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: OrbitSpacing.lg),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: _busy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(
                            _declined || _error != null
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

class _Assurance extends StatelessWidget {
  const _Assurance({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: OrbitSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.successInk),
          const SizedBox(width: OrbitSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
