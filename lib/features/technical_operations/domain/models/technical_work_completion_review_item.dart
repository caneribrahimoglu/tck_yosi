import 'technical_work.dart';
import 'technical_work_completion_request.dart';

class TechnicalWorkCompletionReviewItem {
  final TechnicalWork work;
  final TechnicalWorkCompletionRequest request;

  const TechnicalWorkCompletionReviewItem({
    required this.work,
    required this.request,
  });
}
