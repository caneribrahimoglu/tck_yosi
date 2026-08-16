import '../enums/technical_work_completion_decision.dart';

class TechnicalWorkCompletionRequest {
  final String id;
  final String workId;
  final String requestedByUserId;
  final String summary;
  final DateTime requestedAt;
  final TechnicalWorkCompletionDecision decision;
  final String? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const TechnicalWorkCompletionRequest({
    required this.id,
    required this.workId,
    required this.requestedByUserId,
    required this.summary,
    required this.requestedAt,
    this.decision = TechnicalWorkCompletionDecision.pending,
    this.reviewedByUserId,
    this.reviewedAt,
    this.rejectionReason,
  });

  TechnicalWorkCompletionRequest decided({
    required TechnicalWorkCompletionDecision decision,
    required String reviewedByUserId,
    required DateTime reviewedAt,
    String? rejectionReason,
  }) {
    return TechnicalWorkCompletionRequest(
      id: id,
      workId: workId,
      requestedByUserId: requestedByUserId,
      summary: summary,
      requestedAt: requestedAt,
      decision: decision,
      reviewedByUserId: reviewedByUserId,
      reviewedAt: reviewedAt,
      rejectionReason: rejectionReason,
    );
  }
}
