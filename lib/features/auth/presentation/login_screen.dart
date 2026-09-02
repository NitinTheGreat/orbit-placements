import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_mark.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../services/auth_service.dart';
import '../../../services/google_button_stub.dart'
    if (dart.library.js_interop) '../../../services/google_button_web.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  bool _busy = false;
  String? _error;
  bool _webReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _prepareWeb();
    }
  }

  @override
  void dispose() {
    _authService.stopWebSignInListener();
    super.dispose();
  }

  Future<void> _prepareWeb() async {
    try {
      await _authService.startWebSignInListener(onError: _reportWebError);
      if (mounted) {
        setState(() => _webReady = true);
      }
    } on Object catch (error) {
      _reportWebError(error);
    }
  }

  void _reportWebError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error is AuthException
          ? error.message
          : 'Sign-in did not go through. Check your connection and try again.';
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _authService.signInWithGoogle();
    } on SignInCancelled {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    } on AuthException catch (error) {
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
              'Sign-in did not go through. Check your connection and try '
              'again.';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OrbitSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: OrbitMark(size: 60)),
                  const SizedBox(height: OrbitSpacing.xl),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OrbitSpacing.sm),
                  Text(
                    'Track every placement drive at VIT, from registration '
                    'to result.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OrbitSpacing.xxl),
                  if (_error != null) ...[
                    OrbitNotice(
                      title: 'Use your VIT email',
                      message: _error!,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: OrbitSpacing.lg),
                  ],
                  if (kIsWeb)
                    Center(
                      child: _webReady
                          ? googleSignInButton()
                          : const SizedBox(
                              height: 40,
                              width: 40,
                              child: Center(
                                child: SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            ),
                    )
                  else
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: _busy
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text('Continue with Google'),
                    ),
                  const SizedBox(height: OrbitSpacing.lg),
                  Text(
                    'Sign in with your @${AppConstants.allowedEmailDomain} '
                    'account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkFaint,
                    ),
                    textAlign: TextAlign.center,
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
