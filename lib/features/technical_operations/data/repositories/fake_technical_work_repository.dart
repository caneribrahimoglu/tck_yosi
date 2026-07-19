import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../fake_technical_work_data.dart';

class FakeTechnicalWorkRepository implements TechnicalWorkRepository {
  final List<TechnicalWork> _works;
  final Duration delay;

  FakeTechnicalWorkRepository({
    List<TechnicalWork>? works,
    this.delay = const Duration(milliseconds: 500),
  }) : _works = List.unmodifiable(works ?? FakeTechnicalWorkData.works);

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

  Future<void> _simulateNetworkDelay() async {
    if (delay == Duration.zero) {
      return;
    }

    await Future<void>.delayed(delay);
  }
}
