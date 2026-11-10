import 'package:banhang_app/core/constants/app_constants.dart';
import 'package:banhang_app/core/network/api_exception.dart';
import 'package:banhang_app/core/theme/app_theme.dart';
import 'package:banhang_app/features/auth/data/datasources/auth_api_service.dart';
import 'package:banhang_app/features/auth/data/models/auth_models.dart';
import 'package:banhang_app/features/auth/data/models/user_model.dart';
import 'package:banhang_app/features/auth/data/repositories/auth_repository.dart';
import 'package:banhang_app/features/auth/presentation/screens/login_screen.dart';
import 'package:banhang_app/features/auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

class FakeAuthApi extends AuthApiService {
  final List<LoginRequest> requests = [];
  bool fail = false;

  FakeAuthApi() : super(dio: Dio());

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    requests.add(request);
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConstants.loginEndpoint),
        response: Response(
          requestOptions: RequestOptions(path: AppConstants.loginEndpoint),
          statusCode: 401,
          data: {'success': false, 'errors': ['Sai tài khoản hoặc mật khẩu']},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return const LoginResponse(
      accessToken: 'tok',
      refreshToken: 'ref',
      expiresAt: '2030-01-01T00:00:00Z',
      user: UserModel(id: '1', username: 'me', displayName: 'Chủ quầy', role: 'Seller'),
    );
  }

  @override
  Future<void> logout({String? refreshToken}) async {}
}

void main() {
  late FakeAuthApi api;
  late FakeSecureStorage storage;
  late ProviderContainer container;

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    api = FakeAuthApi();
    storage = FakeSecureStorage();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(apiService: api, storage: storage),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ));
  }

  testWidgets('hien thi o nhap va nut dang nhap', (tester) async {
    await pumpLogin(tester);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('bo trong -> bao loi, khong goi API', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.textContaining('không được để trống'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('mat khau qua ngan -> bao loi', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login_username')), 'me');
    await tester.enterText(find.byKey(const Key('login_password')), '123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.textContaining('tối thiểu'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('dang nhap thanh cong -> luu token va dat trang thai da dang nhap',
      (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login_username')), ' me ');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret1');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(api.requests.single.username, 'me'); // da trim
    expect(api.requests.single.password, 'secret1');
    final auth = container.read(authStateProvider);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.user?.displayName, 'Chủ quầy');
    expect(auth.user?.role, 'Seller');
    expect(storage.data[AppConstants.tokenKey], 'tok');
    expect(storage.data[AppConstants.refreshTokenKey], 'ref');
    expect(storage.data[AppConstants.rememberMeKey], 'true'); // mac dinh ghi nho
  });

  testWidgets('dang nhap that bai -> hien thong diep loi cua server', (tester) async {
    await pumpLogin(tester);
    api.fail = true;

    await tester.enterText(find.byKey(const Key('login_username')), 'me');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrongpass');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.text('Sai tài khoản hoặc mật khẩu'), findsOneWidget);
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
    expect(storage.data, isEmpty);
  });

  test('ApiException.isTransient: khong phan hoi hoac 5xx', () {
    expect(const ApiException(message: 'x').isTransient, isTrue);
    expect(const ApiException(message: 'x', statusCode: 503).isTransient, isTrue);
    expect(const ApiException(message: 'x', statusCode: 400).isTransient, isFalse);
  });
}
