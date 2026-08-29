import 'package:flutter/foundation.dart';

import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../../domain/models/vehicle_usage_session.dart';
import '../../domain/models/vehicle_record.dart';
import '../../domain/repositories/vehicle_repository.dart';
import 'vehicle_detail_load_status.dart';

class VehicleDetailController extends ChangeNotifier {
  final VehicleRepository _repository;

  VehicleDetailLoadStatus _status = VehicleDetailLoadStatus.initial;
  Vehicle? _vehicle;
  String? _errorMessage;
  List<VehicleAssignment> _assignments = const [];
  List<VehicleUsageSession> _usageSessions = const [];
  List<VehicleRecord> _records = const [];

  VehicleDetailController({required VehicleRepository repository})
    : _repository = repository;

  VehicleDetailLoadStatus get status => _status;
  Vehicle? get vehicle => _vehicle;
  String? get errorMessage => _errorMessage;
  List<VehicleAssignment> get assignments => List.unmodifiable(_assignments);
  List<VehicleUsageSession> get usageSessions =>
      List.unmodifiable(_usageSessions);
  List<VehicleRecord> get records => List.unmodifiable(_records);
  VehicleAssignment? get currentAssignment {
    for (final assignment in _assignments) {
      if (assignment.isActive) {
        return assignment;
      }
    }
    return null;
  }

  Future<void> load(String vehicleId) async {
    if (_status == VehicleDetailLoadStatus.loading) {
      return;
    }

    _status = VehicleDetailLoadStatus.loading;
    _vehicle = null;
    _errorMessage = null;
    _assignments = const [];
    _usageSessions = const [];
    _records = const [];
    notifyListeners();

    try {
      final vehicle = await _repository.getVehicleById(vehicleId);
      if (vehicle == null) {
        _status = VehicleDetailLoadStatus.notFound;
      } else {
        _vehicle = vehicle;
        _assignments = List.unmodifiable(
          await _repository.getVehicleAssignments(vehicleId),
        );
        _usageSessions = List.unmodifiable(
          await _repository.getVehicleUsageSessions(vehicleId),
        );
        _records = List.unmodifiable(
          await _repository.getVehicleRecords(vehicleId),
        );
        _status = VehicleDetailLoadStatus.loaded;
      }
    } catch (_) {
      _errorMessage = 'Araç detayı yüklenemedi.';
      _status = VehicleDetailLoadStatus.failure;
    }

    notifyListeners();
  }
}
