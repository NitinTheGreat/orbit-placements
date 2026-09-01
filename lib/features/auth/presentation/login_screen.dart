import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/placeholder_view.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderView(
      title: 'Login',
      actions: [
        FilledButton(
          onPressed: () => context.goNamed(AppRoutes.companies),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
