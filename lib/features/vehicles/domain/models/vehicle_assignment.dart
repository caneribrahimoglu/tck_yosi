class VehicleAssignment {
  final String id;
  final String vehicleId;
  final String assignedToUserId;
  final String assignedToName;
  final DateTime assignedAt;
  final DateTime? endedAt;

  const VehicleAssignment({
    required this.id,
    required this.vehicleId,
    required this.assignedToUserId,
    required this.assignedToName,
    required this.assignedAt,
    this.endedAt,
  });

  bool get isActive => endedAt == null;

  VehicleAssignment end(DateTime endedAt) => VehicleAssignment(
    id: id,
    vehicleId: vehicleId,
    assignedToUserId: assignedToUserId,
    assignedToName: assignedToName,
    assignedAt: assignedAt,
    endedAt: endedAt,
  );
}
