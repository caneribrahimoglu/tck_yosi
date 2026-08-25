sealed class TechnicalWorkHoldException implements Exception {
  const TechnicalWorkHoldException();
}

class TechnicalWorkHoldNotAllowedException extends TechnicalWorkHoldException {
  const TechnicalWorkHoldNotAllowedException();
}

class TechnicalWorkHoldInvalidInputException
    extends TechnicalWorkHoldException {
  const TechnicalWorkHoldInvalidInputException();
}

class TechnicalWorkHoldInvalidStateException
    extends TechnicalWorkHoldException {
  const TechnicalWorkHoldInvalidStateException();
}

class TechnicalWorkHoldTransitionInFlightException
    extends TechnicalWorkHoldException {
  const TechnicalWorkHoldTransitionInFlightException();
}
