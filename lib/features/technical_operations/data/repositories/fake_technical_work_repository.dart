import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../fake_technical_work_data.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/create_field_report_request.dart';
import '../../domain/enums/assignment_target_type.dart';
import '../../domain/models/assignment_target.dart';

class FakeTechnicalWorkRepository implements TechnicalWorkRepository {
  static const assignmentTargets = [
    AssignmentTarget(
      id: 'user-engineer-001',
      name: 'Zeynep Demir',
      type: AssignmentTargetType.engineer,
    ),
    AssignmentTarget(
      id: 'team-road-maintenance',
      name: 'Yol Bakım Ekibi',
      type: AssignmentTargetType.team,
    ),
    AssignmentTarget(
      id: 'team-electrical',
      name: 'Elektrik Ekibi',
      type: AssignmentTargetType.team,
    ),
  ];
  final List<TechnicalWork> _works;
  final Duration delay;

  FakeTechnicalWorkRepository({
    List<TechnicalWork>? works,
    this.delay = const Duration(milliseconds: 500),
  }) : _works = List.of(works ?? FakeTechnicalWorkData.works);

  @override
  Future<List<TechnicalWork>> getAllWorks() async {
    await _simulateNetworkDelay();

    return List.unmodifiable(_works);
  }

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) async {
    await _simulateNetworkDelay();

    return _works
        .where((work) => work.assignedToUserId == userId)
        .toList(growable: false);
  }

  @override
  Future<List<AssignmentTarget>> getAssignmentTargets() async {
    await _simulateNetworkDelay();
    return assignmentTargets;
  }

  @override
  Future<TechnicalWork> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    await _simulateNetworkDelay();

    final workIndex = _works.indexWhere((work) => work.id == workId);
    if (workIndex == -1) {
      throw StateError('Atanacak teknik iş bulunamadı.');
    }

    final updatedWork = _works[workIndex].copyWith(
      priority: priority,
      status: TechnicalWorkStatus.assigned,
      assignedToUserId: target.type == AssignmentTargetType.engineer
          ? target.id
          : null,
      assignedToTeamId: target.type == AssignmentTargetType.team
          ? target.id
          : null,
    );
    _works[workIndex] = updatedWork;
    return updatedWork;
  }

  @override
  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    await _simulateNetworkDelay();

    final now = DateTime.now();
    final newWork = TechnicalWork(
      id: 'work-${now.millisecondsSinceEpoch}',
      title: request.title,
      location: request.location,
      description: request.description,
      category: request.category,
      status: TechnicalWorkStatus.reported,
      priority: TechnicalWorkPriority.normal,
      createdByUserId: createdByUserId,
      createdAt: now,
    );
    _works.add(newWork);
    return newWork;
  }

  Future<void> _simulateNetworkDelay() async {
    if (delay == Duration.zero) {
      return;
    }

    await Future<void>.delayed(delay);
  }
}
