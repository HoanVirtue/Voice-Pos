import 'package:banhang_app/core/auth/permissions.dart';
import 'package:banhang_app/core/utils/vn_format.dart';
import 'package:banhang_app/features/batches/data/batch_repository.dart';
import 'package:banhang_app/features/batches/presentation/batches_screen.dart';
import 'package:banhang_app/features/customers/data/customer_repository.dart';
import 'package:banhang_app/features/debts/presentation/debt_detail_screen.dart';
import 'package:banhang_app/features/debts/presentation/debts_screen.dart';
import 'package:banhang_app/features/ledger/presentation/ledger_screen.dart';
import 'package:banhang_app/features/market_cash/presentation/market_cash_screen.dart';
import 'package:banhang_app/features/more/presentation/more_screen.dart';
import 'package:banhang_app/features/products/data/product_repository.dart';
import 'package:banhang_app/features/products/presentation/products_screen.dart';
import 'package:banhang_app/features/transactions/data/transaction_repository.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('So hom nay', () {
    appTest('tong ket ngay + danh sach, sua/xoa mot dong', (tester, db) async {
      final customers = CustomerRepository(db);
      final products = ProductRepository(db);
      final txns = TransactionRepository(db);
      late String saleId;
      await tester.runAsync(() async {
        final lan = await customers.create(name: 'Cô Lan');
        final bc = await products.create(name: 'Ba chỉ', pricePerKg: 190000);
        final t = await txns.create(
          type: TxnType.sale,
          customerId: lan.id,
          productId: bc.id,
          weightGram: 2000,
          amount: 380000,
          confidence: 0.95,
        );
        saleId = t.id;
        await txns.create(type: TxnType.sale, amount: 100000, paidAmount: 40000, customerId: lan.id, confidence: 0.6);
        await txns.create(type: TxnType.buyPig, amount: 50000);
      });
      await tester.pumpWidget(appHarness(db: db, child: const LedgerScreen()));
      await settle(tester);

      expect(textOf(tester, 'ledger_revenue'), '480.000 đ');
      // Thu tien mat 380.000 + 40.000, chi 50.000 -> 370.000.
      expect(textOf(tester, 'ledger_cash_in_hand'), '370.000 đ');
      expect(find.text('Cô Lan'), findsNWidgets(2));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget); // cau vang

      // Cham mot dong -> the sua; xoa.
      await tester.tap(find.byKey(Key('txn_$saleId')));
      await settle(tester);
      expect(find.byKey(const Key('txn_save')), findsOneWidget);
      await pressKey(tester, 'txn_delete');
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);

      expect(textOf(tester, 'ledger_revenue'), '100.000 đ');
    });

    appTest('chuyen sang ngay truoc: trong, khong qua hom nay', (tester, db) async {
      await tester.pumpWidget(appHarness(db: db, child: const LedgerScreen()));
      await settle(tester);
      expect(tester.widget<IconButton>(find.byKey(const Key('ledger_next'))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('ledger_prev')));
      await settle(tester);

      expect(find.text('Chưa có giao dịch nào trong ngày'), findsOneWidget);
      expect(textOf(tester, 'ledger_revenue'), '0 đ');
      expect(tester.widget<IconButton>(find.byKey(const Key('ledger_next'))).onPressed, isNotNull);
    });

    appTest('khong co quyen xem -> thong bao', (tester, db) async {
      await tester.pumpWidget(appHarness(
        db: db,
        permissions: const PermissionSet(<String>{}),
        child: const LedgerScreen(),
      ));
      await settle(tester);
      expect(find.text('Tài khoản chưa có quyền dùng mục này.'), findsOneWidget);
    });
  });

  group('So no', () {
    appTest('tong no va danh sach khach', (tester, db) async {
      final customers = CustomerRepository(db);
      final txns = TransactionRepository(db);
      await tester.runAsync(() async {
        final lan = await customers.create(name: 'Cô Lan');
        final ha = await customers.create(name: 'Chị Hà');
        await txns.create(type: TxnType.sale, customerId: lan.id, amount: 380000, paidAmount: 0);
        await txns.create(type: TxnType.sale, customerId: ha.id, amount: 500000, paidAmount: 100000);
        await txns.create(type: TxnType.debtPayment, customerId: ha.id, amount: 400000);
      });
      await tester.pumpWidget(appHarness(db: db, child: const DebtsScreen()));
      await settle(tester);

      expect(textOf(tester, 'debts_total'), '380.000 đ'); // Ha da het no
      expect(find.text('Cô Lan'), findsOneWidget);
      expect(find.text('Chị Hà'), findsNothing);
    });

    appTest('chua ai no -> man trong', (tester, db) async {
      await tester.pumpWidget(appHarness(db: db, child: const DebtsScreen()));
      await settle(tester);
      expect(find.text('Không có khách nào đang nợ'), findsOneWidget);
    });

    appTest('chi tiet no: thu no giam no, ghi giao dich thu no', (tester, db) async {
      final customers = CustomerRepository(db);
      final txns = TransactionRepository(db);
      late String id;
      await tester.runAsync(() async {
        final lan = await customers.create(name: 'Cô Lan');
        id = lan.id;
        await txns.create(type: TxnType.sale, customerId: id, amount: 380000, paidAmount: 0);
      });
      await tester.pumpWidget(appHarness(db: db, child: DebtDetailScreen(customerId: id)));
      await settle(tester);
      expect(textOf(tester, 'debt_detail_total'), '380.000 đ');

      await pressKey(tester, 'debt_collect');
      await settle(tester);
      // Mac dinh dien san toan bo no; doi thanh 200.000.
      expect(tester.widget<TextField>(fieldIn('collect_amount')).controller!.text, '380.000');
      await tester.enterText(fieldIn('collect_amount'), '200');
      await tester.pump();
      await pressKey(tester, 'collect_ok');
      await settle(tester);

      expect(textOf(tester, 'debt_detail_total'), '180.000 đ');
      final all = (await tester.runAsync(() => txns.watchAll().first))!;
      expect(all.where((t) => t.type == TxnType.debtPayment).single.amount, 200000);
    });
  });

  group('Tien di cho', () {
    appTest('tinh tien can mang va ghi mang tien di', (tester, db) async {
      final txns = TransactionRepository(db);
      await tester.pumpWidget(appHarness(db: db, child: const MarketCashScreen()));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('market_count')), '2');
      await tester.enterText(fieldIn('market_price'), '7,5 triệu');
      await tester.enterText(fieldIn('market_debt'), '1.000.000');
      await tester.pump();
      // 2 x 7.500.000 = 15.000.000, du phong 10% = 1.500.000, no moi 1.000.000.
      expect(textOf(tester, 'market_total'), '17.500.000 đ');

      await tester.enterText(find.byKey(const Key('market_percent')), '0');
      await tester.pump();
      expect(textOf(tester, 'market_total'), '16.000.000 đ');

      await tester.enterText(find.byKey(const Key('market_percent')), '10');
      await tester.pump();
      await pressKey(tester, 'market_record');
      await settle(tester);

      final all = (await tester.runAsync(() => txns.watchAll().first))!;
      expect(all.single.type, TxnType.cashOut);
      expect(all.single.amount, 17500000);
      expect(all.single.note, 'Đi chợ mua 2 con');
    });
  });

  group('Mon hang', () {
    appTest('them mon, hien gia/kg, xoa', (tester, db) async {
      await tester.pumpWidget(appHarness(db: db, child: const ProductsScreen()));
      await settle(tester);
      expect(find.textContaining('Chưa có món hàng'), findsOneWidget);

      await tester.tap(find.byKey(const Key('product_add')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('product_name')), 'Ba chỉ');
      await tester.enterText(find.byKey(const Key('product_alias')), 'ba rọi');
      await tester.enterText(fieldIn('product_price'), '190000');
      await pressKey(tester, 'product_ok');
      await settle(tester);

      expect(find.text('Ba chỉ'), findsOneWidget);
      expect(find.text('190.000 đ/kg'), findsOneWidget);
      expect(find.text('Còn gọi: ba rọi'), findsOneWidget);

      await tester.tap(find.byTooltip('Xóa'));
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(find.text('Ba chỉ'), findsNothing);
    });

    appTest('ten mon trong -> bao loi, khong dong hop thoai', (tester, db) async {
      await tester.pumpWidget(appHarness(db: db, child: const ProductsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const Key('product_add')));
      await settle(tester);
      await pressKey(tester, 'product_ok');
      await tester.pump();
      expect(find.text('Nhập tên món'), findsOneWidget);
    });
  });

  group('Lo hang', () {
    appTest('them lo, lai theo lo = ban gan voi lo - tien mua - chi phi', (tester, db) async {
      final batches = BatchRepository(db);
      final txns = TransactionRepository(db);
      late String batchId;
      await tester.runAsync(() async {
        final b = await batches.create(pigCount: 2, buyCost: 15000000, otherCost: 0);
        batchId = b.id;
        await txns.create(type: TxnType.sale, amount: 9000000, batchId: b.id);
        await txns.create(type: TxnType.sale, amount: 777, batchId: 'khac');
      });
      await tester.pumpWidget(appHarness(db: db, child: const BatchesScreen()));
      await settle(tester);

      expect(find.textContaining('2 con'), findsOneWidget);
      expect(textOf(tester, 'batch_profit_$batchId'), '-6.000.000 đ');
    });

    appTest('them lo qua hop thoai', (tester, db) async {
      await tester.pumpWidget(appHarness(db: db, child: const BatchesScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const Key('batch_add')));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('batch_count')), '3');
      await tester.enterText(fieldIn('batch_buy'), '22.000.000');
      await pressKey(tester, 'batch_ok');
      await settle(tester);

      expect(find.text('${VnTime.dmy(VnTime.today())} · 3 con'), findsOneWidget);
      expect(find.textContaining('Mua 22.000.000 đ'), findsOneWidget);
    });
  });

  group('Muc Khac', () {
    appTest('liet ke man quan ly; muc khong co quyen bi khoa', (tester, db) async {
      await tester.pumpWidget(appHarness(
        db: db,
        permissions: const PermissionSet({Perm.customersView}),
        child: const MoreScreen(),
      ));
      await settle(tester);

      expect(find.text('Khách hàng'), findsOneWidget);
      expect(find.text('Món hàng'), findsOneWidget);
      expect(find.text('Lô hàng'), findsOneWidget);
      expect(find.text('Tiền đi chợ'), findsOneWidget);
      expect(find.text('Chưa có quyền'), findsNWidgets(3));
      expect(tester.widget<ListTile>(find.byKey(const Key('more_/products'))).enabled, isFalse);
      expect(tester.widget<ListTile>(find.byKey(const Key('more_/customers'))).enabled, isTrue);
    });
  });
}
