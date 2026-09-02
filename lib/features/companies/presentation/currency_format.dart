import '../../../models/company.dart';

final RegExp _digitRun = RegExp(r'\d+');
final RegExp _monthHint = RegExp(
  r'month|/\s*mo\b|\bp\.?\s?m\.?\b',
  caseSensitive: false,
);

String groupIndian(String digits) {
  if (digits.length <= 3) {
    return digits;
  }
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) {
    groups.insert(0, rest);
  }
  return '${groups.join(',')},$last3';
}

String formatAmounts(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  return value.replaceAllMapped(_digitRun, (match) {
    final digits = match.group(0)!;
    if (digits.length < 5) {
      return digits;
    }
    return groupIndian(digits);
  });
}

bool mentionsAMonth(String value) => _monthHint.hasMatch(value);

String formatStipend(String? stipend, StipendPeriod period) {
  final formatted = formatAmounts(stipend);
  if (formatted.isEmpty) {
    return '';
  }
  if (period != StipendPeriod.monthly || mentionsAMonth(formatted)) {
    return formatted;
  }
  return '$formatted / month';
}
