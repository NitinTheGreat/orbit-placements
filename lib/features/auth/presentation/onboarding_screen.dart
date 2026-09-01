import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../models/student.dart';
import '../../../services/firestore_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _neoIdController = TextEditingController();
  final _regNoController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _neoIdController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = SessionScope.of(context);
    final user = session.user;
    if (user == null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _firestoreService.createStudent(
        Student(
          uid: user.uid,
          vitEmail: user.email ?? '',
          name: user.displayName ?? '',
          neoId: _neoIdController.text.trim(),
          regNo: _regNoController.text.trim().toUpperCase(),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Your details did not save. Check your connection and tap '
              'Continue again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Two details and you are in',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: OrbitSpacing.sm),
                    Text(
                      'Orbit uses these to match you to the drives you are '
                      'eligible for.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: OrbitSpacing.xxl),
                    TextFormField(
                      controller: _neoIdController,
                      decoration: const InputDecoration(
                        labelText: 'NeoID',
                        hintText: 'The ID you use for VTOP',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your NeoID so we can match your drives'
                          : null,
                    ),
                    const SizedBox(height: OrbitSpacing.lg),
                    TextFormField(
                      controller: _regNoController,
                      decoration: const InputDecoration(
                        labelText: 'Registration number',
                        hintText: '21BCE1234',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your registration number'
                          : null,
                      onFieldSubmitted: (_) {
                        if (!_busy) {
                          _submit();
                        }
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: OrbitSpacing.lg),
                      OrbitNotice(message: _error!, icon: Icons.error_outline),
                    ],
                    const SizedBox(height: OrbitSpacing.xxl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
