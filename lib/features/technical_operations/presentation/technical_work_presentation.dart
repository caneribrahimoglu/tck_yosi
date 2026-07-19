import 'package:flutter/material.dart';

import '../../../core/enums/app_status_type.dart';
import '../domain/enums/technical_work_category.dart';
import '../domain/enums/technical_work_priority.dart';
import '../domain/enums/technical_work_status.dart';

extension TechnicalWorkCategoryPresentation on TechnicalWorkCategory {
  IconData get icon {
    return switch (this) {
      TechnicalWorkCategory.roadSurface => Icons.add_road_rounded,
      TechnicalWorkCategory.lighting => Icons.lightbulb_outline_rounded,
      TechnicalWorkCategory.trafficSign => Icons.signpost_outlined,
      TechnicalWorkCategory.roadMarking => Icons.route_outlined,
      TechnicalWorkCategory.barrier => Icons.fence_outlined,
      TechnicalWorkCategory.drainage => Icons.water_damage_outlined,
      TechnicalWorkCategory.bridgeAndViaduct => Icons.account_balance_outlined,
      TechnicalWorkCategory.tunnel => Icons.directions_subway_outlined,
      TechnicalWorkCategory.landslide => Icons.landscape_outlined,
      TechnicalWorkCategory.building => Icons.business_outlined,
      TechnicalWorkCategory.electricalSystem =>
        Icons.electrical_services_outlined,
      TechnicalWorkCategory.vehicle => Icons.directions_car_outlined,
      TechnicalWorkCategory.workMachine => Icons.agriculture_outlined,
      TechnicalWorkCategory.other => Icons.construction_outlined,
    };
  }
}

extension TechnicalWorkPriorityPresentation on TechnicalWorkPriority {
  String get label {
    return switch (this) {
      TechnicalWorkPriority.low => 'Düşük',
      TechnicalWorkPriority.normal => 'Normal',
      TechnicalWorkPriority.high => 'Yüksek',
      TechnicalWorkPriority.critical => 'Kritik',
    };
  }

  AppStatusType get statusType {
    return switch (this) {
      TechnicalWorkPriority.low => AppStatusType.neutral,
      TechnicalWorkPriority.normal => AppStatusType.info,
      TechnicalWorkPriority.high => AppStatusType.warning,
      TechnicalWorkPriority.critical => AppStatusType.error,
    };
  }
}

extension TechnicalWorkStatusPresentation on TechnicalWorkStatus {
  String get label {
    return switch (this) {
      TechnicalWorkStatus.reported => 'Bildirildi',
      TechnicalWorkStatus.awaitingInspection => 'İnceleme Bekliyor',
      TechnicalWorkStatus.assigned => 'Ekibe Atandı',
      TechnicalWorkStatus.inProgress => 'Devam Ediyor',
      TechnicalWorkStatus.onHold => 'Beklemeye Alındı',
      TechnicalWorkStatus.completed => 'Tamamlandı',
      TechnicalWorkStatus.cancelled => 'İptal Edildi',
    };
  }

  AppStatusType get statusType {
    return switch (this) {
      TechnicalWorkStatus.reported => AppStatusType.neutral,
      TechnicalWorkStatus.awaitingInspection => AppStatusType.warning,
      TechnicalWorkStatus.assigned => AppStatusType.info,
      TechnicalWorkStatus.inProgress => AppStatusType.info,
      TechnicalWorkStatus.onHold => AppStatusType.warning,
      TechnicalWorkStatus.completed => AppStatusType.success,
      TechnicalWorkStatus.cancelled => AppStatusType.neutral,
    };
  }
}
