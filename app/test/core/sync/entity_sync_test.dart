import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:banhang_app/core/sync/entity_sync.dart';
import 'package:banhang_app/core/sync/sync_service.dart';
import 'package:banhang_app/core/sync/syncers.dart';
import 'package:banhang_app/core/utils/vn_format.dart';
import 'package:banhang_app/features/batches/data/batch_model.dart';
import 'package:banhang_app/features/batches/data/batch_repository.dart';
import 'package:banhang_app/features/customers/data/customer_model.dart';
import 'package:banhang_app/features/customers/data/customer_remote.dart';
import 'package:banhang_app/features/products/data/product_model.dart';
import 'package:banhang_app/features/products/data/product_repository.dart';
import 'package:banhang_app/features/settlements/data/settlement_model.dart';
import 'package:banhang_app/features/settlements/data/settlement_repository.dart';
import 'package:banhang_app/features/transactions/data/transaction_model.dart';
import 'package:banhang_app/features/transactions/data/transaction_repository.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server gia cho mot loai thuc the: luu trong bo nho, ghi lai chuoi thao tac chung.
class FakeEntityRemote<T extends SyncEntity> implements EntityRemote<T> {
  final String name;
  final List<String> log;
  final Map<String, T> store = {};
  List<T> serverItems = [];
  final List<DateTime?> listSince = [];
  DioException? failCreateOnce;

  FakeEntityRemote(this.name, this.log);

  @override
  Future<void> create(T e) async {
    log.add('$name.create:${e.id}');
    final f = failCreateOnce;
    if (f != null) {
      failCreateOnce = null;
      throw f;
    }
    store[e.id] = e;
  }

  @override
  Future<void> update(T e) async {
    log.add('$name.update:${e.id}');
    store[e.id] = e;
  }

  @override
  Future<void> delete(String id) async {
    log.add('$name.delete:$id');
    store.remove(id);
  }

  @override
  Future<EntityPage<T>> list({DateTime? updatedSince, required int page, required int pageSize}) async {
    listSince.add(updatedSince);
    final items = serverItems
        .where((e) => updatedSince == null || e.updatedAt.isAfter(updatedSince))
        .toList();
    return EntityPage(items: items, hasMore: false);
  }
}

class EmptyCustomerRemote implements CustomerRemote {
  @override
  Future<void> create(Customer customer) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<CustomerPage> list({DateTime? updatedSince, required int page, required int pageSize}) async =>
      const CustomerPage(items: [], hasMore: false);
  @override
  Future<void> update(Customer customer) async {}
}

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code),
      type: DioExceptionType.badResponse,
    );

