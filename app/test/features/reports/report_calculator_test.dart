import 'package:banhang_app/core/utils/vn_format.dart';
import 'package:banhang_app/features/batches/data/batch_model.dart';
import 'package:banhang_app/features/reports/report_calculator.dart';
import 'package:banhang_app/features/transactions/data/transaction_model.dart';
import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gio VN -> UTC.
DateTime vn(int y, int m, int d, [int h = 0, int mi = 0]) =>
    DateTime.utc(y, m, d, h, mi).subtract(VnTime.offset);

int _n = 0;

TransactionRecord tx(
  TxnType type,
  DateTime at, {
  String? customer,
  int amount = 0,
  int? paid,
  String? batch,
  bool deleted = false,
}) =>
    TransactionRecord(
      id: 't${_n++}',
      occurredAt: at,
      type: type,
      customerId: customer,
      batchId: batch,
      amount: amount,
      paidAmount: paid ?? amount,
      isDeleted: deleted,
      updatedAt: at,
    );

void main() {
  group('computeDaily', () {
    final day = vn(2026, 11, 9, 8);
    final txns = [
      tx(TxnType.sale, day, amount: 380000), // tra ngay
      tx(TxnType.sale, day, customer: 'a', amount: 200000, paid: 50000), // no 150k
      tx(TxnType.debtPayment, day, customer: 'b', amount: 1000000),
      tx(TxnType.buyPig, day, amount: 9800000),
      tx(TxnType.expense, day, amount: 30000),
      tx(TxnType.cashOut, day, amount: 15000000),
    ];

    test('cong thuc ngay', () {
      final r = computeDaily(txns, '2026-11-09', openingCash: 20000000);
      expect(r.revenue, 580000);
      expect(r.cashSales, 430000);
      expect(r.newDebt, 150000);
      expect(r.debtCollected, 1000000);
      expect(r.cashIn, 1430000);
      expect(r.buyPigCost, 9800000);
      expect(r.expenseCost, 30000);
      expect(r.cashOut, 15000000);
      // 20.000.000 + 1.430.000 - 9.800.000 - 30.000 - 15.000.000
      expect(r.cashInHand, -3400000);
      expect(r.transactionCount, 6);
    });

    test('ngay theo gio VN: 23:59 VN va 00:00 VN khac ngay', () {
      final late = tx(TxnType.sale, vn(2026, 11, 9, 23, 59), amount: 100);
      final next = tx(TxnType.sale, vn(2026, 11, 10, 0, 0), amount: 7);
      final before = tx(TxnType.sale, vn(2026, 11, 8, 23, 59), amount: 5);
      final d9 = computeDaily([late, next, before], '2026-11-09');
      final d10 = computeDaily([late, next, before], '2026-11-10');
      expect(d9.revenue, 100);
      expect(d10.revenue, 7);
      // 23:59 VN ngay 9 la 16:59 UTC ngay 9; 00:00 VN ngay 10 la 17:00 UTC ngay 9.
      expect(late.occurredAt.hour, 16);
      expect(next.occurredAt.day, 9);
    });

    test('bo qua giao dich da xoa', () {
      final r = computeDaily([tx(TxnType.sale, day, amount: 999, deleted: true)], '2026-11-09');
      expect(r.revenue, 0);
      expect(r.transactionCount, 0);
    });

    test('ngay trong: tien trong tay = tien dau ngay', () {
      final r = computeDaily(const [], '2026-11-09', openingCash: 500000);
      expect(r.cashInHand, 500000);
    });
  });

  group('computeDebts', () {
    final t0 = vn(2026, 11, 1, 8);
    final txns = [
      tx(TxnType.sale, t0, customer: 'lan', amount: 380000, paid: 0),
      tx(TxnType.sale, t0, customer: 'lan', amount: 200000, paid: 200000),
      tx(TxnType.debtPayment, t0, customer: 'lan', amount: 100000),
      tx(TxnType.sale, t0, customer: 'ha', amount: 500000, paid: 100000),
      tx(TxnType.sale, t0, customer: 'tu', amount: 100000, paid: 0),
      tx(TxnType.debtPayment, t0, customer: 'tu', amount: 100000), // het no
      tx(TxnType.sale, t0, amount: 50000, paid: 0), // khach le: khong tinh
      tx(TxnType.sale, t0, customer: 'xoa', amount: 10, paid: 0, deleted: true),
    ];
    final names = {'lan': 'Cô Lan', 'ha': 'Chị Hà', 'tu': 'Anh Tú'};

    test('no = ban - da tra - thu no; chi khach no != 0; giam dan', () {
      final rows = computeDebts(txns, names);
      expect(rows.map((r) => r.customerId), ['ha', 'lan']);
      expect(rows[0].debt, 400000);
      expect(rows[1].debt, 280000);
      expect(rows[1].totalSale, 580000);
      expect(rows[1].totalPaid, 200000);
      expect(rows[1].totalDebtPayment, 100000);
      expect(rows[1].customerName, 'Cô Lan');
    });

    test('khach tra thua -> no am van hien', () {
      final rows = computeDebts([
        tx(TxnType.sale, t0, customer: 'a', amount: 100, paid: 100),
        tx(TxnType.debtPayment, t0, customer: 'a', amount: 30),
      ], {'a': 'A'});
      expect(rows.single.debt, -30);
    });

    test('khach khong con trong danh ba -> ten mac dinh', () {
      final rows = computeDebts([tx(TxnType.sale, t0, customer: 'zz', amount: 5, paid: 0)], {});
      expect(rows.single.customerName, 'Khách đã xóa');
    });

    test('chi tiet no cua mot khach, debtDelta dung dau', () {
      final d = computeCustomerDebt(txns, 'lan', 'Cô Lan');
      expect(d.debt, 280000);
      expect(d.items.map((i) => i.debtDelta).toSet(), {380000, 0, -100000});
      expect(d.items.length, 3);
    });
  });

  group('computeMarketCash', () {
    test('mac dinh du phong 10%', () {
      final m = computeMarketCash(pigCount: 2, pigPrice: 7500000, supplierDebt: 1000000);
      expect(m.pigCost, 15000000);
      expect(m.reserve, 1500000);
      expect(m.total, 17500000);
    });

    test('lam tron du phong', () {
      final m = computeMarketCash(pigCount: 1, pigPrice: 1234567, reservePercent: 10);
      expect(m.reserve, 123457);
    });

    test('khong co gi -> 0', () {
      expect(computeMarketCash(pigCount: 0, pigPrice: 0).total, 0);
    });
  });

  group('computeBatchProfit', () {
    final batch = PigBatch(
      id: 'b1',
      date: '2026-11-09',
      pigCount: 2,
      buyCost: 15000000,
      otherCost: 500000,
      updatedAt: DateTime.utc(2026),
    );

    test('lai = doanh thu ban theo lo - tien mua - chi phi', () {
      final p = computeBatchProfit(batch, [
        tx(TxnType.sale, vn(2026, 11, 9), amount: 9000000, batch: 'b1'),
        tx(TxnType.sale, vn(2026, 11, 10), amount: 7000000, batch: 'b1'),
        tx(TxnType.sale, vn(2026, 11, 10), amount: 1, batch: 'b2'), // lo khac
        tx(TxnType.sale, vn(2026, 11, 10), amount: 1, batch: 'b1', deleted: true),
        tx(TxnType.expense, vn(2026, 11, 10), amount: 99, batch: 'b1'), // khong phai ban
      ]);
      expect(p.revenue, 16000000);
      expect(p.profit, 500000);
    });

    test('chua ban gi -> lo', () {
      final p = computeBatchProfit(batch, const []);
      expect(p.profit, -15500000);
    });
  });

  group('vn_format', () {
    test('formatMoney', () {
      expect(formatMoney(0), '0 đ');
      expect(formatMoney(1200000), '1.200.000 đ');
      expect(formatMoney(-3400000), '-3.400.000 đ');
    });
    test('formatWeight', () {
      expect(formatWeight(500), '500 g');
      expect(formatWeight(2000), '2 kg');
      expect(formatWeight(2500), '2,5 kg');
    });
    test('addDays qua thang', () {
      expect(VnTime.addDays('2026-11-30', 1), '2026-12-01');
      expect(VnTime.addDays('2026-01-01', -1), '2025-12-31');
    });
    test('dateString dung gio VN', () {
      expect(VnTime.dateString(DateTime.utc(2026, 11, 9, 17, 0)), '2026-11-10');
      expect(VnTime.dateString(DateTime.utc(2026, 11, 9, 16, 59)), '2026-11-09');
    });
  });
}
