import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_response.dart';
import 'refresh_result.dart';

class DioClient {
  late final Dio _dio;
  final AuthInterceptor _authInterceptor;

  Dio get dio => _dio;

  DioClient({
    required SecureStorageService storage,

    /// Goi khi refresh token het han/khong hop le va auth local da bi xoa:
    /// dat lai state auth trong memory de router tu chuyen ve /login.
    VoidCallback? onSessionExpired,

    /// Goi sau moi lan gia han access token thanh cong (claim/quyen co the doi).
    VoidCallback? onTokenRefreshed,
  }) : _authInterceptor = AuthInterceptor(
          storage: storage,
          refreshDio: _buildRefreshDio(),
          onSessionExpired: onSessionExpired,
          onTokenRefreshed: onTokenRefreshed,
        ) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.environment.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );
    _authInterceptor.attachDio(_dio);
    _dio.interceptors.addAll([
      _authInterceptor,
      if (AppConfig.environment.enableLogging)
        _LoggingInterceptor(
          logger: Logger(
            printer: PrettyPrinter(
              methodCount: 0,
              dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
            ),
          ),
        ),
    ]);
  }

  /// Dio rieng, khong interceptor, de goi refresh ma khong lap vo han.
  static Dio _buildRefreshDio() => Dio(BaseOptions(
        baseUrl: AppConfig.environment.baseUrl,
        contentType: 'application/json',
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
}

/// Interceptor xac thuc.
///
/// 1. Gan `Authorization: Bearer` cho moi request (tru login/refresh).
/// 2. Gap 401: thu gia han ngam bang refresh token, thanh cong thi gui lai.
/// 3. Nhieu request cung 401 chi gui MOT lan refresh (dung chung Completer).
/// 4. Request da danh dau `_retry` khong bao gio gui lai lan hai.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _refreshDio;
  final VoidCallback? _onSessionExpired;
  final VoidCallback? _onTokenRefreshed;

  late Dio _dio;

  final _log = Logger(
    printer: PrettyPrinter(methodCount: 0, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart),
  );

  Completer<RefreshResult>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storage,
    required Dio refreshDio,
    VoidCallback? onSessionExpired,
    VoidCallback? onTokenRefreshed,
  })  : _storage = storage,
        _refreshDio = refreshDio,
        _onSessionExpired = onSessionExpired,
        _onTokenRefreshed = onTokenRefreshed;

  /// Phai goi mot lan ngay sau khi tao Dio chinh (de gui lai request).
  void attachDio(Dio dio) => _dio = dio;

  bool _isPublicPath(String path) =>
      path == AppConstants.loginEndpoint || path == AppConstants.refreshEndpoint;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicPath(options.path)) return handler.next(options);

    final token = await _storage.read(AppConstants.tokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isPublicPath(err.requestOptions.path)) {
      return handler.next(err);
    }

    if (err.requestOptions.extra['_retry'] == true) {
      await _clearAuth();
      return handler.next(err);
    }

    final storedRefreshToken = await _storage.read(AppConstants.refreshTokenKey);
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      await _clearAuth();
      return handler.next(err);
    }

    RefreshResult outcome;
    if (_refreshCompleter != null) {
      outcome = await _refreshCompleter!.future;
    } else {
      final completer = _refreshCompleter = Completer<RefreshResult>();
      try {
        outcome = await _doRefresh(storedRefreshToken);
      } catch (e) {
        _log.e('[Auth] Unexpected error during refresh: $e');
        outcome = RefreshResult.unavailable;
      } finally {
        _refreshCompleter = null;
      }
      completer.complete(outcome);
    }

    if (outcome == RefreshResult.ok) {
      final newToken = await _storage.read(AppConstants.tokenKey);
      if (newToken != null && newToken.isNotEmpty) {
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        err.requestOptions.extra['_retry'] = true;
        try {
          final response = await _dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      }
      return handler.next(err);
    }

    if (outcome == RefreshResult.rejected) {
      await _clearAuth();
    }
    // unavailable: giu nguyen phien, request nay that bai, lan sau thu lai.
    return handler.next(err);
  }

  /// POST /api/v1/Auth/refresh. Body: `{ refreshToken }`; `result` cung dang LoginResultDto.
  Future<RefreshResult> _doRefresh(String refreshToken) async {
    try {
      final response = await _refreshDio.post(
        AppConstants.refreshEndpoint,
        data: {'refreshToken': refreshToken},
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) return RefreshResult.rejected;
      if (body['success'] == false) return RefreshResult.rejected;
      final data = (body['result'] as Map<String, dynamic>?) ?? body;

      final newAccessToken = data['accessToken'] as String?;
      if (newAccessToken == null || newAccessToken.isEmpty) {
        return RefreshResult.rejected;
      }
      await _storage.write(AppConstants.tokenKey, newAccessToken);

      final expiresAt = data['expiresAtUtc'] as String?;
      if (expiresAt != null) {
        await _storage.write(AppConstants.tokenExpiryKey, expiresAt);
      }

      final newRefreshToken = data['refreshToken'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write(AppConstants.refreshTokenKey, newRefreshToken);
      }

      _onTokenRefreshed?.call();
      return RefreshResult.ok;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      return (status == 400 || status == 401)
          ? RefreshResult.rejected
          : RefreshResult.unavailable;
    } catch (_) {
      return RefreshResult.unavailable;
    }
  }

  Future<void> _clearAuth() async {
    await _storage.delete(AppConstants.tokenKey);
    await _storage.delete(AppConstants.tokenExpiryKey);
    await _storage.delete(AppConstants.refreshTokenKey);
    await _storage.delete(AppConstants.userKey);
    await _storage.delete(AppConstants.rememberMeKey);
    _onSessionExpired?.call();
  }
}

/// Doc `result` cua envelope `ActionResponse<T>`; nem [DioException] khi `success=false`.
T unwrapResult<T>(Response response, T Function(dynamic) fromJson) {
  final body = response.data;
  if (body is Map<String, dynamic>) {
    final parsed = ApiResponse<T>.fromJson(body, fromJson);
    if (!parsed.success) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: parsed.message,
      );
    }
    final data = parsed.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Phản hồi không có dữ liệu',
      );
    }
    return data;
  }
  throw DioException(
    requestOptions: response.requestOptions,
    response: response,
    type: DioExceptionType.badResponse,
    message: 'Phản hồi không hợp lệ',
  );
}

class _LoggingInterceptor extends Interceptor {
  final Logger _logger;

  _LoggingInterceptor({required Logger logger}) : _logger = logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.i('→ ${options.method} ${options.uri}');
    // Chi ghi ten truong, khong ghi gia tri (mat khau, token...).
    final data = options.data;
    if (data is Map) {
      _logger.d('Request fields: ${data.keys.toList()}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.i('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('✖ ${err.response?.statusCode ?? "ERR"} ${err.requestOptions.uri}\n${err.message}');
    handler.next(err);
  }
}
