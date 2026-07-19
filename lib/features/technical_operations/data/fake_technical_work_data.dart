import '../domain/enums/technical_work_category.dart';
import '../domain/enums/technical_work_priority.dart';
import '../domain/enums/technical_work_status.dart';
import '../domain/models/technical_work.dart';

class FakeTechnicalWorkData {
  FakeTechnicalWorkData._();

  static final List<TechnicalWork> works = [
    TechnicalWork(
      id: 'work-001',
      title: 'Aydınlatma arızası',
      description: 'Yol aydınlatma direklerinin bir bölümü çalışmıyor.',
      location: 'D-100 / Km 14+200',
      category: TechnicalWorkCategory.lighting,
      priority: TechnicalWorkPriority.critical,
      status: TechnicalWorkStatus.inProgress,
      createdByUserId: 'user-chief-001',
      assignedToUserId: 'user-engineer-001',
      createdAt: DateTime(2026, 7, 19, 8, 30),
    ),
    TechnicalWork(
      id: 'work-002',
      title: 'Hasarlı yön levhası',
      description: 'Yönlendirme levhasında görüşü etkileyen hasar bulunuyor.',
      location: 'Ankara istikameti / Km 22+450',
      category: TechnicalWorkCategory.trafficSign,
      priority: TechnicalWorkPriority.high,
      status: TechnicalWorkStatus.awaitingInspection,
      createdByUserId: 'user-driver-001',
      assignedToUserId: 'user-engineer-001',
      createdAt: DateTime(2026, 7, 19, 9, 15),
    ),
    TechnicalWork(
      id: 'work-003',
      title: 'Bariyer deformasyonu',
      description: 'Hasarlı bariyer için saha ekibi görevlendirildi.',
      location: 'Köprü yaklaşımı / Km 31+800',
      category: TechnicalWorkCategory.barrier,
      priority: TechnicalWorkPriority.normal,
      status: TechnicalWorkStatus.assigned,
      createdByUserId: 'user-chief-001',
      assignedToUserId: 'user-engineer-001',
      createdAt: DateTime(2026, 7, 18, 14, 20),
    ),
    TechnicalWork(
      id: 'work-004',
      title: 'Yol yüzeyinde çökme',
      description: 'Sağ şeritte trafik güvenliğini etkileyen çökme oluştu.',
      location: 'D-100 / Km 38+100',
      category: TechnicalWorkCategory.roadSurface,
      priority: TechnicalWorkPriority.critical,
      status: TechnicalWorkStatus.reported,
      createdByUserId: 'user-driver-001',
      createdAt: DateTime(2026, 7, 19, 10, 5),
    ),
  ];

  static List<TechnicalWork> assignedTo(String userId) {
    return works
        .where((work) => work.assignedToUserId == userId)
        .toList(growable: false);
  }
}
