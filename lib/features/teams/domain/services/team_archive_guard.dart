abstract interface class TeamArchiveGuard {
  Future<bool> hasOpenTechnicalWork(String teamId);
}
