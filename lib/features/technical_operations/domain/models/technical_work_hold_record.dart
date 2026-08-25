class TechnicalWorkHoldRecord {
  final String id;
  final String workId;
  final String heldByUserId;
  final DateTime heldAt;
  final String reason;
  final String? resumedByUserId;
  final DateTime? resumedAt;

  const TechnicalWorkHoldRecord({
    required this.id,
    required this.workId,
    required this.heldByUserId,
    required this.heldAt,
    required this.reason,
    this.resumedByUserId,
    this.resumedAt,
  });

  bool get isResumed => resumedAt != null;

  TechnicalWorkHoldRecord resumed({
    required String resumedByUserId,
    required DateTime resumedAt,
  }) {
    return TechnicalWorkHoldRecord(
      id: id,
      workId: workId,
      heldByUserId: heldByUserId,
      heldAt: heldAt,
      reason: reason,
      resumedByUserId: resumedByUserId,
      resumedAt: resumedAt,
    );
  }
}
