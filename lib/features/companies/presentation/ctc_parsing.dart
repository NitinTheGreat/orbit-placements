class CtcRange {
  const CtcRange({required this.minLpa, required this.maxLpa});

  final double minLpa;
  final double maxLpa;

  double get bestLpa => maxLpa;
}

final RegExp _number = RegExp(r'\d[\d,]*(?:\.\d+)?');
final RegExp _lakhWords = RegExp(r'lpa|lakh|lac|lpm', caseSensitive: false);
final RegExp _croreWords = RegExp(r'\bcrore?s?\b', caseSensitive: false);

double? _toDouble(String raw) => double.tryParse(raw.replaceAll(',', ''));

double _toLpa(double value, {required bool lakhUnits, required bool crore}) {
  if (crore) {
    return value * 100;
  }
  if (lakhUnits) {
    return value;
  }
  if (value >= 10000) {
    return value / 100000;
  }
  return value;
}

CtcRange? parseCtc(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  final lakhUnits = _lakhWords.hasMatch(raw);
  final crore = _croreWords.hasMatch(raw);

  final values = <double>[];
  for (final match in _number.allMatches(raw)) {
    final parsed = _toDouble(match.group(0)!);
    if (parsed == null || parsed <= 0) {
      continue;
    }
    final lpa = _toLpa(parsed, lakhUnits: lakhUnits, crore: crore);
    if (lpa > 0 && lpa < 1000) {
      values.add(lpa);
    }
  }

  if (values.isEmpty) {
    return null;
  }

  values.sort();
  return CtcRange(minLpa: values.first, maxLpa: values.last);
}

class OfferThresholds {
  const OfferThresholds({this.dream, this.superDream});

  final double? dream;
  final double? superDream;

  bool get isConfigured => dream != null || superDream != null;

  static OfferThresholds fromMap(Map<String, dynamic>? map) {
    double? read(Object? value) {
      if (value is num) {
        return value.toDouble();
      }
      return null;
    }

    return OfferThresholds(
      dream: read(map?['dream']),
      superDream: read(map?['superDream']),
    );
  }
}

double? bestOfferLpa(Iterable<String?> offerCtcs) {
  double? best;
  for (final raw in offerCtcs) {
    final range = parseCtc(raw);
    if (range == null) {
      continue;
    }
    if (best == null || range.bestLpa > best) {
      best = range.bestLpa;
    }
  }
  return best;
}

bool stillEligibleAbove({
  required double? bestOfferLpa,
  required String? driveCtc,
  required OfferThresholds thresholds,
}) {
  if (!thresholds.isConfigured || bestOfferLpa == null) {
    return false;
  }
  final range = parseCtc(driveCtc);
  if (range == null) {
    return false;
  }
  final multiplier = thresholds.superDream ?? thresholds.dream;
  if (multiplier == null) {
    return false;
  }
  return range.bestLpa >= bestOfferLpa * multiplier;
}
