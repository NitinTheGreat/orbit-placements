enum BranchFamily {
  computerScience,
  informationTechnology,
  electronicsCommunication,
  electricalElectronics,
  instrumentation,
  mechanical,
  civil,
  chemical,
  biotechnology,
}

class BranchInfo {
  const BranchInfo(this.code, this.name, this.family);

  final String code;
  final String name;
  final BranchFamily family;
}

const Map<String, BranchInfo> vitBranchCodes = <String, BranchInfo>{
  'BCE': BranchInfo(
    'BCE',
    'Computer Science and Engineering',
    BranchFamily.computerScience,
  ),
  'BCT': BranchInfo(
    'BCT',
    'Computer Science and Engineering',
    BranchFamily.computerScience,
  ),
  'BAI': BranchInfo(
    'BAI',
    'Computer Science and Engineering (AI and Machine Learning)',
    BranchFamily.computerScience,
  ),
  'BCI': BranchInfo(
    'BCI',
    'Computer Science and Engineering (Information Security)',
    BranchFamily.computerScience,
  ),
  'BPS': BranchInfo(
    'BPS',
    'Computer Science and Engineering (Cyber Physical Systems)',
    BranchFamily.computerScience,
  ),
  'BDS': BranchInfo(
    'BDS',
    'Computer Science and Engineering (Data Science)',
    BranchFamily.computerScience,
  ),
  'BRS': BranchInfo(
    'BRS',
    'Computer Science and Engineering (AI and Robotics)',
    BranchFamily.computerScience,
  ),
  'BIT': BranchInfo(
    'BIT',
    'Information Technology',
    BranchFamily.informationTechnology,
  ),
  'BEC': BranchInfo(
    'BEC',
    'Electronics and Communication Engineering',
    BranchFamily.electronicsCommunication,
  ),
  'BEE': BranchInfo(
    'BEE',
    'Electrical and Electronics Engineering',
    BranchFamily.electricalElectronics,
  ),
  'BEI': BranchInfo(
    'BEI',
    'Electronics and Instrumentation Engineering',
    BranchFamily.instrumentation,
  ),
  'BME': BranchInfo('BME', 'Mechanical Engineering', BranchFamily.mechanical),
  'BCL': BranchInfo('BCL', 'Civil Engineering', BranchFamily.civil),
  'BCH': BranchInfo('BCH', 'Chemical Engineering', BranchFamily.chemical),
  'BBT': BranchInfo('BBT', 'Biotechnology', BranchFamily.biotechnology),
};

final RegExp _regNoPattern = RegExp(r'^(\d{2})([A-Z]{3})(\d{4})$');

String? branchCodeFromRegNo(String? regNo) {
  final cleaned = regNo?.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  final match = _regNoPattern.firstMatch(cleaned);
  return match?.group(2);
}

BranchInfo? branchForRegNo(String? regNo) {
  final code = branchCodeFromRegNo(regNo);
  if (code == null) {
    return null;
  }
  return vitBranchCodes[code];
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
      BranchFamily.electronicsCommunication: <String>[
        'ece',
        'ecm',
        'electronics and communication',
        'electronics communication',
        'electronics and telecommunication',
      ],
      BranchFamily.electricalElectronics: <String>[
        'eee',
        'electrical',
        'electrical and electronics',
      ],
      BranchFamily.instrumentation: <String>[
        'eie',
        'instrumentation',
        'electronics and instrumentation',
      ],
      BranchFamily.mechanical: <String>[
        'mech',
        'mechanical',
        'mechatronics',
        'automotive',
      ],
      BranchFamily.civil: <String>['civil'],
      BranchFamily.chemical: <String>['chemical', 'chem'],
      BranchFamily.biotechnology: <String>[
        'bio',
        'biotech',
        'biotechnology',
        'biomedical',
      ],
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
