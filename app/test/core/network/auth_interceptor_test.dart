import 'package:banhang_app/core/constants/app_constants.dart';
import 'package:banhang_app/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const _base = 'http://test.local';

/// Dung Dio chinh + Dio refresh cung tro vao mot adapter gia.
({Dio dio, FakeSecureStorage storage, Counters counters}) _setup({
  required Future<ResponseBody> Function(RequestOptions o, Counters c) server,
  Map<String, String>? stored,
  void Function()? onExpired,
  void Function()? onRefreshed,
}) {
  final storage = FakeSecureStorage(stored ??
      {
        AppConstants.tokenKey: 'old',
        AppConstants.refreshTokenKey: 'r-old',
        AppConstants.userKey: '{}',
      });
  final counters = Counters();
  final adapter = FakeAdapter((o) => server(o, counters));

  final refreshDio = Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = adapter;
  final dio = Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = adapter;
  final interceptor = AuthInterceptor(
    storage: storage,
    refreshDio: refreshDio,
    onSessionExpired: onExpired,
    onTokenRefreshed: onRefreshed,
  )..attachDio(dio);
  dio.interceptors.add(interceptor);
  return (dio: dio, storage: storage, counters: counters);
}

class Counters {
  int refreshCalls = 0;
  int dataCalls = 0;
}

Map<String, dynamic> _ok(Object? result) =>
    {'success': true, 'errors': <String>[], 'result': result};

void main() {
  test('gan Bearer token vao request thuong', () async {
    String? seen;
    final s = _setup(server: (o, c) async {
      seen = o.headers['Authorization'] as String?;
      return jsonResponse(200, _ok([]));
    });
    await s.dio.get(AppConstants.customersEndpoint);
    expect(seen, 'Bearer old');
  });

  test('khong gan token cho login', () async {
    String? seen = 'unset';
    final s = _setup(server: (o, c) async {
      seen = o.headers['Authorization'] as String?;
      return jsonResponse(200, _ok({}));
    });
    await s.dio.post(AppConstants.loginEndpoint, data: {});
    expect(seen, isNull);
  });

  test('401 -> refresh thanh cong -> gui lai request voi token moi', () async {
    var refreshed = 0;
    final s = _setup(
      onRefreshed: () => refreshed++,
      server: (o, c) async {
        if (o.path == AppConstants.refreshEndpoint) {
          c.refreshCalls++;
          expect(o.data, {'refreshToken': 'r-old'});
          return jsonResponse(200, _ok({
            'accessToken': 'new',
            'refreshToken': 'r-new',
            'expiresAtUtc': '2030-01-01T00:00:00Z',
            'userId': 1,
            'role': 'Seller',
          }));
        }
        c.dataCalls++;
        return o.headers['Authorization'] == 'Bearer new'
            ? jsonResponse(200, _ok(['x']))
            : jsonResponse(401, {'success': false, 'errors': ['expired']});
      },
    );

    final res = await s.dio.get(AppConstants.customersEndpoint);

    expect(res.statusCode, 200);
    expect(s.counters.refreshCalls, 1);
    expect(s.counters.dataCalls, 2); // lan dau 401, lan hai 200
    expect(s.storage.data[AppConstants.tokenKey], 'new');
    expect(s.storage.data[AppConstants.refreshTokenKey], 'r-new');
    expect(s.storage.data[AppConstants.tokenExpiryKey], '2030-01-01T00:00:00Z');
    expect(refreshed, 1);
  });

  test('nhieu request cung 401 chi refresh MOT lan', () async {
    final s = _setup(server: (o, c) async {
      if (o.path == AppConstants.refreshEndpoint) {
        c.refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return jsonResponse(200, _ok({'accessToken': 'new', 'refreshToken': 'r2'}));
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? jsonResponse(200, _ok([]))
          : jsonResponse(401, {'success': false});
    });

    final results = await Future.wait([
      s.dio.get('/api/v1/Customers'),
      s.dio.get('/api/v1/Customers?page=2'),
      s.dio.get('/api/v1/voice/stt-token'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(s.counters.refreshCalls, 1);
  });

  test('refresh bi tu choi (401) -> xoa phien va bao het phien', () async {
    var expired = 0;
    final s = _setup(
      onExpired: () => expired++,
      server: (o, c) async {
        if (o.path == AppConstants.refreshEndpoint) {
          return jsonResponse(401, {'success': false, 'errors': ['invalid']});
        }
        return jsonResponse(401, {'success': false});
      },
    );

    await expectLater(
      s.dio.get(AppConstants.customersEndpoint),
      throwsA(isA<DioException>()),
    );
    expect(expired, 1);
    expect(s.storage.data, isEmpty);
  });

  test('refresh khong toi duoc server (5xx) -> GIU phien', () async {
    var expired = 0;
    final s = _setup(
      onExpired: () => expired++,
      server: (o, c) async {
        if (o.path == AppConstants.refreshEndpoint) {
          return jsonResponse(503, {'success': false});
        }
        return jsonResponse(401, {'success': false});
      },
    );

    await expectLater(
      s.dio.get(AppConstants.customersEndpoint),
      throwsA(isA<DioException>()),
    );
    expect(expired, 0);
    expect(s.storage.data[AppConstants.tokenKey], 'old');
    expect(s.storage.data[AppConstants.refreshTokenKey], 'r-old');
  });

  test('401 ma khong co refresh token -> xoa phien', () async {
    var expired = 0;
    final s = _setup(
      stored: {AppConstants.tokenKey: 'old'},
      onExpired: () => expired++,
      server: (o, c) async => jsonResponse(401, {'success': false}),
    );
    await expectLater(
      s.dio.get(AppConstants.customersEndpoint),
      throwsA(isA<DioException>()),
    );
    expect(expired, 1);
  });

  test('401 lan hai sau khi da refresh -> khong lap vo han', () async {
    var expired = 0;
    final s = _setup(
      onExpired: () => expired++,
      server: (o, c) async {
        if (o.path == AppConstants.refreshEndpoint) {
          c.refreshCalls++;
          return jsonResponse(200, _ok({'accessToken': 'new'}));
        }
        c.dataCalls++;
        return jsonResponse(401, {'success': false}); // luon 401
      },
    );
    await expectLater(
      s.dio.get(AppConstants.customersEndpoint),
      throwsA(isA<DioException>()),
    );
    expect(s.counters.refreshCalls, 1);
    expect(s.counters.dataCalls, 2);
    expect(expired, 1);
  });
}
