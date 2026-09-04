import 'package:flutter/foundation.dart';

const String refreshWidgetAction = 'refreshWidget';

final ValueNotifier<String?> pendingCompanyId = ValueNotifier<String?>(null);

String? companyIdFromMessage(Map<String, dynamic>? data) {
  if (data == null) {
    return null;
  }
  if (data['orbitAction'] == refreshWidgetAction) {
    return null;
  }
  final raw = data['companyId'];
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void rememberTappedCompany(Map<String, dynamic>? data) {
  final companyId = companyIdFromMessage(data);
  if (companyId != null) {
    pendingCompanyId.value = companyId;
  }
}
