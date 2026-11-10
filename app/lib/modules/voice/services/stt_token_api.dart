import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';

/// Lay token Blaze STT tu BE: `GET /api/v1/voice/stt-token`.
/// `result` = `{ provider: "blaze", token }` (SttTokenDto).
class SttTokenApi {
  final Dio _dio;

  SttTokenApi({required Dio dio}) : _dio = dio;

  Future<String> fetchToken() async {
    final response = await _dio.get(AppConstants.sttTokenEndpoint);
    return unwrapResult<String>(response, (r) {
      if (r is Map && r['token'] is String) return r['token'] as String;
      throw const FormatException('stt-token: thiếu trường token');
    });
  }
}
