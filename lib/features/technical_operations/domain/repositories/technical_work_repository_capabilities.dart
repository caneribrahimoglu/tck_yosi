/// Allows a staged backend migration without silently falling back to demo writes.
abstract interface class TechnicalWorkRepositoryCapabilities {
  bool get supportsExecution;
  bool get supportsCompletion;
}
