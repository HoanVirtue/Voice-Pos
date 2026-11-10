import 'package:flutter/foundation.dart';

/// Cau hinh theo moi truong. Chon bang `--dart-define=ENV=local|dev|prod`.
///
///   flutter run --dart-define=ENV=local
///   flutter run --dart-define=ENV=local --dart-define=API_BASE=http://192.168.1.10:5000
///
/// `API_BASE` (neu co) ghi de URL mac dinh cua bat ky moi truong nao.
class AppConfig {
  final String name;
  final String baseUrl;
  final bool enableLogging;

  const AppConfig({
    required this.name,
    required this.baseUrl,
    required this.enableLogging,
  });

  static const String _envName = String.fromEnvironment('ENV', defaultValue: 'local');
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE');

  /// Cong mac dinh cua BE khi chay local (`dotnet run`). Doi bang `API_BASE`.
  static const int localPort = 5299;

  /// May ao Android khong thay `localhost` cua may chu nha: `10.0.2.2` moi la
  /// duong vao. Web, iOS simulator, desktop dung `localhost`.
  static String get _localHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static AppConfig get local => AppConfig(
        name: 'local',
        baseUrl: _apiBaseOverride.isNotEmpty
            ? _apiBaseOverride
            : 'http://$_localHost:$localPort',
        enableLogging: true,
      );

  // Dia chi dev/prod chua co: dat qua --dart-define=API_BASE khi build.
  static AppConfig get dev => AppConfig(
        name: 'dev',
        baseUrl: _apiBaseOverride.isNotEmpty
            ? _apiBaseOverride
            : 'https://dev.banhang.example',
        enableLogging: true,
      );

  static AppConfig get prod => AppConfig(
        name: 'prod',
        baseUrl: _apiBaseOverride.isNotEmpty
            ? _apiBaseOverride
            : 'https://api.banhang.example',
        enableLogging: false,
      );

  static AppConfig get environment {
    switch (_envName) {
      case 'prod':
        return prod;
      case 'dev':
        return dev;
      case 'local':
      default:
        return local;
    }
  }
}
