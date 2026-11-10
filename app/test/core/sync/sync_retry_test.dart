import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:banhang_app/core/sync/entity_sync.dart';
import 'package:banhang_app/core/sync/sync_service.dart';
import 'package:banhang_app/core/sync/syncers.dart';
import 'package:banhang_app/features/customers/data/customer_model.dart';
import 'package:banhang_app/features/customers/data/customer_remote.dart';
import 'package:banhang_app/features/transactions/data/transaction_model.dart';
import 'package:banhang_app/features/transactions/data/transaction_repository.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _netError() => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
      message: 'khong toi duoc server',
    );

class _EmptyCustomers implements CustomerRemote {
  @override
  Future<void> create(Customer c) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<CustomerPage> list({DateTime? updatedSince, required int page, required int pageSize}) async =>
      const CustomerPage(items: [], hasMore: false);
  @override
  Future<void> update(Customer c) async {}
}

/// Remote giao dich: that bai (loi mang) `failures` lan dau roi thanh cong.
class _FlakyTxnRemote implements EntityRemote<TransactionRecord> {
  int failures;
  int createCalls = 0;
  final Map<String, TransactionRecord> store = {};
  _FlakyTxnRemote(this.failures);

  @override
  Future<void> create(TransactionRecord e) async {
    createCalls++;
    if (failures > 0) {
      failures--;
      throw _netError();
    }
    store[e.id] = e;
  }

  @override
  Future<void> update(TransactionRecord e) async => store[e.id] = e;
  @override
  Future<void> delete(String id) async => store.remove(id);
  @override
  Future<EntityPage<TransactionRecord>> list(
          {DateTime? updatedSince, required int page, required int pageSize}) async =>
      const EntityPage(items: [], hasMore: false);
}

Future<void> _until(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('het thoi gian cho dieu kien');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase db;
  late _FlakyTxnRemote remote;
  late SyncService sync;

  SyncService build(int failures, List<Duration> delays) {
    remote = _FlakyTxnRemote(failures);
    return SyncService(
      db: db,
      remote: _EmptyCustomers(),
      syncers: [transactionSyncer(remote)],
      isOnline: () async => true,
      retryDelays: delays,
    );
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  test('day outbox that bai vi mat ket noi -> tu thu lai den khi len server', () async {
    sync = build(2, const [Duration(milliseconds: 30), Duration(milliseconds: 60)]);
    await TransactionRepository(db).create(type: TxnType.sale, amount: 100000, customerId: 'c1');

    final first = await sync.syncNow();
    expect(first.completed, isFalse);
    expect(sync.status, SyncStatus.error);

    await _until(() => remote.store.length == 1);
    expect(remote.createCalls, 3); // 2 lan loi + 1 lan thanh cong
    await _until(() => sync.status == SyncStatus.idle);
    expect(await db.select(db.outboxEntries).get(), isEmpty);
  });

  test('thanh cong thi khong hen them (khong goi lai)', () async {
    sync = build(0, const [Duration(milliseconds: 20)]);
    await TransactionRepository(db).create(type: TxnType.sale, amount: 100000, customerId: 'c1');
    await sync.syncNow();
    expect(remote.createCalls, 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(remote.createCalls, 1);
  });

  test('dispose (dang xuat) huy hen gio thu lai', () async {
    sync = build(100, const [Duration(milliseconds: 40)]);
    await TransactionRepository(db).create(type: TxnType.sale, amount: 100000, customerId: 'c1');
    await sync.syncNow();
    expect(remote.createCalls, 1);
    sync.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(remote.createCalls, 1);
  });

  test('lui dan: khoang cach thu lai tang theo bang, phan tu cuoi lap lai', () async {
    sync = build(100, const [Duration(milliseconds: 40), Duration(milliseconds: 120)]);
    await TransactionRepository(db).create(type: TxnType.sale, amount: 100000, customerId: 'c1');
    final times = <DateTime>[];
    final sub = sync.statusStream.listen((s) {
      if (s == SyncStatus.syncing) times.add(DateTime.now());
    });
    await sync.syncNow();
    await _until(() => times.length >= 4);
    await sub.cancel();
    // times[0]: vong dau; times[1] sau ~40ms; times[2] sau ~120ms; times[3] sau ~120ms
    final d1 = times[2].difference(times[1]).inMilliseconds;
    expect(d1, greaterThanOrEqualTo(100));
  });
}
