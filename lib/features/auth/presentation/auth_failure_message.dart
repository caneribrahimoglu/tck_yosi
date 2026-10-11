import '../domain/enums/auth_failure.dart';

String authFailureMessage(AuthFailure? failure) => switch (failure) {
  AuthFailure.invalidCredentials => 'Kullanıcı adı veya parola hatalı.',
  AuthFailure.inactiveAccount =>
    'Hesabınız aktif değil. Sistem yöneticisiyle iletişime geçin.',
  AuthFailure.networkError =>
    'Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin.',
  AuthFailure.invalidPassword =>
    'Mevcut parolanızı kontrol edin. Yeni parola en az 12 karakter ve mevcut paroladan farklı olmalıdır.',
  AuthFailure.sessionExpired =>
    'Oturumunuz sona erdi. Lütfen yeniden giriş yapın.',
  AuthFailure.unknown || null => 'İşlem tamamlanamadı. Lütfen yeniden deneyin.',
};
