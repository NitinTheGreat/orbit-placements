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
      announcedAt: (map['announcedAt'] as Timestamp?)?.toDate(),
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

class CompanyRequirement {
  const CompanyRequirement({
    required this.id,
    required this.type,
    required this.label,
    this.url,
    this.isRequired = false,
  });

  final String id;
  final String type;
  final String label;
  final String? url;
  final bool isRequired;

  factory CompanyRequirement.fromMap(Map<String, dynamic> map) {
    final label = map['label'] as String? ?? '';
    return CompanyRequirement(
      id: map['id'] as String? ?? slugify(label),
      type: map['type'] as String? ?? 'other',
      label: label,
      url: map['url'] as String?,
      isRequired: map['required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'label': label,
      'url': url,
      'required': isRequired,
    };
  }

  CompanyRequirement copyWith({
    String? id,
    String? type,
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
    this.eligibleBranches = const <String>[],
    this.eligibilityCriteria,
    this.registrationDeadline,
    this.visitDate,
    this.status = CompanyStatus.registrationOpen,
    this.requirements = const <CompanyRequirement>[],
    this.rounds = const <CompanyRound>[],
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String? ctc;
  final String? stipend;
  final List<String> eligibleBranches;
  final String? eligibilityCriteria;
  final DateTime? registrationDeadline;
  final DateTime? visitDate;
  final CompanyStatus status;
  final List<CompanyRequirement> requirements;
  final List<CompanyRound> rounds;
  final DateTime? createdAt;

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
      eligibleBranches:
          (data['eligibleBranches'] as List<dynamic>?)
              ?.map((branch) => branch.toString())
              .toList() ??
          const <String>[],
      eligibilityCriteria: data['eligibilityCriteria'] as String?,
      registrationDeadline: (data['registrationDeadline'] as Timestamp?)
          ?.toDate(),
      visitDate: (data['visitDate'] as Timestamp?)?.toDate(),
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'ctc': ctc,
      'stipend': stipend,
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
