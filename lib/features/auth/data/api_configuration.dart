import 'package:flutter/foundation.dart';

class ApiConfiguration {
  ApiConfiguration._();
  static Uri get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    final value = configured.isNotEmpty
        ? configured
        : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:8000/api/v1/'
              : 'http://127.0.0.1:8000/api/v1/');
    final uri = Uri.parse(value.endsWith('/') ? value : '$value/');
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(kDebugMode && uri.scheme == 'http'))) {
      throw StateError('Geçerli bir HTTPS API_BASE_URL gereklidir.');
    }
    return uri;
  }
}
