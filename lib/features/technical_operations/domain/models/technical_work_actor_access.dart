class TechnicalWorkActorAccess {
  final Set<String> activeTeamIds;
  final bool canStartTechnicalWork;

  const TechnicalWorkActorAccess({
    required this.activeTeamIds,
    required this.canStartTechnicalWork,
  });
}
