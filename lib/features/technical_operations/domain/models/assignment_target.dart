import '../enums/assignment_target_type.dart';

class AssignmentTarget {
  final String id;
  final String name;
  final AssignmentTargetType type;

  const AssignmentTarget({
    required this.id,
    required this.name,
    required this.type,
  });
}
