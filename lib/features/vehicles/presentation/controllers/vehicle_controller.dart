import 'package:flutter/foundation.dart';

import '../../../auth/domain/enums/app_permission.dart';
import '../../../auth/domain/enums/user_role.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/services/app_user_directory.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/models/update_vehicle_request.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/vehicle_repository_exception.dart';
import 'vehicle_load_status.dart';

class VehicleController extends ChangeNotifier {
  final VehicleRepository _repository;
  final AppUserDirectory? _userDirectory;

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
  List<AppUser> _assignmentCandidates = const [];
  bool _isLoadingAssignmentCandidates = false;
  bool _isAssigning = false;
  String? _assignmentErrorMessage;

  VehicleController({
    required VehicleRepository repository,
    AppUserDirectory? userDirectory,
  }) : _repository = repository,
       _userDirectory = userDirectory;

  VehicleLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isCreating => _isCreating;
  String? get creationErrorMessage => _creationErrorMessage;
  bool get isUpdating => _isUpdating;
  String? get updateErrorMessage => _updateErrorMessage;
  List<AppUser> get assignmentCandidates =>
      List.unmodifiable(_assignmentCandidates);
  bool get isLoadingAssignmentCandidates => _isLoadingAssignmentCandidates;
  bool get isAssigning => _isAssigning;
  String? get assignmentErrorMessage => _assignmentErrorMessage;
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

  Future<void> loadAssignmentCandidates() async {
    final directory = _userDirectory;
    if (directory == null || _isLoadingAssignmentCandidates) {
      return;
    }
    _isLoadingAssignmentCandidates = true;
    _assignmentErrorMessage = null;
    notifyListeners();
    try {
      final users = await directory.getAllUsers();
      _assignmentCandidates = List.unmodifiable(
        users.where(
          (user) =>
              user.isActive &&
              user.hasPermission(AppPermission.viewAssignedVehicle) &&
              user.role != UserRole.chief &&
              user.role != UserRole.director &&
              user.role != UserRole.admin,
        ),
      );
    } catch (_) {
      _assignmentCandidates = const [];
      _assignmentErrorMessage = 'Atanabilir personel listesi yüklenemedi.';
    } finally {
      _isLoadingAssignmentCandidates = false;
      notifyListeners();
    }
  }

  Future<VehicleAssignment?> assignVehicle({
    required String vehicleId,
    required AppUser user,
  }) async {
    if (_isAssigning) {
      return null;
    }
    _isAssigning = true;
    _assignmentErrorMessage = null;
    notifyListeners();
    try {
      return await _repository.assignVehicle(
        vehicleId: vehicleId,
        userId: user.id,
        userName: user.fullName,
      );
    } on VehicleRepositoryException catch (error) {
      _assignmentErrorMessage = error.message;
      return null;
    } catch (_) {
      _assignmentErrorMessage = 'Araç personele atanamadı.';
      return null;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }

  Future<bool> releaseVehicle(String vehicleId) async {
    if (_isAssigning) {
      return false;
    }
    _isAssigning = true;
    _assignmentErrorMessage = null;
    notifyListeners();
    try {
      await _repository.releaseVehicle(vehicleId);
      return true;
    } on VehicleRepositoryException catch (error) {
      _assignmentErrorMessage = error.message;
      return false;
    } catch (_) {
      _assignmentErrorMessage = 'Araç ataması sonlandırılamadı.';
      return false;
    } finally {
      _isAssigning = false;
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
