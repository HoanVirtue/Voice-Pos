import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:banhang_app/features/counter/counter_screen.dart';
import 'package:banhang_app/features/customers/data/customer_repository.dart';
import 'package:banhang_app/features/products/data/product_repository.dart';
import 'package:banhang_app/features/transactions/data/transaction_model.dart';
import 'package:banhang_app/features/transactions/data/transaction_repository.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

Future<void> settle(WidgetTester tester) async {
  // Thao tac drift chay nua trong vung gia (do UI goi) nua ngoai: xen ke cho that va tien thoi gian gia.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Bam nut trong the xac nhan (the nam trong bottom sheet cuon duoc nen goi thang onPressed).
Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  final w = tester.widget(f);
  if (w is ElevatedButton) {
    w.onPressed!();
  } else if (w is OutlinedButton) {
    w.onPressed!();
  } else {
    await tester.tap(f);
  }
  await tester.pump();
}

Finder fieldIn(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakeTts tts;
  late CustomerRepository customers;
  late ProductRepository products;
  late TransactionRepository txns;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tts = FakeTts();
    customers = CustomerRepository(db);
    products = ProductRepository(db);
    txns = TransactionRepository(db);
  });

  /// Test man hinh: man hinh du cao de thay het the, don stream drift truoc khi dong DB.
  void appTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
      // Khong goi db.close(): DB in-memory, dong trong vung gia co the treo (drift doi tac vu dang do).
    });
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(appHarness(db: db, tts: tts, child: const CounterScreen()));
    await settle(tester);
  }

  Future<List<TransactionRecord>> allTxns(WidgetTester tester) async =>
      (await tester.runAsync(() => txns.watchAll().first))!;

  appTest('go cau -> the xac nhan -> luu thanh giao dich ban, doc lai bang giong', (tester) async {
    await tester.runAsync(() async {
      await customers.create(name: 'Cô Lan');
      await products.create(name: 'Ba chỉ', pricePerKg: 190000);
    });
    await open(tester);

    await tester.enterText(find.byKey(const Key('counter_input')), 'Cô Lan hai cân ba chỉ ba trăm tám');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    // The xac nhan hien ket qua da hieu.
    expect(find.byKey(const Key('txn_level')), findsOneWidget);
    expect(find.text('Đã hiểu – kiểm tra rồi bấm Lưu'), findsOneWidget);
    expect(tester.widget<TextField>(fieldIn('txn_amount')).controller!.text, '380.000');
    expect(tester.widget<TextField>(find.byKey(const Key('txn_weight'))).controller!.text, '2');

    await tapKey(tester, 'txn_save');
    await settle(tester);

    final saved = await allTxns(tester);
    expect(saved, hasLength(1));
    expect(saved.single.type, TxnType.sale);
    expect(saved.single.amount, 380000);
    expect(saved.single.paidAmount, 380000);
    expect(saved.single.weightGram, 2000);
    expect(saved.single.customerId, isNotNull);
    expect(saved.single.rawText, 'Cô Lan hai cân ba chỉ ba trăm tám');
    expect(tts.spoken, ['Cô Lan, ba trăm tám mươi nghìn đồng, đã trả']);
    expect(find.textContaining('Vừa ghi'), findsOneWidget);
  });

  appTest('sua tien tren the truoc khi luu', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('counter_input')), 'Lẻ năm chục');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    await tester.enterText(fieldIn('txn_amount'), '60');
    await tester.pump();
    expect(find.text('= 60.000 đ'), findsWidgets);
    await tapKey(tester, 'txn_save');
    await settle(tester);

    final saved = await allTxns(tester);
    expect(saved.single.amount, 60000);
    expect(saved.single.paidAmount, 60000); // da tra het bam theo tien
    expect(saved.single.customerId, isNull);
  });

  appTest('ghi no khach chua co: bao loi, them khach vao danh ba roi luu duoc', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('counter_input')), 'Anh Minh ba trăm nợ');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    expect(find.text('Chưa chắc – xem kỹ trước khi lưu'), findsOneWidget);
    await tapKey(tester, 'txn_save');
    await tester.pump();
    expect(find.byKey(const Key('txn_error')), findsOneWidget);
    expect(find.text('Ghi nợ phải chọn khách'), findsOneWidget);

    await tapKey(tester, 'txn_add_customer');
    await settle(tester);
    await tapKey(tester, 'txn_save');
    await settle(tester);

    final saved = await allTxns(tester);
    expect(saved.single.amount, 300000);
    expect(saved.single.paidAmount, 0);
    expect(saved.single.customerId, isNotNull);
    final c = await tester.runAsync(() => customers.getById(saved.single.customerId!));
    expect(c?.name, 'Anh Minh');
  });

  appTest('"xoa cau vua roi" xoa mem giao dich gan nhat sau khi xac nhan', (tester) async {
    await tester.runAsync(() => txns.create(type: TxnType.sale, amount: 123000));
    await open(tester);

    await tester.enterText(find.byKey(const Key('counter_input')), 'Xóa câu vừa rồi');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);
    expect(find.text('Xóa giao dịch vừa rồi?'), findsOneWidget);

    await tester.tap(find.text('Xóa').last);
    await settle(tester);

    expect(await allTxns(tester), isEmpty);
  });

  appTest('"sua ..." mo the voi giao dich gan nhat va cap nhat tien', (tester) async {
    final t = (await tester.runAsync(() => txns.create(type: TxnType.sale, amount: 380000)))!;
    await open(tester);

    await tester.enterText(find.byKey(const Key('counter_input')), 'Sửa ba trăm sáu');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);
    expect(tester.widget<TextField>(fieldIn('txn_amount')).controller!.text, '360.000');

    await tapKey(tester, 'txn_save');
    await settle(tester);

    final got = (await tester.runAsync(() => txns.getById(t.id)))!;
    expect(got.amount, 360000);
    expect(got.paidAmount, 360000);
  });

  appTest('cau khong co so tien: the mau do, khong luu duoc khi chua nhap tien', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('counter_input')), 'Cô Lan');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    expect(find.text('Không hiểu hết – nhập tay giúp nhé'), findsOneWidget);
    await tapKey(tester, 'txn_save');
    await tester.pump();
    expect(find.text('Nhập số tiền'), findsWidgets);
    expect(await allTxns(tester), isEmpty);
  });

  appTest('bat "tu ghi cau chac chan": cau xanh ghi luon, khong hien the', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('counter_autosave')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('counter_input')), 'Lẻ năm chục');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    expect(find.byKey(const Key('txn_level')), findsNothing);
    expect((await allTxns(tester)).single.amount, 50000);
  });

  appTest('hoan tac cau vua ghi', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('counter_autosave')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('counter_input')), 'Lẻ năm chục');
    await tester.tap(find.byKey(const Key('counter_parse')));
    await settle(tester);

    await tester.tap(find.byTooltip('Hoàn tác'));
    await settle(tester);

    expect(await allTxns(tester), isEmpty);
  });
}
