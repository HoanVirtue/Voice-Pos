import 'package:banhang_app/core/utils/vn_format.dart';
import 'package:banhang_app/features/settlements/data/settlement_repository.dart';
import 'package:banhang_app/features/settlements/presentation/settlement_screen.dart';
import 'package:banhang_app/features/transactions/data/transaction_repository.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  appTest('chot so: nhap tien dau ngay + ket dem -> hien chenh lech, luu duoc', (tester, db) async {
    final txns = TransactionRepository(db);
    final settlements = SettlementRepository(db);
    await tester.runAsync(() async {
      await txns.create(type: TxnType.sale, amount: 380000); // tra ngay
      await txns.create(type: TxnType.sale, amount: 200000, paidAmount: 50000, customerId: 'c'); // no 150k
      await txns.create(type: TxnType.buyPig, amount: 100000);
    });
    await tester.pumpWidget(appHarness(db: db, child: const SettlementScreen()));
    await settle(tester);

    // Tien dau ngay 0: thu 430.000, chi 100.000 -> 330.000.
    expect(textOf(tester, 'settle_expected'), '330.000 đ');
    expect(textOf(tester, 'settle_diff'), '—');

    await tester.enterText(fieldIn('settle_opening'), '1.000.000');
    await tester.pump();
    expect(textOf(tester, 'settle_expected'), '1.330.000 đ');

    await tester.enterText(fieldIn('settle_counted'), '1.330.000');
    await tester.pump();
    expect(textOf(tester, 'settle_diff'), 'Khớp');

    await tester.enterText(fieldIn('settle_counted'), '1.250.000');
    await tester.pump();
    expect(textOf(tester, 'settle_diff'), 'Thiếu 80.000 đ');

    await tester.enterText(fieldIn('settle_counted'), '1.340.000');
    await tester.pump();
    expect(textOf(tester, 'settle_diff'), 'Thừa 10.000 đ');

    await tester.enterText(fieldIn('settle_counted'), '1.250.000');
    await tester.enterText(find.byKey(const Key('settle_note')), 'thiếu tiền lẻ');
    await tester.pump();
    await pressKey(tester, 'settle_save');
    await settle(tester);

    final saved = await tester.runAsync(() => settlements.getByDate(VnTime.today()));
    expect(saved, isNotNull);
    expect(saved!.openingCash, 1000000);
    expect(saved.countedCash, 1250000);
    expect(saved.expectedCash, 1330000);
    expect(saved.difference, -80000);
    expect(saved.note, 'thiếu tiền lẻ');
    expect(find.text('Chốt lại'), findsOneWidget);
  });

  appTest('tien dau ngay lay tu ket dem lan chot truoc', (tester, db) async {
    final settlements = SettlementRepository(db);
    await tester.runAsync(() => settlements.save(
          date: VnTime.addDays(VnTime.today(), -1),
          openingCash: 0,
          countedCash: 5000000,
          expectedCash: 5000000,
        ));
    await tester.pumpWidget(appHarness(db: db, child: const SettlementScreen()));
    await settle(tester);

    expect(tester.widget<TextField>(fieldIn('settle_opening')).controller!.text, '5.000.000');
    expect(textOf(tester, 'settle_expected'), '5.000.000 đ');
  });

  appTest('chuyen ngay truoc: khong cho di qua hom nay', (tester, db) async {
    await tester.pumpWidget(appHarness(db: db, child: const SettlementScreen()));
    await settle(tester);

    final today = VnTime.today();
    expect(find.text('Hôm nay · ${VnTime.dmy(today)}'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('settle_next'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('settle_prev')));
    await settle(tester);
    expect(find.text(VnTime.dmy(VnTime.addDays(today, -1))), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('settle_next'))).onPressed, isNotNull);
  });

  appTest('nut doi ngay co tooltip cho trinh doc man hinh', (tester, db) async {
    await tester.pumpWidget(appHarness(db: db, child: const SettlementScreen()));
    await settle(tester);
    expect(tester.widget<IconButton>(find.byKey(const Key('settle_prev'))).tooltip, 'Ngày trước');
    expect(tester.widget<IconButton>(find.byKey(const Key('settle_next'))).tooltip, 'Ngày sau');
  });
}
