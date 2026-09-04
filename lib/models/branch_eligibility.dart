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

enum DegreeLevel { undergraduate, postgraduate }

const Map<DegreeLevel, List<String>> _levelKeywords = <DegreeLevel, List<String>>{
  DegreeLevel.postgraduate: <String>[
    'm tech',
    'mtech',
    'm e',
    'mca',
    'msc',
    'm sc',
    'mba',
    'pg',
    'postgraduate',
    'post graduate',
    'masters',
  ],
  DegreeLevel.undergraduate: <String>[
    'b tech',
    'btech',
    'b e',
    'ug',
    'undergraduate',
    'under graduate',
    'bachelor',
    'bachelors',
  ],
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

DegreeLevel? degreeLevelForCode(String? code) {
  final upper = code?.trim().toUpperCase();
  if (upper == null || upper.isEmpty) {
    return null;
  }
  if (upper.startsWith('B')) {
    return DegreeLevel.undergraduate;
  }
  if (upper.startsWith('M')) {
    return DegreeLevel.postgraduate;
  }
  return null;
}

DegreeLevel? degreeLevelForRegNo(String? regNo) =>
    degreeLevelForCode(branchCodeFromRegNo(regNo));

Set<DegreeLevel> levelsMentionedIn(String text) {
  final normalised = _normalise(text);
  final found = <DegreeLevel>{};
  _levelKeywords.forEach((level, keywords) {
    for (final keyword in keywords) {
      if (_mentions(normalised, keyword)) {
        found.add(level);
        return;
      }
    }
  });
  return found;
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

BranchRelevance _branchOutcome(BranchFamily family, String lowered) {
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
  DegreeLevel? level,
}) {
  if (branch == null) {
    return BranchRelevance.unknown;
  }

  final resolvedLevel = level ?? degreeLevelForCode(branch.code);
  var levelAdmitted = false;
  var levelExcluded = false;
  var branchExcluded = false;

  for (final entry in eligibleBranches) {
    if (entry.trim().isEmpty) {
      continue;
    }
    final lowered = entry.toLowerCase();
    final levels = levelsMentionedIn(lowered);

    if (resolvedLevel != null &&
        levels.isNotEmpty &&
        !levels.contains(resolvedLevel)) {
      levelExcluded = true;
      continue;
    }
    levelAdmitted = true;

    if (branch.family == BranchFamily.postgraduate) {
      continue;
    }

    switch (_branchOutcome(branch.family, lowered)) {
      case BranchRelevance.eligible:
        return BranchRelevance.eligible;
      case BranchRelevance.notOpen:
        branchExcluded = true;
      case BranchRelevance.unknown:
        break;
    }
  }

  if (levelAdmitted) {
    return branchExcluded ? BranchRelevance.notOpen : BranchRelevance.unknown;
  }
  return levelExcluded ? BranchRelevance.notOpen : BranchRelevance.unknown;
}

BranchRelevance branchRelevanceForRegNo({
  required String? regNo,
  required List<String> eligibleBranches,
}) {
  return branchRelevance(
    branch: branchForRegNo(regNo),
    eligibleBranches: eligibleBranches,
    level: degreeLevelForRegNo(regNo),
  );
}
