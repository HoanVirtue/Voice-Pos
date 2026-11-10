import 'package:banhang_app/core/network/api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doc result trong envelope ActionResponse', () {
    final r = ApiResponse<int>.fromJson(
      {'success': true, 'errors': [], 'result': 42},
      (v) => v as int,
    );
    expect(r.success, isTrue);
    expect(r.data, 42);
    expect(r.errors, isEmpty);
  });

  test('doc errors dang chuoi, object va chuoi don', () {
    expect(ApiResponse.parseErrors(['a', 'b']), ['a', 'b']);
    expect(
      ApiResponse.parseErrors([
        {'message': 'm1'},
        {'code': 'c2'},
      ]),
      ['m1', 'c2'],
    );
    expect(ApiResponse.parseErrors('boom'), ['boom']);
    expect(ApiResponse.parseErrors(null), isEmpty);
  });

  test('success=false giu errors, khong co data', () {
    final r = ApiResponse<int>.fromJson(
      {'success': false, 'errors': ['loi'], 'result': null},
      (v) => v as int,
    );
    expect(r.success, isFalse);
    expect(r.data, isNull);
    expect(r.message, 'loi');
  });
}
