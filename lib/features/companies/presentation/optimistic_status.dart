import '../../../models/student_company_status.dart';

class OptimisticStatus {
  const OptimisticStatus({
    this.pendingRequirements = const <String, bool>{},
    this.pendingOptedIn,
  });

  final Map<String, bool> pendingRequirements;
  final bool? pendingOptedIn;

  bool get isEmpty => pendingRequirements.isEmpty && pendingOptedIn == null;

  bool isPending(String requirementId) =>
      pendingRequirements.containsKey(requirementId);

  bool get isOptedInPending => pendingOptedIn != null;

  OptimisticStatus withRequirement(String requirementId, bool completed) {
    return OptimisticStatus(
      pendingRequirements: <String, bool>{
        ...pendingRequirements,
        requirementId: completed,
      },
      pendingOptedIn: pendingOptedIn,
    );
  }

  OptimisticStatus withoutRequirement(String requirementId) {
    final next = <String, bool>{...pendingRequirements}..remove(requirementId);
    return OptimisticStatus(
      pendingRequirements: next,
      pendingOptedIn: pendingOptedIn,
    );
  }

  OptimisticStatus withOptedIn(bool optedIn) {
    return OptimisticStatus(
      pendingRequirements: pendingRequirements,
      pendingOptedIn: optedIn,
    );
  }

  OptimisticStatus withoutOptedIn() {
    return OptimisticStatus(pendingRequirements: pendingRequirements);
  }

  List<String> completedIds(List<String> serverIds) {
    final resolved = serverIds.toSet();
    pendingRequirements.forEach((id, completed) {
      if (completed) {
        resolved.add(id);
      } else {
        resolved.remove(id);
      }
    });
    return resolved.toList(growable: false);
  }

  bool optedIn(bool? serverOptedIn) {
    return pendingOptedIn ?? serverOptedIn ?? true;
  }

  OptimisticStatus reconcile(StudentCompanyStatus? status) {
    final serverIds = (status?.completedRequirementIds ?? const <String>[])
        .toSet();
    final remaining = <String, bool>{};
    pendingRequirements.forEach((id, completed) {
      if (serverIds.contains(id) != completed) {
        remaining[id] = completed;
      }
    });

    final serverOptedIn = status?.optedIn ?? true;
    final optedInStillPending =
        pendingOptedIn != null && pendingOptedIn != serverOptedIn;

    return OptimisticStatus(
      pendingRequirements: remaining,
      pendingOptedIn: optedInStillPending ? pendingOptedIn : null,
    );
  }

  StudentCompanyStatus? applyTo(
    StudentCompanyStatus? status, {
    required String studentId,
    required String companyId,
  }) {
    if (isEmpty && status == null) {
      return null;
    }
    final base =
        status ??
        StudentCompanyStatus(studentId: studentId, companyId: companyId);
    return StudentCompanyStatus(
      studentId: base.studentId,
      companyId: base.companyId,
      currentRoundId: base.currentRoundId,
      roundHistory: base.roundHistory,
      overallStatus: base.overallStatus,
      optedIn: pendingOptedIn ?? base.optedIn,
      completedRequirementIds: completedIds(base.completedRequirementIds),
      updatedAt: base.updatedAt,
      source: base.source,
    );
  }
}
