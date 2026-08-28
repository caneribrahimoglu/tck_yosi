class VehicleRepositoryException implements Exception {
  final String message;

  const VehicleRepositoryException(this.message);

  @override
  String toString() => message;
}
