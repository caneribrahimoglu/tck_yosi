class ArchivedTeamNameConflict implements Exception {
  final String teamId;
  final String teamName;

  const ArchivedTeamNameConflict({
    required this.teamId,
    required this.teamName,
  });

  @override
  String toString() => 'ArchivedTeamNameConflict($teamId, $teamName)';
}
