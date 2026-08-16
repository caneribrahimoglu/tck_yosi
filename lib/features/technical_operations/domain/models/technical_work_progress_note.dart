class TechnicalWorkProgressNote {
  final String id;
  final String workId;
  final String authorUserId;
  final String content;
  final DateTime createdAt;

  const TechnicalWorkProgressNote({
    required this.id,
    required this.workId,
    required this.authorUserId,
    required this.content,
    required this.createdAt,
  });
}
