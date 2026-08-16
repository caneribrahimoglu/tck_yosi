import '../../auth/domain/enums/app_permission.dart';

extension TeamPermissionPresentation on AppPermission {
  String get teamLabel => switch (this) {
    AppPermission.viewAssignedVehicle => 'Atanmış aracı görüntüleme',
    AppPermission.receiveVehicle => 'Araç teslim alma',
    AppPermission.returnVehicle => 'Araç iade etme',
    AppPermission.updateMileage => 'Kilometre güncelleme',
    AppPermission.createFuelRecord => 'Yakıt kaydı oluşturma',
    AppPermission.createFieldReport => 'Saha bildirimi oluşturma',
    AppPermission.viewPersonnel => 'Personel görüntüleme',
    AppPermission.managePersonnel => 'Personel yönetimi',
    AppPermission.viewReports => 'Rapor görüntüleme',
    AppPermission.approveOperations => 'Operasyon onaylama',
    AppPermission.manageUsers => 'Kullanıcı yönetimi',
    AppPermission.assignTechnicalWork => 'Teknik iş atama',
    AppPermission.startTechnicalWork => 'Teknik işi başlatma',
    AppPermission.manageTeamPermissions => 'Ekip yetkisi yönetimi',
  };
}
