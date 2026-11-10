import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:banhang_app/core/sync/sync_service.dart';
import 'package:banhang_app/features/customers/data/customer_model.dart';
import 'package:banhang_app/features/customers/data/customer_remote.dart';
import 'package:banhang_app/features/customers/data/customer_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server gia: luu khach trong bo nho, ghi lai chuoi thao tac.
class FakeRemote implements CustomerRemote {
  final Map<String, Customer> store = {};
  final List<String> calls = [];
  final List<DateTime?> listSince = [];

  /// Loi se nem o lan goi tiep theo cua thao tac (create/update/delete/list).
  final Map<String, DioException> failOnce = {};

  /// Du lieu "server" tra ve cho `list`.
  List<Customer> serverItems = [];

  void _maybeFail(String op) {
    final e = failOnce.remove(op);
    if (e != null) throw e;
  }

  @override
  Future<void> create(Customer c) async {
    calls.add('create:${c.id}');
    _maybeFail('create');
    store[c.id] = c;
  }

  @override
  Future<void> update(Customer c) async {
    calls.add('update:${c.id}');
    _maybeFail('update');
    store[c.id] = c;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    _maybeFail('delete');
    store.remove(id);
  }

  @override
  Future<CustomerPage> list({
    DateTime? updatedSince,
    required int page,
    required int pageSize,
  }) async {
    calls.add('list:$page');
    listSince.add(updatedSince);
    _maybeFail('list');
    final items = serverItems
        .where((c) => updatedSince == null || !c.updatedAt.isBefore(updatedSince))
        .toList();
    return CustomerPage(items: items, hasMore: false);
  }
}

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code),
      type: DioExceptionType.badResponse,
    );

DioException get _offline => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );

