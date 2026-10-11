import '../../../auth/domain/enums/user_role.dart';
import '../../../auth/domain/services/app_user_directory.dart';
import '../../../technical_operations/domain/enums/assignment_target_type.dart';
import '../../../technical_operations/domain/models/assignment_target.dart';
import '../../../technical_operations/domain/repositories/individual_assignment_target_source.dart';

class UserAssignmentTargetAdapter implements IndividualAssignmentTargetSource {
  final AppUserDirectory userDirectory;
  const UserAssignmentTargetAdapter({required this.userDirectory});
  @override
  Future<List<AssignmentTarget>> getIndividualAssignmentTargets() async =>
      List.unmodifiable(
        (await userDirectory.getAllUsers())
            .where((user) => user.isActive && user.role == UserRole.engineer)
            .map(
              (user) => AssignmentTarget(
                id: user.id,
                name: user.fullName,
                type: AssignmentTargetType.engineer,
              ),
            ),
      );
}
