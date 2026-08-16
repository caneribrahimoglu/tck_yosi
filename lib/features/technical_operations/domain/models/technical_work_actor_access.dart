class TechnicalWorkActorAccess {
  final Set<String> activeTeamIds;
  final bool canStartTechnicalWork;
  final bool canAddTechnicalWorkProgress;
  final bool isActive;
  final bool canViewAllTechnicalWork;

  const TechnicalWorkActorAccess({
    required this.activeTeamIds,
    required this.canStartTechnicalWork,
    this.canAddTechnicalWorkProgress = false,
    this.isActive = true,
    this.canViewAllTechnicalWork = false,
  });
}