void main() {
  late AppDatabase db;
  late FakeRemote remote;
  late CustomerRepository repo;
  late SyncService sync;
  var clock = DateTime.utc(2026, 1, 1, 8);

  DateTime tick() => clock = clock.add(const Duration(minutes: 1));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeRemote();
    clock = DateTime.utc(2026, 1, 1, 8);
    repo = CustomerRepository(db, now: tick);
    sync = SyncService(db: db, remote: remote, isOnline: () async => true);
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  Future<int> outboxCount() async => (await db.select(db.outboxEntries).get()).length;

  test('ghi local truoc + xep vao outbox, chua goi server', () async {
    final c = await repo.create(name: '  Cô Lan ', phone: '0912345678');

    expect(c.name, 'Cô Lan');
    expect((await repo.getById(c.id))?.name, 'Cô Lan');
    expect(await outboxCount(), 1);
    expect(remote.calls, isEmpty);
    expect(await repo.watchPendingCount().first, 1);
  });

  test('id do client sinh la uuid hop le va khac nhau', () async {
    final a = await repo.create(name: 'A');
    final b = await repo.create(name: 'B');
    final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    expect(uuid.hasMatch(a.id), isTrue);
    expect(a.id, isNot(b.id));
  });

  test('syncNow day outbox theo thu tu va don sach hang doi', () async {
    final c = await repo.create(name: 'Lan');
    await repo.update(c.copyWith(name: 'Lan 2'));
    await repo.softDelete(c.id);

    final result = await sync.syncNow();

    expect(result.completed, isTrue);
    expect(result.pushed, 3);
    expect(remote.calls.where((e) => !e.startsWith('list')), [
      'create:${c.id}',
      'update:${c.id}',
      'delete:${c.id}',
    ]);
    expect(await outboxCount(), 0);
  });

  test('gui lai cung thao tac nhieu lan van an toan (BE idempotent): chi xoa khoi outbox khi thanh cong', () async {
    final c = await repo.create(name: 'Lan');
    remote.failOnce['create'] = _status(503);

    final r1 = await sync.syncNow();
    expect(r1.completed, isFalse);
    expect(await outboxCount(), 1);

    final r2 = await sync.syncNow(); // gui lai cung Id
    expect(r2.completed, isTrue);
    expect(remote.store.keys, [c.id]);
    expect(await outboxCount(), 0);
  });

  test('delete gap 404 coi nhu da xong', () async {
    final c = await repo.create(name: 'Lan');
    await sync.syncNow();
    await repo.softDelete(c.id);
    remote.failOnce['delete'] = _status(404);

    final r = await sync.syncNow();

    expect(r.completed, isTrue);
    expect(await outboxCount(), 0);
  });

  test('mat mang giua chung: dung lai, giu outbox, lan sau day tiep khong trung', () async {
    final a = await repo.create(name: 'A');
    final b = await repo.create(name: 'B');
    remote.failOnce['create'] = _offline; // loi o thao tac dau

    final r1 = await sync.syncNow();
    expect(r1.completed, isFalse);
    expect(await outboxCount(), 2);

    remote.calls.clear();
    final r2 = await sync.syncNow();
    expect(r2.completed, isTrue);
    expect(remote.calls.where((e) => e.startsWith('create')),
        ['create:${a.id}', 'create:${b.id}']);
    expect(remote.store.keys, containsAll([a.id, b.id]));
    expect(await outboxCount(), 0);
  });

  test('loi 4xx khong the thu lai: ghi lastError, tang attempts, khong chan hang doi', () async {
    final a = await repo.create(name: 'A');
    final b = await repo.create(name: 'B');
    remote.failOnce['create'] = _status(422);

    final r = await sync.syncNow();

    expect(r.completed, isTrue);
    expect(remote.store.containsKey(b.id), isTrue);
    final left = await db.select(db.outboxEntries).get();
    expect(left, hasLength(1));
    expect(left.single.entityId, a.id);
    expect(left.single.attempts, 1);
    expect(left.single.lastError, contains('422'));
  });

  test('offline: khong goi server, trang thai offline', () async {
    final offline = SyncService(db: db, remote: remote, isOnline: () async => false);
    await repo.create(name: 'A');

    final r = await offline.syncNow();

    expect(r.completed, isFalse);
    expect(offline.status, SyncStatus.offline);
    expect(remote.calls, isEmpty);
    expect(await outboxCount(), 1);
    offline.dispose();
  });

  test('pull: ap ban ghi server, luu moc updatedSince, lan sau chi hoi tu moc', () async {
    final t1 = DateTime.utc(2026, 2, 1, 9);
    final t2 = DateTime.utc(2026, 2, 2, 9);
    remote.serverItems = [
      Customer(id: 'srv-1', name: 'Anh Tú', updatedAt: t1),
      Customer(id: 'srv-2', name: 'Chị Hà', alias: 'góc chợ', updatedAt: t2),
    ];

    final r1 = await sync.syncNow();
    expect(r1.pulled, 2);
    expect(remote.listSince.first, isNull);
    final list = await repo.watchAll().first;
    expect(list.map((c) => c.name), ['Anh Tú', 'Chị Hà']);
    expect(list.last.alias, 'góc chợ');
    expect(await db.getMeta(SyncService.customersCursorKey), t2.toIso8601String());

    await sync.syncNow();
    expect(remote.listSince.last, t2);
  });

  test('pull khong ghi de ban ghi dang cho day (local thang)', () async {
    final c = await repo.create(name: 'Lan (sua local)');
    remote.failOnce['create'] = _offline; // de outbox con lai
    remote.serverItems = [
      Customer(
        id: c.id,
        name: 'Ten cu tren server',
        updatedAt: c.updatedAt.add(const Duration(days: 1)),
      ),
    ];

    await sync.syncNow(); // push that bai -> khong pull
    expect((await repo.getById(c.id))?.name, 'Lan (sua local)');

    // Goi truc tiep pull khi outbox con: van khong duoc ghi de.
    final applied = await sync.pullCustomers();
    expect(applied, 0);
    expect((await repo.getById(c.id))?.name, 'Lan (sua local)');
  });

  test('pull ap xoa mem tu server', () async {
    final t = DateTime.utc(2026, 3, 1);
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'srv-9',
          name: 'Khách cũ',
          updatedAt: t,
        ));
    remote.serverItems = [
      Customer(
        id: 'srv-9',
        name: 'Khách cũ',
        isDeleted: true,
        updatedAt: t.add(const Duration(hours: 1)),
      ),
    ];

    await sync.syncNow();

    expect(await repo.watchAll().first, isEmpty);
    expect((await repo.getById('srv-9'))?.isDeleted, isTrue);
  });

  test('xoa mem: an khoi danh sach nhung giu dong de dong bo', () async {
    final c = await repo.create(name: 'Lan');
    await repo.softDelete(c.id);

    expect(await repo.watchAll().first, isEmpty);
    expect((await repo.getById(c.id))?.isDeleted, isTrue);
    final ops = (await db.select(db.outboxEntries).get()).map((e) => e.operation);
    expect(ops, [OutboxOp.create, OutboxOp.delete]);
  });

  test('tim kiem theo ten, biet danh va so dien thoai', () async {
    await repo.create(name: 'Cô Lan', alias: 'bán rau', phone: '0912345678');
    await repo.create(name: 'Anh Tú', phone: '0987654321');
    expect((await repo.watchAll(query: 'rau').first).map((c) => c.name), ['Cô Lan']);

    expect((await repo.watchAll(query: 'lan').first).map((c) => c.name), ['Cô Lan']);
    expect((await repo.watchAll(query: '0987').first).map((c) => c.name), ['Anh Tú']);
  });

  test('onLocalChange duoc goi sau moi lan ghi', () async {
    var n = 0;
    final r = CustomerRepository(db, now: tick, onLocalChange: () => n++);
    final c = await r.create(name: 'A');
    await r.update(c.copyWith(name: 'B'));
    await r.softDelete(c.id);
    expect(n, 3);
  });
}
