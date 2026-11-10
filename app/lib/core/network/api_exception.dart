import 'package:dio/dio.dart';

import 'api_response.dart';

/// Doi loi Dio thanh thong diep than thien.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({required this.message, this.statusCode, this.data});

  /// Loi tam thoi (mat mang, timeout, 5xx): thu lai sau la duoc.
  bool get isTransient => statusCode == null || statusCode! >= 500;

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Kết nối đến server bị timeout. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Không thể kết nối đến server. Kiểm tra kết nối mạng.',
        );
      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);
      case DioExceptionType.cancel:
        return const ApiException(message: 'Yêu cầu đã bị hủy.');
      default:
        return const ApiException(message: 'Đã có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  static ApiException _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;

    String? message;
    if (data is Map<String, dynamic>) {
      final errors = ApiResponse.parseErrors(data['errors']);
      if (errors.isNotEmpty) {
        message = errors.join('\n');
      } else if (data['message'] is String) {
        message = data['message'] as String;
      }
    }
    message ??= switch (statusCode) {
      400 => 'Dữ liệu không hợp lệ.',
      401 => 'Sai tên đăng nhập hoặc phiên đăng nhập đã hết hạn.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      409 => 'Dữ liệu đã tồn tại.',
      500 => 'Lỗi server. Vui lòng thử lại sau.',
      _ => 'Đã có lỗi xảy ra (Mã: $statusCode).',
    };

    return ApiException(message: message, statusCode: statusCode, data: data);
  }

  @override
  String toString() => message;
}
