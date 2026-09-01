import 'package:cloud_firestore/cloud_firestore.dart';

enum CompanyStatus {
  open('open', 'Open'),
  pptScheduled('ppt_scheduled', 'PPT scheduled'),
  shortlisting('shortlisting', 'Shortlisting'),
  oaScheduled('oa_scheduled', 'OA scheduled'),
  results('results', 'Results'),
  closed('closed', 'Closed');

  const CompanyStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static CompanyStatus fromWire(Object? value) {
    return CompanyStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => CompanyStatus.open,
    );
  }
}

class CompanyRequirement {
  const CompanyRequirement({
    required this.type,
    required this.label,
    this.url,
    this.isRequired = false,
  });

  final String type;
  final String label;
  final String? url;
  final bool isRequired;

  factory CompanyRequirement.fromMap(Map<String, dynamic> map) {
    return CompanyRequirement(
      type: map['type'] as String? ?? 'other',
      label: map['label'] as String? ?? '',
      url: map['url'] as String?,
      isRequired: map['required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'label': label,
      'url': url,
      'required': isRequired,
    };
  }

  CompanyRequirement copyWith({
    String? type,
    String? label,
    String? url,
    bool? isRequired,
  }) {
    return CompanyRequirement(
      type: type ?? this.type,
      label: label ?? this.label,
      url: url ?? this.url,
      isRequired: isRequired ?? this.isRequired,
    );
  }
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
    this.status = CompanyStatus.open,
    this.requirements = const <CompanyRequirement>[],
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
  final DateTime? createdAt;

  factory Company.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
      registrationDeadline:
          (data['registrationDeadline'] as Timestamp?)?.toDate(),
      visitDate: (data['visitDate'] as Timestamp?)?.toDate(),
      status: CompanyStatus.fromWire(data['status']),
      requirements:
          (data['requirements'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CompanyRequirement.fromMap)
              .toList() ??
          const <CompanyRequirement>[],
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
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
