sealed class TechnicalWorkCompletionException implements Exception {
  const TechnicalWorkCompletionException();
}

class TechnicalWorkCompletionNotAllowedException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionNotAllowedException();
}

class TechnicalWorkCompletionReviewNotAllowedException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionReviewNotAllowedException();
}

class TechnicalWorkCompletionInvalidInputException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionInvalidInputException();
}

class TechnicalWorkCompletionInvalidStateException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionInvalidStateException();
}

class TechnicalWorkCompletionSubmissionInFlightException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionSubmissionInFlightException();
}

class TechnicalWorkCompletionAlreadyDecidedException
    extends TechnicalWorkCompletionException {
  const TechnicalWorkCompletionAlreadyDecidedException();
}
