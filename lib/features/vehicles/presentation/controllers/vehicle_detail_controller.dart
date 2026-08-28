import 'package:flutter/foundation.dart';

import '../../domain/models/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import 'vehicle_detail_load_status.dart';

class VehicleDetailController extends ChangeNotifier {
  final VehicleRepository _repository;

  VehicleDetailLoadStatus _status = VehicleDetailLoadStatus.initial;
  Vehicle? _vehicle;
  String? _errorMessage;

  VehicleDetailController({required VehicleRepository repository})
    : _repository = repository;

  VehicleDetailLoadStatus get status => _status;
  Vehicle? get vehicle => _vehicle;
  String? get errorMessage => _errorMessage;

  Future<void> load(String vehicleId) async {
    if (_status == VehicleDetailLoadStatus.loading) {
      return;
    }

    _status = VehicleDetailLoadStatus.loading;
    _vehicle = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final vehicle = await _repository.getVehicleById(vehicleId);
      if (vehicle == null) {
        _status = VehicleDetailLoadStatus.notFound;
      } else {
        _vehicle = vehicle;
        _status = VehicleDetailLoadStatus.loaded;
      }
    } catch (_) {
      _errorMessage = 'Araç detayı yüklenemedi.';
      _status = VehicleDetailLoadStatus.failure;
    }

    notifyListeners();
  }
}
