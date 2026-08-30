import '../enums/vehicle_fault_review_decision.dart';

class VehicleFaultReview {
  final String id;
  final VehicleFaultReviewDecision decision;
  final String note;
  final String reviewedByUserId;
  final String reviewedByName;
  final DateTime reviewedAt;

  const VehicleFaultReview({
    required this.id,
    required this.decision,
    required this.note,
    required this.reviewedByUserId,
    required this.reviewedByName,
    required this.reviewedAt,
  });
}
