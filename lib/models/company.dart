import 'package:cloud_firestore/cloud_firestore.dart';

enum CompanyStatus {
  registrationOpen('registration_open', 'Registration open'),
  inProgress('in_progress', 'In progress'),
  resultsDeclared('results_declared', 'Results declared'),
  closed('closed', 'Closed');

  const CompanyStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static CompanyStatus fromWire(Object? value) {
    return CompanyStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => CompanyStatus.registrationOpen,
    );
  }
}

enum RoundType {
  ppt('ppt', 'Pre-placement talk'),
  oa('oa', 'Online assessment'),
  interview('interview', 'Interview'),
  other('other', 'Round');

  const RoundType(this.wireName, this.label);

  final String wireName;
  final String label;

  static RoundType fromWire(Object? value) {
    return RoundType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => RoundType.other,
    );
  }
}

class CompanyRound {
  const CompanyRound({
    required this.id,
    required this.name,
    required this.order,
    this.type = RoundType.other,
    this.announcedAt,
  });

  final String id;
  final String name;
  final int order;
  final RoundType type;
  final DateTime? announcedAt;

  factory CompanyRound.fromMap(Map<String, dynamic> map) {
    return CompanyRound(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      type: RoundType.fromWire(map['type']),
      announcedAt: Company._toDate(map['announcedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'order': order,
      'type': type.wireName,
      'announcedAt': announcedAt == null
          ? null
          : Timestamp.fromDate(announcedAt!),
    };
  }
}

enum StipendPeriod {
  monthly('monthly'),
  total('total'),
  unspecified('unspecified');

  const StipendPeriod(this.wireName);

  final String wireName;

  static StipendPeriod fromWire(Object? value) {
    return StipendPeriod.values.firstWhere(
      (period) => period.wireName == value,
      orElse: () => StipendPeriod.unspecified,
    );
  }
}

enum RequirementType {
  neopat('neopat', 'NeoPAT'),
  googleForm('google_form', 'Form'),
  companySite('company_site', 'Company site'),
  other('other', 'Step');

  const RequirementType(this.wireName, this.label);

  final String wireName;
  final String label;

  static RequirementType fromWire(Object? value) {
    return RequirementType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => RequirementType.other,
    );
  }
}

class CompanyRequirement {
  const CompanyRequirement({
    required this.id,
    required this.type,
    required this.label,
    this.url,
    this.isRequired = false,
    this.addedAt,
    this.sourceMessageId,
  });

  final String id;
  final RequirementType type;
  final String label;
  final String? url;
  final bool isRequired;
  final DateTime? addedAt;
  final String? sourceMessageId;

  bool get hasUrl => url != null && url!.isNotEmpty;

  factory CompanyRequirement.fromMap(Map<String, dynamic> map) {
    final label = map['label'] as String? ?? '';
    final type = RequirementType.fromWire(map['type']);
    return CompanyRequirement(
      id: map['id'] as String? ?? slugify('${type.wireName} $label'),
      type: type,
      label: label,
      url: map['url'] as String?,
      isRequired: map['required'] as bool? ?? false,
      addedAt: Company._toDate(map['addedAt']),
      sourceMessageId: map['sourceMessageId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type.wireName,
      'label': label,
      'url': url,
      'required': isRequired,
      'addedAt': addedAt == null ? null : Timestamp.fromDate(addedAt!),
      'sourceMessageId': sourceMessageId,
    };
  }

  CompanyRequirement copyWith({
    String? id,
    RequirementType? type,
    String? label,
    String? url,
    bool? isRequired,
  }) {
    return CompanyRequirement(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      url: url ?? this.url,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}

String slugify(String value) {
  final lowered = value.toLowerCase().trim();
  final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.category,
    this.ctc,
    this.stipend,
    this.stipendPeriod = StipendPeriod.unspecified,
    this.eligibleBranches = const <String>[],
    this.eligibilityCriteria,
    this.registrationDeadline,
    this.visitDate,
    this.status = CompanyStatus.registrationOpen,
    this.requirements = const <CompanyRequirement>[],
    this.rounds = const <CompanyRound>[],
    this.createdAt,
    this.sourceSubject,
    this.sourceDate,
    this.lastUpdatedSubject,
    this.lastUpdatedDate,
  });

  final String id;
  final String name;
  final String category;
  final String? ctc;
  final String? stipend;
  final StipendPeriod stipendPeriod;
  final List<String> eligibleBranches;
  final String? eligibilityCriteria;
  final DateTime? registrationDeadline;
  final DateTime? visitDate;
  final CompanyStatus status;
  final List<CompanyRequirement> requirements;
  final List<CompanyRound> rounds;
  final DateTime? createdAt;
  final String? sourceSubject;
  final DateTime? sourceDate;
  final String? lastUpdatedSubject;
  final DateTime? lastUpdatedDate;

  bool get hasSeparateUpdate =>
      lastUpdatedSubject != null && lastUpdatedSubject != sourceSubject;

  List<CompanyRequirement> get requiredRequirements =>
      requirements.where((r) => r.isRequired).toList(growable: false);

  List<CompanyRound> get orderedRounds {
    final sorted = [...rounds]..sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  CompanyRound? get finalRound =>
      orderedRounds.isEmpty ? null : orderedRounds.last;

  CompanyRound? roundById(String? roundId) {
    if (roundId == null) {
      return null;
    }
    for (final round in rounds) {
      if (round.id == roundId) {
        return round;
      }
    }
    return null;
  }

  factory Company.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Company(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      ctc: data['ctc'] as String?,
      stipend: data['stipend'] as String?,
      stipendPeriod: StipendPeriod.fromWire(data['stipendPeriod']),
      eligibleBranches:
          (data['eligibleBranches'] as List<dynamic>?)
              ?.map((branch) => branch.toString())
              .toList() ??
          const <String>[],
      eligibilityCriteria: data['eligibilityCriteria'] as String?,
      registrationDeadline: _toDate(data['registrationDeadline']),
      visitDate: _toDate(data['visitDate']),
      status: CompanyStatus.fromWire(data['status']),
      requirements:
          (data['requirements'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CompanyRequirement.fromMap)
              .toList() ??
          const <CompanyRequirement>[],
      rounds:
          (data['rounds'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CompanyRound.fromMap)
              .toList() ??
          const <CompanyRound>[],
      createdAt: _toDate(data['createdAt']),
      sourceSubject: data['sourceSubject'] as String?,
      sourceDate: _toDate(data['sourceDate']),
      lastUpdatedSubject:
          (data['lastUpdatedFrom'] as Map<String, dynamic>?)?['subject']
              as String?,
      lastUpdatedDate: _toDate(
        (data['lastUpdatedFrom'] as Map<String, dynamic>?)?['date'],
      ),
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'ctc': ctc,
      'stipend': stipend,
      'stipendPeriod': stipendPeriod.wireName,
      'eligibleBranches': eligibleBranches,
      'eligibilityCriteria': eligibilityCriteria,
      'registrationDeadline': registrationDeadline == null
          ? null
          : Timestamp.fromDate(registrationDeadline!),
      'visitDate': visitDate == null ? null : Timestamp.fromDate(visitDate!),
      'status': status.wireName,
      'requirements': requirements
          .map((requirement) => requirement.toMap())
          .toList(),
      'rounds': rounds.map((round) => round.toMap()).toList(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
