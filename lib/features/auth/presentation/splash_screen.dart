import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/placeholder_view.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderView(
      title: 'Splash',
      showAppBar: false,
      actions: [
        FilledButton(
          onPressed: () => context.goNamed(AppRoutes.login),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
