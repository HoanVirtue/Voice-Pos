import 'package:banhang_app/core/router/app_router.dart';
import 'package:banhang_app/features/auth/data/models/user_model.dart';
import 'package:banhang_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = UserModel(id: '1', username: 'u', displayName: 'U');

  test('chua khoi phuc xong phien: giu nguyen', () {
    expect(appRedirect(const AuthState(), '/customers'), isNull);
  });

  test('chua dang nhap -> /login', () {
    expect(
      appRedirect(const AuthState(initialized: true), '/customers'),
      AppRoutes.login,
    );
    expect(appRedirect(const AuthState(initialized: true), '/login'), isNull);
  });

  test('da dang nhap o /login -> /counter, o noi khac giu nguyen', () {
    const auth = AuthState(initialized: true, isAuthenticated: true, user: user);
    expect(appRedirect(auth, '/login'), AppRoutes.counter);
    expect(appRedirect(auth, '/customers'), isNull);
  });
}
