import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../fake_technical_work_data.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/create_field_report_request.dart';

class FakeTechnicalWorkRepository implements TechnicalWorkRepository {
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
