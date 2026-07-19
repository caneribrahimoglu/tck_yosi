import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';

void main() {
  TechnicalWork createWork({
    TechnicalWorkPriority priority = TechnicalWorkPriority.normal,
    TechnicalWorkStatus status = TechnicalWorkStatus.reported,
    String? assignedToUserId,
  }) {
    return TechnicalWork(
      id: 'work-001',
      title: 'Aydınlatma arızası',
      description: 'Üç aydınlatma direği çalışmıyor.',
      location: 'D-100 / Km 14+200',
      category: TechnicalWorkCategory.lighting,
      priority: priority,
      status: status,
      createdByUserId: 'user-001',
      assignedToUserId: assignedToUserId,
      createdAt: DateTime(2026, 7, 19),
    );
  }

  test('atanan kullanıcı varsa iş atanmış kabul edilir', () {
    final work = createWork(assignedToUserId: 'engineer-001');

    expect(work.isAssigned, isTrue);
  });

  test('atanan kullanıcı yoksa iş atanmamış kabul edilir', () {
    final work = createWork();

    expect(work.isAssigned, isFalse);
  });

  test('kritik öncelikli iş kritik kabul edilir', () {
    final work = createWork(priority: TechnicalWorkPriority.critical);

    expect(work.isCritical, isTrue);
  });

  test('tamamlanan durumdaki iş tamamlanmış kabul edilir', () {
    final work = createWork(status: TechnicalWorkStatus.completed);

    expect(work.isCompleted, isTrue);
  });

  test('bildirilen iş açık kabul edilir', () {
    final work = createWork(status: TechnicalWorkStatus.reported);

    expect(work.isOpen, isTrue);
  });

  test('tamamlanan iş açık kabul edilmez', () {
    final work = createWork(status: TechnicalWorkStatus.completed);

    expect(work.isOpen, isFalse);
  });

  test('iptal edilen iş açık kabul edilmez', () {
    final work = createWork(status: TechnicalWorkStatus.cancelled);

    expect(work.isOpen, isFalse);
  });
}
