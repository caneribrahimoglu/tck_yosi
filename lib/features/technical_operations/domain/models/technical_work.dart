import '../enums/technical_work_category.dart';
import '../enums/technical_work_priority.dart';
import '../enums/technical_work_status.dart';

class TechnicalWork {
  final String id;
  final String title;
  final String description;
  final String location;
  final TechnicalWorkCategory category;
  final TechnicalWorkPriority priority;
  final TechnicalWorkStatus status;
  final String createdByUserId;
  final String? assignedToUserId;
  final DateTime createdAt;
  final DateTime? plannedAt;
  final DateTime? completedAt;

  const TechnicalWork({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdByUserId,
    required this.createdAt,
    this.assignedToUserId,
    this.plannedAt,
    this.completedAt,
  });

  bool get isAssigned => assignedToUserId != null;

  bool get isCritical {
    return priority == TechnicalWorkPriority.critical;
  }

  bool get isCompleted {
    return status == TechnicalWorkStatus.completed;
  }

  bool get isOpen {
    return status != TechnicalWorkStatus.completed &&
        status != TechnicalWorkStatus.cancelled;
  }
}
