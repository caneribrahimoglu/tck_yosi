import 'package:flutter/material.dart';

import '../../../core/enums/app_status_type.dart';
import '../domain/enums/vehicle_operational_status.dart';
import '../domain/enums/vehicle_ownership_type.dart';
import '../domain/enums/vehicle_type.dart';
import '../domain/models/vehicle.dart';

extension VehiclePresentation on Vehicle {
  String get formattedMileage => '${_formatNumber(currentMileage)} km';
}

extension VehicleOwnershipTypePresentation on VehicleOwnershipType {
  String get label => switch (this) {
    VehicleOwnershipType.institutionOwned => 'Kuruma Ait',
    VehicleOwnershipType.contracted => 'Sözleşmeli',
  };

  AppStatusType get statusType => switch (this) {
    VehicleOwnershipType.institutionOwned => AppStatusType.info,
    VehicleOwnershipType.contracted => AppStatusType.warning,
  };
}

extension VehicleOperationalStatusPresentation on VehicleOperationalStatus {
  String get label => switch (this) {
    VehicleOperationalStatus.active => 'Aktif',
    VehicleOperationalStatus.maintenance => 'Bakımda',
    VehicleOperationalStatus.outOfService => 'Hizmet Dışı',
  };

  AppStatusType get statusType => switch (this) {
    VehicleOperationalStatus.active => AppStatusType.success,
    VehicleOperationalStatus.maintenance => AppStatusType.warning,
    VehicleOperationalStatus.outOfService => AppStatusType.error,
  };
}

extension VehicleTypePresentation on VehicleType {
  String get label => switch (this) {
    VehicleType.passengerCar => 'Binek',
    VehicleType.pickup => 'Kamyonet',
    VehicleType.truck => 'Kamyon',
    VehicleType.workMachine => 'İş Makinesi',
  };

  IconData get icon => switch (this) {
    VehicleType.passengerCar => Icons.directions_car_outlined,
    VehicleType.pickup => Icons.local_shipping_outlined,
    VehicleType.truck => Icons.fire_truck_outlined,
    VehicleType.workMachine => Icons.agriculture_outlined,
  };
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
