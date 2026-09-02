import 'package:flutter/material.dart';

import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import '../../../services/home_widget_service.dart';
import '../../companies/presentation/widget_feed.dart';

class WidgetRefresher extends StatefulWidget {
  const WidgetRefresher({super.key, required this.studentId, this.child});

  final String? studentId;
  final Widget? child;

  @override
  State<WidgetRefresher> createState() => _WidgetRefresherState();
}

class _WidgetRefresherState extends State<WidgetRefresher>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final HomeWidgetService _homeWidget = const HomeWidgetService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  @override
  void didUpdateWidget(WidgetRefresher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      _publish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _publish();
    }
  }

  Future<void> _publish() async {
    final studentId = widget.studentId;
    if (studentId == null || !_homeWidget.isSupported) {
      return;
    }

    try {
      final companies = await _firestoreService.watchCompanies().first;
      final statuses = await _firestoreService
          .watchStatusesForStudent(studentId)
          .first;
      await _homeWidget.publish(
        buildWidgetFeed(
          companies: companies,
          statusesByCompanyId: <String, StudentCompanyStatus>{
            for (final status in statuses) status.companyId: status,
          },
        ),
      );
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
