import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
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
          _error = 'Could not save your details. Please try again.';
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
        title: const Text('Finish setting up'),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'We need two more details before you can track drives.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _neoIdController,
                      decoration: const InputDecoration(
                        labelText: 'NeoID',
                        hintText: 'Your VIT NeoID',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your NeoID'
                          : null,
                    ),
                    const SizedBox(height: 16),
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
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
