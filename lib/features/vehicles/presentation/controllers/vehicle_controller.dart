import 'package:flutter/foundation.dart';

import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/models/update_vehicle_request.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/vehicle_repository_exception.dart';
import 'vehicle_load_status.dart';

class VehicleController extends ChangeNotifier {
  final VehicleRepository _repository;

  VehicleLoadStatus _status = VehicleLoadStatus.initial;
  List<Vehicle> _allVehicles = const [];
  String _searchQuery = '';
  VehicleOwnershipType? _ownershipFilter;
  VehicleOperationalStatus? _statusFilter;
  String? _errorMessage;
  bool _isCreating = false;
  String? _creationErrorMessage;
  bool _isUpdating = false;
  String? _updateErrorMessage;

  VehicleController({required VehicleRepository repository})
    : _repository = repository;

  VehicleLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isCreating => _isCreating;
  String? get creationErrorMessage => _creationErrorMessage;
  bool get isUpdating => _isUpdating;
  String? get updateErrorMessage => _updateErrorMessage;
  String get searchQuery => _searchQuery;
  VehicleOwnershipType? get ownershipFilter => _ownershipFilter;
  VehicleOperationalStatus? get statusFilter => _statusFilter;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _ownershipFilter != null ||
      _statusFilter != null;

  List<Vehicle> get allVehicles => List.unmodifiable(_allVehicles);

  List<Vehicle> get vehicles {
    final normalizedQuery = _normalize(_searchQuery);
    return List.unmodifiable(
      _allVehicles.where((vehicle) {
        final matchesQuery =
            normalizedQuery.isEmpty ||
            _normalize(vehicle.licensePlate).contains(normalizedQuery) ||
            _normalize(vehicle.brand).contains(normalizedQuery) ||
            _normalize(vehicle.model).contains(normalizedQuery);
        final matchesOwnership =
            _ownershipFilter == null ||
            vehicle.ownershipType == _ownershipFilter;
        final matchesStatus =
            _statusFilter == null || vehicle.operationalStatus == _statusFilter;
        return matchesQuery && matchesOwnership && matchesStatus;
      }),
    );
  }

  int get totalCount => _allVehicles.length;
  int get activeCount => _allVehicles
      .where(
        (vehicle) =>
            vehicle.operationalStatus == VehicleOperationalStatus.active,
      )
      .length;
  int get maintenanceCount => _allVehicles
      .where(
        (vehicle) =>
            vehicle.operationalStatus == VehicleOperationalStatus.maintenance,
      )
      .length;
  int get contractedCount => _allVehicles
      .where(
        (vehicle) => vehicle.ownershipType == VehicleOwnershipType.contracted,
      )
      .length;

  Future<void> load() async {
    if (_status == VehicleLoadStatus.loading) {
      return;
    }
    _status = VehicleLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _allVehicles = List.unmodifiable(await _repository.getAllVehicles());
      _status = VehicleLoadStatus.loaded;
    } catch (_) {
      _allVehicles = const [];
      _errorMessage = 'Araç bilgileri yüklenemedi.';
      _status = VehicleLoadStatus.failure;
    }
    notifyListeners();
  }

  Future<Vehicle?> createVehicle(CreateVehicleRequest request) async {
    if (_isCreating) {
      return null;
    }
    _isCreating = true;
    _creationErrorMessage = null;
    notifyListeners();
    try {
      final vehicle = await _repository.createVehicle(request);
      _allVehicles = List.unmodifiable([..._allVehicles, vehicle]);
      _status = VehicleLoadStatus.loaded;
      return vehicle;
    } on VehicleRepositoryException catch (error) {
      _creationErrorMessage = error.message;
      return null;
    } catch (_) {
      _creationErrorMessage = 'Araç kaydı oluşturulamadı.';
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<Vehicle?> updateVehicle({
    required String vehicleId,
    required UpdateVehicleRequest request,
  }) async {
    if (_isUpdating) {
      return null;
    }
    _isUpdating = true;
    _updateErrorMessage = null;
    notifyListeners();
    try {
      final updatedVehicle = await _repository.updateVehicle(
        vehicleId: vehicleId,
        request: request,
      );
      _allVehicles = List.unmodifiable([
        for (final vehicle in _allVehicles)
          if (vehicle.id == vehicleId) updatedVehicle else vehicle,
      ]);
      return updatedVehicle;
    } on VehicleRepositoryException catch (error) {
      _updateErrorMessage = error.message;
      return null;
    } catch (_) {
      _updateErrorMessage = 'Araç bilgileri güncellenemedi.';
      return null;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    final normalizedValue = value.trim();
    if (_searchQuery == normalizedValue) {
      return;
    }
    _searchQuery = normalizedValue;
    notifyListeners();
  }

  void setOwnershipFilter(VehicleOwnershipType? value) {
    if (_ownershipFilter == value) {
      return;
    }
    _ownershipFilter = value;
    notifyListeners();
  }

  void setStatusFilter(VehicleOperationalStatus? value) {
    if (_statusFilter == value) {
      return;
    }
    _statusFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    if (!hasActiveFilters) {
      return;
    }
    _searchQuery = '';
    _ownershipFilter = null;
    _statusFilter = null;
    notifyListeners();
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll('ı', 'i');
}
