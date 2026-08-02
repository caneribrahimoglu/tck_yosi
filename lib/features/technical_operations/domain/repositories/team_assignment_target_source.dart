import '../models/assignment_target.dart';

abstract interface class TeamAssignmentTargetSource {
  Future<List<AssignmentTarget>> getActiveTeamTargets();
}
