import '../../../auth/domain/enums/app_permission.dart';

class Team {
  static const Object _notProvided = Object();

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool isArchived;
  final Set<AppPermission> permissions;

  const Team({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.isArchived = false,
    required this.permissions,
  });

  Team copyWith({
    String? name,
    String? description,
    bool? isActive,
    bool? isArchived,
    Object? permissions = _notProvided,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      permissions: identical(permissions, _notProvided)
          ? this.permissions
          : Set.unmodifiable(permissions! as Set<AppPermission>),
    );
  }
}
