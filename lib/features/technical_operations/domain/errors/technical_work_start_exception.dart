sealed class TechnicalWorkStartException implements Exception {
  const TechnicalWorkStartException();
}

final class TechnicalWorkAlreadyStartedException
    extends TechnicalWorkStartException {
  const TechnicalWorkAlreadyStartedException();
}

final class TechnicalWorkStartNotAllowedException
    extends TechnicalWorkStartException {
  const TechnicalWorkStartNotAllowedException();
}
