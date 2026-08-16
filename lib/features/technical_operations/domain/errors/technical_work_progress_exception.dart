sealed class TechnicalWorkProgressException implements Exception {
  const TechnicalWorkProgressException();
}

final class TechnicalWorkProgressNotAllowedException
    extends TechnicalWorkProgressException {
  const TechnicalWorkProgressNotAllowedException();
}

final class TechnicalWorkProgressInvalidInputException
    extends TechnicalWorkProgressException {
  const TechnicalWorkProgressInvalidInputException();
}

final class TechnicalWorkProgressInvalidStateException
    extends TechnicalWorkProgressException {
  const TechnicalWorkProgressInvalidStateException();
}

final class TechnicalWorkProgressSubmissionInFlightException
    extends TechnicalWorkProgressException {
  const TechnicalWorkProgressSubmissionInFlightException();
}
