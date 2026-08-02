import '../../../technical_operations/domain/enums/assignment_target_type.dart';
import '../../../technical_operations/domain/models/assignment_target.dart';
import '../../../technical_operations/domain/repositories/team_assignment_target_source.dart';
import '../../domain/repositories/team_repository.dart';

class TeamAssignmentTargetAdapter implements TeamAssignmentTargetSource {
  final TeamRepository _repository;

  const TeamAssignmentTargetAdapter({required TeamRepository repository})
    : _repository = repository;

  @override
  Future<List<AssignmentTarget>> getActiveTeamTargets() async {
    final teams = await _repository.getTeams();
    return teams
        .where((team) => team.isActive && !team.isArchived)
        .map(
          (team) => AssignmentTarget(
            id: team.id,
            name: team.name,
            type: AssignmentTargetType.team,
          ),
        )
        .toList(growable: false);
  }
}
