class ApiException implements Exception {
  final String code;
  final Map<String, dynamic> context;
  const ApiException(this.code, [this.context = const {}]);

  String get userMessage => switch (code) {
    'not_allowed' ||
    'grant_not_allowed' => 'Bu işlem için yetkiniz bulunmuyor.',
    'session_expired' => 'Oturumunuz sona erdi. Yeniden giriş yapın.',
    'username_exists' => 'Bu kullanıcı adı zaten kullanılıyor.',
    'invalid_password' => 'Geçici parola en az 12 karakter olmalıdır.',
    'protected_account' =>
      'Kendi hesabınız veya yönetici hesapları bu ekrandan değiştirilemez.',
    'protected_role' => 'Bu ekrandan yönetici hesabı oluşturulamaz.',
    'team_name_exists' => 'Bu adla bir ekip zaten bulunuyor.',
    'team_archived' =>
      'Arşivlenmiş ekip değiştirilemez. Önce arşivden geri getirin.',
    'team_not_archived' => 'Yalnızca arşivlenmiş ekip geri yüklenebilir.',
    'member_exists' => 'Kullanıcı zaten bu ekibin üyesi.',
    'active_user_required' => 'Aktif kullanıcı bulunamadı.',
    'invalid_input' => 'Bilgileri kontrol edip tekrar deneyin.',
    'network_error' => 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.',
    _ => 'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
  };
}
