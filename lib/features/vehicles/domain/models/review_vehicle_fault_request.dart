import '../enums/vehicle_fault_review_decision.dart';

class ReviewVehicleFaultRequest {
  final VehicleFaultReviewDecision decision;
  final String note;

  const ReviewVehicleFaultRequest({required this.decision, required this.note});
}
