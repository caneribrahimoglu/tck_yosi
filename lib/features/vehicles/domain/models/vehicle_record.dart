import '../enums/vehicle_record_type.dart';
import '../enums/vehicle_fault_review_decision.dart';
import 'vehicle_fault_review.dart';

class VehicleRecord {
  final String id;
  final String vehicleId;
  final String usageSessionId;
  final VehicleRecordType type;
  final String title;
  final String description;
  final int mileage;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final List<VehicleFaultReview> faultReviews;

  const VehicleRecord({
    required this.id,
    required this.vehicleId,
    required this.usageSessionId,
    required this.type,
    required this.title,
    required this.description,
    required this.mileage,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    this.faultReviews = const [],
  });

  VehicleFaultReview? get latestFaultReview =>
      faultReviews.isEmpty ? null : faultReviews.last;

  bool get isFaultResolved =>
      latestFaultReview?.decision == VehicleFaultReviewDecision.resolve;

  VehicleRecord addFaultReview(VehicleFaultReview review) => VehicleRecord(
    id: id,
    vehicleId: vehicleId,
    usageSessionId: usageSessionId,
    type: type,
    title: title,
    description: description,
    mileage: mileage,
    createdByUserId: createdByUserId,
    createdByName: createdByName,
    createdAt: createdAt,
    faultReviews: List.unmodifiable([...faultReviews, review]),
  );
}
