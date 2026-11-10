import 'package:banhang_app/features/customers/data/customer_model.dart';
import 'package:banhang_app/features/customers/data/customer_remote.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Map<String, dynamic> _dto(String id, {bool deleted = false}) => {
      'id': id,
      'name': 'Cô Lan',
      'alias': 'bán rau',
      'phone': '0912345678',
      'note': null,
      'updatedAt': '2026-05-01T08:00:00Z',
      'isDeleted': deleted,
    };

void main() {
  test('Customer.fromJson doc CustomerDto, updatedAt la UTC', () {
    final c = Customer.fromJson(_dto('a1'));
    expect(c.alias, 'bán rau');
    expect(c.note, isNull);
    expect(c.updatedAt, DateTime.utc(2026, 5, 1, 8));
    expect(c.updatedAt.isUtc, isTrue);
  });

  test('toUpsertBody chi gom id, name, alias, phone, note', () {
    final c = Customer.fromJson(_dto('a1'));
    expect(c.toUpsertBody().keys.toSet(), {'id', 'name', 'alias', 'phone', 'note'});
  });

  test('CustomerPage: hasMore = pageIndex < totalPages', () {
    CustomerPage page(int index, int pages) => CustomerPage.fromResult({
          'items': [_dto('a')],
          'pageIndex': index,
          'pageSize': 100,
          'totalItems': 250,
          'totalPages': pages,
        });
    expect(page(1, 3).hasMore, isTrue);
    expect(page(3, 3).hasMore, isFalse);
  });

  test('list gui pageIndex, pageSize, updatedSince, includeDeleted=true', () async {
    RequestOptions? seen;
    final dio = Dio(BaseOptions(baseUrl: 'http://t'))
      ..httpClientAdapter = FakeAdapter((o) async {
        seen = o;
        return jsonResponse(200, {
          'success': true,
          'errors': [],
          'result': {
            'items': [_dto('a', deleted: true)],
            'pageIndex': 1,
            'pageSize': 100,
            'totalItems': 1,
            'totalPages': 1,
          },
        });
      });

    final page = await CustomerApiService(dio: dio).list(
      updatedSince: DateTime.utc(2026, 1, 1),
      page: 1,
      pageSize: 100,
    );

    expect(seen!.queryParameters['pageIndex'], 1);
    expect(seen!.queryParameters['pageSize'], 100);
    expect(seen!.queryParameters['updatedSince'], '2026-01-01T00:00:00.000Z');
    expect(seen!.queryParameters['includeDeleted'], true);
    expect(page.items.single.isDeleted, isTrue);
    expect(page.hasMore, isFalse);
  });

  test('create/update gui body upsert; update dung PUT /Customers/{id}', () async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://t'))
      ..httpClientAdapter = FakeAdapter((o) async {
        calls.add('${o.method} ${o.path}');
        return jsonResponse(200, {'success': true, 'errors': [], 'result': _dto('a1')});
      });
    final api = CustomerApiService(dio: dio);
    final c = Customer.fromJson(_dto('a1'));

    await api.create(c);
    await api.update(c);
    await api.delete('a1');

    expect(calls, [
      'POST /api/v1/Customers',
      'PUT /api/v1/Customers/a1',
      'DELETE /api/v1/Customers/a1',
    ]);
  });
}
