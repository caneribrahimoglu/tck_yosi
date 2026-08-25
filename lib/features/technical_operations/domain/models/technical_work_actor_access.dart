class TechnicalWorkActorAccess {
  final Set<String> activeTeamIds;
  final bool canStartTechnicalWork;
  final bool canAddTechnicalWorkProgress;
  final bool isActive;
  final bool canViewAllTechnicalWork;
  final bool canRequestTechnicalWorkCompletion;
  final bool canReviewTechnicalWorkCompletion;
  final bool canPauseTechnicalWork;
  final bool canResumeTechnicalWork;

  const TechnicalWorkActorAccess({
    required this.activeTeamIds,
    required this.canStartTechnicalWork,
    this.canAddTechnicalWorkProgress = false,
    this.isActive = true,
    this.canViewAllTechnicalWork = false,
    this.canRequestTechnicalWorkCompletion = false,
    this.canReviewTechnicalWorkCompletion = false,
    this.canPauseTechnicalWork = false,
    this.canResumeTechnicalWork = false,
  });
}
