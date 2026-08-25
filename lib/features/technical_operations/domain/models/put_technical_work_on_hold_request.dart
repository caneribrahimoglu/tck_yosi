class PutTechnicalWorkOnHoldRequest {
  final String workId;
  final String reason;

  const PutTechnicalWorkOnHoldRequest({
    required this.workId,
    required this.reason,
  });
}
