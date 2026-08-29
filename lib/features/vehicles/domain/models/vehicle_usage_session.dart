import 'vehicle_inspection.dart';

class VehicleUsageSession {
  final String id;
  final String assignmentId;
  final String vehicleId;
  final String userId;
  final String userName;
  final DateTime receivedAt;
  final int receivedMileage;
  final VehicleInspection receiveInspection;
  final DateTime? returnedAt;
  final int? returnedMileage;
  final VehicleInspection? returnInspection;

  const VehicleUsageSession({
    required this.id,
    required this.assignmentId,
    required this.vehicleId,
    required this.userId,
    required this.userName,
    required this.receivedAt,
    required this.receivedMileage,
    required this.receiveInspection,
    this.returnedAt,
    this.returnedMileage,
    this.returnInspection,
  });

  bool get isActive => returnedAt == null;

  VehicleUsageSession close({
    required DateTime returnedAt,
    required int returnedMileage,
    required VehicleInspection returnInspection,
  }) => VehicleUsageSession(
    id: id,
    assignmentId: assignmentId,
    vehicleId: vehicleId,
    userId: userId,
    userName: userName,
    receivedAt: receivedAt,
    receivedMileage: receivedMileage,
    receiveInspection: receiveInspection,
    returnedAt: returnedAt,
    returnedMileage: returnedMileage,
    returnInspection: returnInspection,
  );
}
