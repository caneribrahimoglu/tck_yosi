import '../enums/technical_work_category.dart';
import '../enums/technical_work_priority.dart';
import '../enums/technical_work_status.dart';

class TechnicalWork {
  static const Object _notProvided = Object();

  final String id;
  final String title;
  final String description;
  final String location;
  final TechnicalWorkCategory category;
  final TechnicalWorkPriority priority;
  final TechnicalWorkStatus status;
  final String createdByUserId;
  final String? assignedToUserId;
  final String? assignedToTeamId;
  final DateTime createdAt;
  final DateTime? plannedAt;
  final DateTime? completedAt;
  final String? startedByUserId;
  final DateTime? startedAt;

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
    this.assignedToTeamId,
    this.plannedAt,
    this.completedAt,
    this.startedByUserId,
    this.startedAt,
  });

  bool get isAssigned => assignedToUserId != null || assignedToTeamId != null;

  TechnicalWork copyWith({
    TechnicalWorkPriority? priority,
    TechnicalWorkStatus? status,
    Object? assignedToUserId = _notProvided,
    Object? assignedToTeamId = _notProvided,
    Object? startedByUserId = _notProvided,
    Object? startedAt = _notProvided,
    Object? completedAt = _notProvided,
  }) {
    return TechnicalWork(
      id: id,
      title: title,
      description: description,
      location: location,
      category: category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdByUserId: createdByUserId,
      assignedToUserId: identical(assignedToUserId, _notProvided)
          ? this.assignedToUserId
          : assignedToUserId as String?,
      assignedToTeamId: identical(assignedToTeamId, _notProvided)
          ? this.assignedToTeamId
          : assignedToTeamId as String?,
      createdAt: createdAt,
      plannedAt: plannedAt,
      completedAt: identical(completedAt, _notProvided)
          ? this.completedAt
          : completedAt as DateTime?,
      startedByUserId: identical(startedByUserId, _notProvided)
          ? this.startedByUserId
          : startedByUserId as String?,
      startedAt: identical(startedAt, _notProvided)
          ? this.startedAt
          : startedAt as DateTime?,
    );
  }

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
