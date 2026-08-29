import '../../auth/domain/enums/app_permission.dart';

extension TeamPermissionPresentation on AppPermission {
  String get teamLabel => switch (this) {
    AppPermission.viewAssignedVehicle => 'Atanmış aracı görüntüleme',
    AppPermission.viewVehicleFleet => 'Araç filosunu görüntüleme',
    AppPermission.manageVehicleFleet => 'Araç filosunu yönetme',
    AppPermission.receiveVehicle => 'Araç teslim alma',
    AppPermission.returnVehicle => 'Araç iade etme',
    AppPermission.updateMileage => 'Kilometre güncelleme',
    AppPermission.createFuelRecord => 'Yakıt kaydı oluşturma',
    AppPermission.createVehicleFaultRecord => 'Araç arıza kaydı oluşturma',
    AppPermission.createVehicleMaintenanceRecord =>
      'Araç bakım kaydı oluşturma',
    AppPermission.createFieldReport => 'Saha bildirimi oluşturma',
    AppPermission.viewPersonnel => 'Personel görüntüleme',
    AppPermission.managePersonnel => 'Personel yönetimi',
    AppPermission.viewReports => 'Rapor görüntüleme',
    AppPermission.approveOperations => 'Operasyon onaylama',
    AppPermission.manageUsers => 'Kullanıcı yönetimi',
    AppPermission.assignTechnicalWork => 'Teknik iş atama',
    AppPermission.startTechnicalWork => 'Teknik işi başlatma',
    AppPermission.addTechnicalWorkProgress =>
      'Teknik işe ilerleme kaydı ekleme',
    AppPermission.pauseTechnicalWork => 'Teknik işi beklemeye alma',
    AppPermission.resumeTechnicalWork => 'Teknik işe devam etme',
    AppPermission.requestTechnicalWorkCompletion =>
      'Teknik iş tamamlama talebi gönderme',
    AppPermission.reviewTechnicalWorkCompletion =>
      'Teknik iş tamamlama talebi inceleme',
    AppPermission.viewAllTechnicalWork => 'Tüm teknik işleri görüntüleme',
    AppPermission.manageTeamPermissions => 'Ekip yetkisi yönetimi',
  };
}
