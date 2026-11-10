/// Envelope chung cua BE: `{ success, errors: [...], result }`.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final List<String> errors;
  final int? statusCode;

  const ApiResponse({
    required this.success,
    this.data,
    this.errors = const [],
    this.statusCode,
  });

  /// Thong diep loi dau tien (neu co).
  String? get message => errors.isEmpty ? null : errors.first;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    final result = json['result'];
    return ApiResponse<T>(
      success: json['success'] as bool? ?? true,
      data: result != null && fromJsonT != null ? fromJsonT(result) : null,
      errors: parseErrors(json['errors']),
    );
  }

  /// `errors` co the la `["a","b"]` hoac `[{message:"a"}]` hoac chuoi don.
  static List<String> parseErrors(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String) return raw.isEmpty ? const [] : [raw];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['message'] ?? e['description'] ?? e['code'] ?? '')
                  .toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  factory ApiResponse.success(T data) =>
      ApiResponse<T>(success: true, data: data);

  factory ApiResponse.error(String message, {int? statusCode}) =>
      ApiResponse<T>(success: false, errors: [message], statusCode: statusCode);
}
