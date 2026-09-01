import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class CompanyDetailScreen extends StatelessWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderView(
      title: 'Company Detail',
      subtitle: companyId.isEmpty ? null : companyId,
    );
  }
}
