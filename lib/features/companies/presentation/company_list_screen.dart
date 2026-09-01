import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/placeholder_view.dart';

class CompanyListScreen extends StatelessWidget {
  const CompanyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderView(
      title: 'Company List',
      actions: [
        FilledButton(
          onPressed: () => context.goNamed(
            AppRoutes.companyDetail,
            pathParameters: {'companyId': 'placeholder'},
          ),
          child: const Text('Open a company'),
        ),
      ],
    );
  }
}
