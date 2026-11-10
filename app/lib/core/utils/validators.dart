import '../constants/app_constants.dart';

class Validators {
  static String? required(String? v, {String label = 'Trường này'}) {
    if (v == null || v.trim().isEmpty) return '$label không được để trống';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < AppConstants.minPasswordLength) {
      return 'Mật khẩu tối thiểu ${AppConstants.minPasswordLength} ký tự';
    }
    return null;
  }

  /// Rong thi hop le (so dien thoai la tuy chon).
  static String? optionalPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final cleaned = v.replaceAll(RegExp(r'[\s.\-]'), '');
    return RegExp(AppConstants.phoneRegex).hasMatch(cleaned)
        ? null
        : 'Số điện thoại không hợp lệ';
  }
}
