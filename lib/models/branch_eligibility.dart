enum BranchFamily {
  computerScience,
  informationTechnology,
  electrical,
  mechanical,
  postgraduate,
}

class BranchInfo {
  const BranchInfo(this.code, this.name, this.family);

  final String code;
  final String name;
  final BranchFamily family;
}

const Map<BranchFamily, String> branchFamilyNames = <BranchFamily, String>{
  BranchFamily.computerScience: 'Computer Science and Engineering',
  BranchFamily.informationTechnology: 'Information Technology',
  BranchFamily.electrical: 'Electrical and Electronics',
  BranchFamily.mechanical: 'Mechanical',
  BranchFamily.postgraduate: 'Postgraduate',
};

final RegExp _regNoPattern = RegExp(r'^(\d{2})([A-Z]{3})(\d{4})$');

String? branchCodeFromRegNo(String? regNo) {
  final cleaned = regNo?.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  return _regNoPattern.firstMatch(cleaned)?.group(2);
}

BranchFamily? branchFamilyForCode(String? code) {
  final upper = code?.trim().toUpperCase();
  if (upper == null || upper.isEmpty) {
    return null;
  }
  if (upper == 'BIT') {
    return BranchFamily.informationTechnology;
  }
  if (upper.startsWith('BC')) {
    return BranchFamily.computerScience;
  }
  if (upper.startsWith('BE')) {
    return BranchFamily.electrical;
  }
  if (upper.startsWith('BM')) {
    return BranchFamily.mechanical;
  }
  if (upper.startsWith('M')) {
    return BranchFamily.postgraduate;
  }
  return null;
}

BranchInfo? branchForRegNo(String? regNo) {
  final code = branchCodeFromRegNo(regNo);
  final family = branchFamilyForCode(code);
  if (code == null || family == null) {
    return null;
  }
  return BranchInfo(code, branchFamilyNames[family]!, family);
}

const Map<BranchFamily, List<String>> _familyKeywords =
    <BranchFamily, List<String>>{
      BranchFamily.computerScience: <String>[
        'cse',
        'cs',
        'computer science',
        'computer sciences',
        'computing',
        'aiml',
        'ai ml',
        'data science',
        'ds',
      ],
      BranchFamily.informationTechnology: <String>[
        'it',
        'information technology',
      ],
      BranchFamily.electrical: <String>[
        'ece',
        'ecm',
        'eee',
        'eie',
        'electrical',
        'electronics',
        'electronics and communication',
        'electronics communication',
        'electronics and telecommunication',
        'electrical and electronics',
        'instrumentation',
        'electronics and instrumentation',
      ],
      BranchFamily.mechanical: <String>[
        'mech',
        'mechanical',
        'mechatronics',
        'automotive',
      ],
      BranchFamily.postgraduate: <String>['m tech', 'mtech', 'mca', 'msc'],
    };

final RegExp _separators = RegExp(r'[^a-z0-9]+');
final RegExp _exclusion = RegExp(r'\b(except|excluding|other than)\b');
final RegExp _openToAll = RegExp(r'\ball\b');

String _normalise(String value) {
  return ' ${value.toLowerCase().replaceAll(_separators, ' ').trim()} ';
}

bool _mentions(String normalised, String keyword) {
  return normalised.contains(' ${keyword.replaceAll(_separators, ' ')} ');
}

Set<BranchFamily> familiesMentionedIn(String text) {
  final normalised = _normalise(text);
  final found = <BranchFamily>{};
  _familyKeywords.forEach((family, keywords) {
    for (final keyword in keywords) {
      if (_mentions(normalised, keyword)) {
        found.add(family);
        return;
      }
    }
  });
  return found;
}

enum BranchRelevance { eligible, notOpen, unknown }

BranchRelevance _relevanceForEntry(BranchFamily family, String entry) {
  final lowered = entry.toLowerCase();
  final exclusion = _exclusion.firstMatch(lowered);

  if (exclusion != null) {
    final excluded = familiesMentionedIn(lowered.substring(exclusion.end));
    if (excluded.isEmpty) {
      return BranchRelevance.unknown;
    }
    if (excluded.contains(family)) {
      return BranchRelevance.notOpen;
    }
    final base = lowered.substring(0, exclusion.start);
    return _openToAll.hasMatch(base)
        ? BranchRelevance.eligible
        : BranchRelevance.unknown;
  }

  final mentioned = familiesMentionedIn(lowered);
  if (mentioned.isEmpty) {
    return BranchRelevance.unknown;
  }
  return mentioned.contains(family)
      ? BranchRelevance.eligible
      : BranchRelevance.notOpen;
}

BranchRelevance branchRelevance({
  required BranchInfo? branch,
  required List<String> eligibleBranches,
}) {
  if (branch == null) {
    return BranchRelevance.unknown;
  }

  var sawNotOpen = false;
  for (final entry in eligibleBranches) {
    if (entry.trim().isEmpty) {
      continue;
    }
    switch (_relevanceForEntry(branch.family, entry)) {
      case BranchRelevance.eligible:
        return BranchRelevance.eligible;
      case BranchRelevance.notOpen:
        sawNotOpen = true;
      case BranchRelevance.unknown:
        break;
    }
  }

  return sawNotOpen ? BranchRelevance.notOpen : BranchRelevance.unknown;
}

BranchRelevance branchRelevanceForRegNo({
  required String? regNo,
  required List<String> eligibleBranches,
}) {
  return branchRelevance(
    branch: branchForRegNo(regNo),
    eligibleBranches: eligibleBranches,
  );
}
