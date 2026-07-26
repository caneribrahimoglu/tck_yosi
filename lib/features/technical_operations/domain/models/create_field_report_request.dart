import '../enums/technical_work_category.dart';

class CreateFieldReportRequest {
  final TechnicalWorkCategory category;
  final String title;
  final String description;
  final String location;
  const CreateFieldReportRequest({
    required this.category,
    required this.title,
    required this.description,
    required this.location,
  });
}
