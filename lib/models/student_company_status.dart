import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentStage {
  applied('applied', 'Applied'),
  shortlistedPpt('shortlisted_ppt', 'Shortlisted for PPT'),
  shortlistedOa('shortlisted_oa', 'Shortlisted for OA'),
  selected('selected', 'Selected'),
  rejected('rejected', 'Rejected'),
  unknown('unknown', 'Unknown');

  const StudentStage(this.wireName, this.label);

  final String wireName;
  final String label;

  static StudentStage fromWire(Object? value) {
    return StudentStage.values.firstWhere(
      (stage) => stage.wireName == value,
      orElse: () => StudentStage.unknown,
    );
  }
}

class StudentCompanyStatus {
  const StudentCompanyStatus({
    required this.studentId,
    required this.companyId,
    this.stage = StudentStage.unknown,
    this.updatedAt,
    this.source,
  });

  final String studentId;
  final String companyId;
  final StudentStage stage;
  final DateTime? updatedAt;
  final String? source;

  String get id => docIdFor(studentId: studentId, companyId: companyId);

  static String docIdFor({
    required String studentId,
    required String companyId,
  }) {
    return '${studentId}_$companyId';
  }

  factory StudentCompanyStatus.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return StudentCompanyStatus(
      studentId: data['studentId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      stage: StudentStage.fromWire(data['stage']),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'studentId': studentId,
      'companyId': companyId,
      'stage': stage.wireName,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      'source': source,
    };
  }
}
