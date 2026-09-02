const String auroraRegNo = '23BCT0210';
const String auroraFirstName = 'guneet';
const String auroraDisplayName = 'Ms Aurora';

final RegExp _nonAlphanumeric = RegExp(r'[^a-z0-9]+');

List<String> _tokens(String? value) {
  if (value == null) {
    return const [];
  }
  return value
      .toLowerCase()
      .split(_nonAlphanumeric)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

bool isAurora({String? name, String? regNo}) {
  final marks = <String>{..._tokens(name), ..._tokens(regNo)};
  return marks.contains(auroraRegNo.toLowerCase()) ||
      marks.contains(auroraFirstName);
}

String? firstNameOf(String? name) {
  for (final token in (name ?? '').trim().split(RegExp(r'\s+'))) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (RegExp(r'^\d').hasMatch(trimmed)) {
      continue;
    }
    return trimmed;
  }
  return null;
}

String? greetingName({String? name, String? regNo}) {
  if (isAurora(name: name, regNo: regNo)) {
    return auroraDisplayName;
  }
  return firstNameOf(name);
}

String displayName({String? name, String? regNo}) {
  if (isAurora(name: name, regNo: regNo)) {
    return auroraDisplayName;
  }
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'Your profile';
  }
  return trimmed;
}
