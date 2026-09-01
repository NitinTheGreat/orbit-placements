import 'package:cloud_firestore/cloud_firestore.dart';

import 'company.dart';

enum RoundResult {
  invited('invited', 'Invited'),
  cleared('cleared', 'Cleared'),
  rejected('rejected', 'Not selected'),
  pending('pending', 'Pending');

  const RoundResult(this.wireName, this.label);

  final String wireName;
  final String label;

  static RoundResult fromWire(Object? value) {
    return RoundResult.values.firstWhere(
      (result) => result.wireName == value,
      orElse: () => RoundResult.pending,
    );
  }
}

enum OverallStatus {
  active('active', 'In the running'),
  selected('selected', 'Selected'),
  rejected('rejected', 'Not selected'),
  withdrawn('withdrawn', 'Withdrawn');

  const OverallStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static OverallStatus fromWire(Object? value) {
    return OverallStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => OverallStatus.active,
    );
  }
}

enum StatusSource {
  gmailIngestion('gmail_ingestion'),
  adminManual('admin_manual');

  const StatusSource(this.wireName);

  final String wireName;

  static StatusSource fromWire(Object? value) {
    return StatusSource.values.firstWhere(
      (source) => source.wireName == value,
      orElse: () => StatusSource.gmailIngestion,
    );
  }
}

class RoundHistoryEntry {
  const RoundHistoryEntry({
    required this.roundId,
    required this.result,
    this.updatedAt,
    this.sourceMessageId,
  });

  final String roundId;
  final RoundResult result;
  final DateTime? updatedAt;
  final String? sourceMessageId;

  factory RoundHistoryEntry.fromMap(Map<String, dynamic> map) {
    return RoundHistoryEntry(
      roundId: map['roundId'] as String? ?? '',
      result: RoundResult.fromWire(map['result']),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      sourceMessageId: map['sourceMessageId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roundId': roundId,
      'result': result.wireName,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      'sourceMessageId': sourceMessageId,
    };
  }
}

class StudentCompanyStatus {
  const StudentCompanyStatus({
    required this.studentId,
    required this.companyId,
    this.currentRoundId,
    this.roundHistory = const <RoundHistoryEntry>[],
    this.overallStatus = OverallStatus.active,
    this.optedIn,
    this.completedRequirementIds = const <String>[],
    this.updatedAt,
    this.source = StatusSource.gmailIngestion,
  });

  final String studentId;
  final String companyId;
  final String? currentRoundId;
  final List<RoundHistoryEntry> roundHistory;
  final OverallStatus overallStatus;
  final bool? optedIn;
  final List<String> completedRequirementIds;
  final DateTime? updatedAt;
  final StatusSource source;

  String get id => docIdFor(studentId: studentId, companyId: companyId);

  bool get isOptedOut => optedIn == false;

  static String docIdFor({
    required String studentId,
    required String companyId,
  }) {
    return '${studentId}_$companyId';
  }

  RoundHistoryEntry? entryFor(String roundId) {
    for (final entry in roundHistory) {
      if (entry.roundId == roundId) {
        return entry;
      }
    }
    return null;
  }

  static String? resolveCurrentRoundId(
    List<RoundHistoryEntry> history,
    Company company,
  ) {
    String? bestId;
    int? bestOrder;
    for (final entry in history) {
      if (entry.result == RoundResult.rejected) {
        continue;
      }
      final round = company.roundById(entry.roundId);
      if (round == null) {
        continue;
      }
      if (bestOrder == null || round.order > bestOrder) {
        bestOrder = round.order;
        bestId = round.id;
      }
    }
    return bestId;
  }

  static OverallStatus resolveOverallStatus(
    List<RoundHistoryEntry> history,
    Company company,
  ) {
    if (history.any((entry) => entry.result == RoundResult.rejected)) {
      return OverallStatus.rejected;
    }
    final finalRound = company.finalRound;
    if (finalRound != null) {
      for (final entry in history) {
        if (entry.roundId == finalRound.id &&
            entry.result == RoundResult.cleared) {
          return OverallStatus.selected;
        }
      }
    }
    return OverallStatus.active;
  }

  factory StudentCompanyStatus.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return StudentCompanyStatus(
      studentId: data['studentId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      currentRoundId: data['currentRoundId'] as String?,
      roundHistory:
          (data['roundHistory'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(RoundHistoryEntry.fromMap)
              .toList() ??
          const <RoundHistoryEntry>[],
      overallStatus: OverallStatus.fromWire(data['overallStatus']),
      optedIn: data['optedIn'] as bool?,
      completedRequirementIds:
          (data['completedRequirementIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          const <String>[],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      source: StatusSource.fromWire(data['source']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'studentId': studentId,
      'companyId': companyId,
      'currentRoundId': currentRoundId,
      'roundHistory': roundHistory.map((entry) => entry.toMap()).toList(),
      'overallStatus': overallStatus.wireName,
      'optedIn': optedIn,
      'completedRequirementIds': completedRequirementIds,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      'source': source.wireName,
    };
  }
}
