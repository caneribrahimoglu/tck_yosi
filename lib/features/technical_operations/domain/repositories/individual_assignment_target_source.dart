import '../models/assignment_target.dart';

abstract interface class IndividualAssignmentTargetSource {
  Future<List<AssignmentTarget>> getIndividualAssignmentTargets();
}
