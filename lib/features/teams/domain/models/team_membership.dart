class TeamMembership {
  final String id;
  final String teamId;
  final String userId;
  final bool isActive;

  const TeamMembership({
    required this.id,
    required this.teamId,
    required this.userId,
    this.isActive = true,
  });
}