void main() {
  late AppDatabase db;
  late List<String> log;
  late FakeEntityRemote<Product> products;
  late FakeEntityRemote<PigBatch> batches;
  late FakeEntityRemote<TransactionRecord> txns;
  late FakeEntityRemote<DaySettlement> settlements;
  late SyncService sync;
  var clock = DateTime.utc(2026, 11, 9, 1);
  DateTime tick() => clock = clock.add(const Duration(minutes: 1));

  late ProductRepository productRepo;
  late BatchRepository batchRepo;
  late TransactionRepository txRepo;
  late SettlementRepository settleRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    log = [];
    products = FakeEntityRemote('product', log);
    batches = FakeEntityRemote('batch', log);
    txns = FakeEntityRemote('txn', log);
    settlements = FakeEntityRemote('settle', log);
    clock = DateTime.utc(2026, 11, 9, 1);
    productRepo = ProductRepository(db, now: tick);
    batchRepo = BatchRepository(db, now: tick);
    txRepo = TransactionRepository(db, now: tick);
    settleRepo = SettlementRepository(db, now: tick);
    sync = SyncService(
      db: db,
      remote: EmptyCustomerRemote(),
      syncers: [
        productSyncer(products),
        batchSyncer(batches),
        transactionSyncer(txns),
        settlementSyncer(settlements),
      ],
      isOnline: () async => true,
    );
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  Future<int> outboxCount() async => (await db.select(db.outboxEntries).get()).length;

  group('TransactionRepository', () {
    test('ghi local + outbox, Id uuid, chua goi server', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 380000, customerId: 'c1', weightGram: 2000);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(t.id),
        isTrue,
      );
      expect((await txRepo.getById(t.id))?.amount, 380000);
      expect(await outboxCount(), 1);
      expect(log, isEmpty);
    });

    test('ban khong noi gi thi coi la da tra het; chan tra > tien', () async {
      final a = await txRepo.create(type: TxnType.sale, amount: 100);
      final b = await txRepo.create(type: TxnType.sale, amount: 100, paidAmount: 500);
      final c = await txRepo.create(type: TxnType.sale, amount: 100, paidAmount: -5);
      expect(a.paidAmount, 100);
      expect(b.paidAmount, 100);
      expect(c.paidAmount, 0);
      expect(c.debt, 100);
    });

    test('loai chi/thu no: paidAmount luon = amount', () async {
      final a = await txRepo.create(type: TxnType.buyPig, amount: 9800000, paidAmount: 0);
      final b = await txRepo.create(type: TxnType.debtPayment, amount: 100, customerId: 'c');
      expect(a.paidAmount, 9800000);
      expect(b.paidAmount, 100);
    });

    test('xoa mem: dong van con, khong hien o danh sach, outbox co delete', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 1);
      await txRepo.softDelete(t.id);
      await txRepo.softDelete(t.id); // idempotent
      expect(await txRepo.watchAll().first, isEmpty);
      expect((await txRepo.getById(t.id))?.isDeleted, isTrue);
      final ops = (await db.select(db.outboxEntries).get()).map((e) => e.operation).toList();
      expect(ops, ['create', 'delete']);
    });

    test('getLast: giao dich moi nhat chua xoa', () async {
      final a = await txRepo.create(type: TxnType.sale, amount: 1, occurredAt: DateTime.utc(2026, 11, 9, 2));
      final b = await txRepo.create(type: TxnType.sale, amount: 2, occurredAt: DateTime.utc(2026, 11, 9, 3));
      expect((await txRepo.getLast())?.id, b.id);
      await txRepo.softDelete(b.id);
      expect((await txRepo.getLast())?.id, a.id);
    });

    test('watchDay loc theo ngay VN', () async {
      // 23:30 VN ngay 9 = 16:30 UTC; 00:30 VN ngay 10 = 17:30 UTC ngay 9.
      await txRepo.create(type: TxnType.sale, amount: 1, occurredAt: DateTime.utc(2026, 11, 9, 16, 30));
      await txRepo.create(type: TxnType.sale, amount: 2, occurredAt: DateTime.utc(2026, 11, 9, 17, 30));
      expect((await txRepo.watchDay('2026-11-09').first).map((e) => e.amount), [1]);
      expect((await txRepo.watchDay('2026-11-10').first).map((e) => e.amount), [2]);
    });

    test('sua: cap nhat updatedAt va dong update', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 380000);
      final u = await txRepo.update(t.copyWith(amount: 360000));
      expect(u.amount, 360000);
      expect(u.paidAmount, 360000); // da tra het -> bam theo
      expect(u.updatedAt.isAfter(t.updatedAt), isTrue);
    });

    test('copyWith xoa duoc khach (null that su)', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 1, customerId: 'c1');
      expect(t.copyWith(customerId: null).customerId, isNull);
      expect(t.copyWith().customerId, 'c1');
    });
  });

  group('Product / Batch repository', () {
    test('chuan hoa va xoa mem mon hang', () async {
      final p = await productRepo.create(name: '  Ba chỉ ', alias: ' ', pricePerKg: 190000);
      expect(p.name, 'Ba chỉ');
      expect(p.alias, isNull);
      await productRepo.softDelete(p.id);
      expect(await productRepo.watchAll().first, isEmpty);
      expect(await outboxCount(), 2);
    });

    test('lo hang: ngay mac dinh la hom nay gio VN', () async {
      final b = await batchRepo.create(pigCount: 2, buyCost: 15000000);
      expect(b.date, VnTime.dateString(clock));
      expect((await batchRepo.watchAll().first).single.pigCount, 2);
    });
  });

  group('SettlementRepository', () {
    test('chot hai lan cung ngay -> sua ban ghi cu (giu Id), chenh lech dung', () async {
      final a = await settleRepo.save(
          date: '2026-11-09', openingCash: 1000, countedCash: 5000, expectedCash: 5200);
      expect(a.difference, -200);
      final b = await settleRepo.save(
          date: '2026-11-09', openingCash: 1000, countedCash: 5300, expectedCash: 5200, note: ' dư ');
      expect(b.id, a.id);
      expect(b.difference, 100);
      expect(b.note, 'dư');
      expect((await settleRepo.watchAll().first).length, 1);
      final ops = (await db.select(db.outboxEntries).get()).map((e) => e.operation).toList();
      expect(ops, ['create', 'update']);
    });

    test('lastBefore lay lan chot gan nhat truoc ngay', () async {
      await settleRepo.save(date: '2026-11-07', openingCash: 0, countedCash: 700, expectedCash: 700);
      await settleRepo.save(date: '2026-11-08', openingCash: 0, countedCash: 800, expectedCash: 800);
      expect((await settleRepo.lastBefore('2026-11-09'))?.countedCash, 800);
      expect((await settleRepo.lastBefore('2026-11-08'))?.countedCash, 700);
      expect(await settleRepo.lastBefore('2026-11-07'), isNull);
    });
  });

  group('SyncService nhieu thuc the', () {
    test('day outbox theo thu tu giua cac loai thuc the', () async {
      final p = await productRepo.create(name: 'Ba chỉ', pricePerKg: 1);
      final t = await txRepo.create(type: TxnType.sale, amount: 5);
      final b = await batchRepo.create(pigCount: 1);
      final s = await settleRepo.save(date: '2026-11-09', openingCash: 0, countedCash: 0, expectedCash: 0);

      final r = await sync.syncNow();

      expect(r.completed, isTrue);
      expect(r.pushed, 4);
      expect(log, ['product.create:${p.id}', 'txn.create:${t.id}', 'batch.create:${b.id}', 'settle.create:${s.id}']);
      expect(await outboxCount(), 0);
    });

    test('loi tam thoi: giu outbox, gui lai khong trung', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 5);
      txns.failCreateOnce = _status(503);

      final r1 = await sync.syncNow();
      expect(r1.completed, isFalse);
      expect(await outboxCount(), 1);

      final r2 = await sync.syncNow();
      expect(r2.completed, isTrue);
      expect(txns.store.keys, [t.id]);
      expect(await outboxCount(), 0);
    });

    test('loi 409 (trung ngay chot): ghi lastError, khong chan cac thao tac sau', () async {
      final s = await settleRepo.save(date: '2026-11-09', openingCash: 0, countedCash: 0, expectedCash: 0);
      final p = await productRepo.create(name: 'Xương');
      settlements.failCreateOnce = _status(409);

      final r = await sync.syncNow();

      expect(r.completed, isTrue);
      expect(products.store.keys, [p.id]);
      final left = await db.select(db.outboxEntries).get();
      expect(left.single.entityId, s.id);
      expect(left.single.attempts, 1);
      expect(left.single.lastError, contains('409'));
    });

    test('keo: ap vao local, luu moc, lan sau chi keo phan moi', () async {
      products.serverItems = [
        Product(id: 'p1', name: 'Sườn', pricePerKg: 180000, updatedAt: DateTime.utc(2026, 11, 9, 5)),
      ];
      txns.serverItems = [
        TransactionRecord(
          id: 'tx1',
          occurredAt: DateTime.utc(2026, 11, 9, 4),
          type: TxnType.debtPayment,
          customerId: 'c1',
          amount: 1000000,
          paidAmount: 1000000,
          updatedAt: DateTime.utc(2026, 11, 9, 6),
        ),
      ];

      final r = await sync.syncNow();
      expect(r.pulled, 2);
      expect((await productRepo.watchAll().first).single.name, 'Sườn');
      expect((await txRepo.getById('tx1'))?.type, TxnType.debtPayment);
      expect(products.listSince.last, isNull);

      await sync.syncNow();
      expect(products.listSince.last, DateTime.utc(2026, 11, 9, 5));
    });

    test('keo: ban ghi dang cho day thi local thang', () async {
      final p = await productRepo.create(name: 'Local', pricePerKg: 1);
      products.serverItems = [
        Product(id: p.id, name: 'Server', pricePerKg: 2, updatedAt: DateTime.utc(2030)),
      ];
      products.failCreateOnce = null;
      // Cho outbox con day: chi chay keo.
      await syncer(products).pull(db);
      expect((await productRepo.getById(p.id))?.name, 'Local');
    });

    test('keo: ban xoa tu server an khoi danh sach', () async {
      final p = await productRepo.create(name: 'A');
      await sync.syncNow(); // day xong
      products.serverItems = [
        Product(id: p.id, name: 'A', isDeleted: true, updatedAt: DateTime.utc(2030)),
      ];
      await sync.syncNow();
      expect(await productRepo.watchAll().first, isEmpty);
    });

    test('keo giao dich giu duong dan ghi am cua may nay', () async {
      final t = await txRepo.create(type: TxnType.sale, amount: 5, audioPath: '/tmp/a.wav');
      await sync.syncNow();
      txns.serverItems = [t.copyWith(amount: 7, updatedAt: DateTime.utc(2030))];
      await sync.syncNow();
      final got = await txRepo.getById(t.id);
      expect(got?.amount, 7);
      expect(got?.audioPath, '/tmp/a.wav');
    });

    test('delete gap 404 coi nhu da xong', () async {
      final p = await productRepo.create(name: 'A');
      await sync.syncNow();
      await productRepo.softDelete(p.id);
      final syncer404 = SyncService(
        db: db,
        remote: EmptyCustomerRemote(),
        syncers: [productSyncer(_Delete404Remote())],
        isOnline: () async => true,
      );
      final r = await syncer404.syncNow();
      expect(r.completed, isTrue);
      expect(await outboxCount(), 0);
      syncer404.dispose();
    });
  });

  group('JSON', () {
    test('TransactionRecord <-> JSON', () {
      final j = {
        'id': 'x',
        'occurredAt': '2026-11-09T01:02:03Z',
        'type': 'BuyPig',
        'customerId': null,
        'amount': 9800000,
        'paidAmount': 9800000,
        'confidence': 0.9,
        'rawText': 'mua lợn chín triệu tám',
        'updatedAt': '2026-11-09T01:02:04Z',
        'isDeleted': false,
      };
      final t = TransactionRecord.fromJson(j);
      expect(t.type, TxnType.buyPig);
      expect(t.occurredAt, DateTime.utc(2026, 11, 9, 1, 2, 3));
      expect(t.toUpsertBody()['type'], 'BuyPig');
      expect(t.toUpsertBody().containsKey('audioPath'), isFalse);
      expect(t.toUpsertBody().containsKey('isDeleted'), isFalse);
      expect(TransactionRecord.fromJson(t.toJson()), t);
    });

    test('Batch / Settlement doc ngay yyyy-MM-dd (bo phan gio neu co)', () {
      final b = PigBatch.fromJson(const {'id': 'b', 'date': '2026-11-09T00:00:00', 'pigCount': 2, 'buyCost': 10});
      expect(b.date, '2026-11-09');
      final s = DaySettlement.fromJson(const {'id': 's', 'date': '2026-11-09', 'countedCash': 5, 'difference': -3});
      expect(s.difference, -3);
      expect(s.toUpsertBody().keys, containsAll(['id', 'date', 'openingCash', 'countedCash', 'note']));
      expect(s.toUpsertBody().containsKey('expectedCash'), isFalse);
    });
  });
}

EntitySyncer<Product> syncer(EntityRemote<Product> r) => productSyncer(r);

class _Delete404Remote implements EntityRemote<Product> {
  @override
  Future<void> create(Product entity) async {}
  @override
  Future<void> update(Product entity) async {}
  @override
  Future<void> delete(String id) async => throw _status(404);
  @override
  Future<EntityPage<Product>> list({DateTime? updatedSince, required int page, required int pageSize}) async =>
      const EntityPage(items: [], hasMore: false);
}
