// Cong thuc bao cao tinh cuc bo (offline) tu giao dich - khop docs/hop-dong-api-so-ban-hang.md.
// Thuan Dart: ngay tinh theo gio VN (UTC+7).

import '../../core/utils/vn_format.dart';
import '../batches/data/batch_model.dart';
import '../transactions/data/transaction_model.dart';
import '../transactions/data/txn_type.dart';

/// Bao cao ngay.
class DailyReport {
  final String date;

  /// Tong tien cac giao dich ban (ca tra ngay lan no).
  final int revenue;
  final int cashSales;
  final int newDebt;
  final int debtCollected;

  /// = cashSales + debtCollected
  final int cashIn;
  final int buyPigCost;
  final int expenseCost;
  final int cashOut;

  /// = openingCash + cashIn - buyPigCost - expenseCost - cashOut
  final int cashInHand;
  final int transactionCount;

  const DailyReport({
    required this.date,
    required this.revenue,
    required this.cashSales,
    required this.newDebt,
    required this.debtCollected,
    required this.cashIn,
    required this.buyPigCost,
    required this.expenseCost,
    required this.cashOut,
    required this.cashInHand,
    required this.transactionCount,
  });
}

DailyReport computeDaily(List<TransactionRecord> txns, String date, {int openingCash = 0}) {
  final (from, to) = VnTime.dayRangeUtc(date);
  var revenue = 0, cashSales = 0, debtCollected = 0, buyPig = 0, expense = 0, cashOut = 0, count = 0;
  for (final t in txns) {
    if (t.isDeleted) continue;
    final at = t.occurredAt.toUtc();
    if (at.isBefore(from) || !at.isBefore(to)) continue;
    count++;
    switch (t.type) {
      case TxnType.sale:
        revenue += t.amount;
        cashSales += t.paidAmount;
      case TxnType.debtPayment:
        debtCollected += t.amount;
      case TxnType.buyPig:
        buyPig += t.amount;
      case TxnType.expense:
        expense += t.amount;
      case TxnType.cashOut:
        cashOut += t.amount;
    }
  }
  final cashIn = cashSales + debtCollected;
  return DailyReport(
    date: date,
    revenue: revenue,
    cashSales: cashSales,
    newDebt: revenue - cashSales,
    debtCollected: debtCollected,
    cashIn: cashIn,
    buyPigCost: buyPig,
    expenseCost: expense,
    cashOut: cashOut,
    cashInHand: openingCash + cashIn - buyPig - expense - cashOut,
    transactionCount: count,
  );
}

/// Cong no mot khach.
class DebtRow {
  final String customerId;
  final String customerName;
  final int totalSale;
  final int totalPaid;
  final int totalDebtPayment;

  /// = totalSale - totalPaid - totalDebtPayment
  final int debt;

  const DebtRow({
    required this.customerId,
    required this.customerName,
    required this.totalSale,
    required this.totalPaid,
    required this.totalDebtPayment,
    required this.debt,
  });
}

/// Danh sach no theo khach: chi khach co no != 0, no giam dan.
/// [customerNames]: id -> ten (khach da xoa van nen co mat de khong mat no).
List<DebtRow> computeDebts(List<TransactionRecord> txns, Map<String, String> customerNames) {
  final sale = <String, int>{};
  final paid = <String, int>{};
  final pay = <String, int>{};
  for (final t in txns) {
    if (t.isDeleted || t.customerId == null) continue;
    final id = t.customerId!;
    switch (t.type) {
      case TxnType.sale:
        sale[id] = (sale[id] ?? 0) + t.amount;
        paid[id] = (paid[id] ?? 0) + t.paidAmount;
      case TxnType.debtPayment:
        pay[id] = (pay[id] ?? 0) + t.amount;
      case TxnType.buyPig:
      case TxnType.expense:
      case TxnType.cashOut:
        break;
    }
  }
  final ids = {...sale.keys, ...pay.keys};
  final rows = <DebtRow>[];
  for (final id in ids) {
    final s = sale[id] ?? 0;
    final p = paid[id] ?? 0;
    final d = pay[id] ?? 0;
    final debt = s - p - d;
    if (debt == 0) continue;
    rows.add(DebtRow(
      customerId: id,
      customerName: customerNames[id] ?? 'Khách đã xóa',
      totalSale: s,
      totalPaid: p,
      totalDebtPayment: d,
      debt: debt,
    ));
  }
  rows.sort((a, b) => b.debt.compareTo(a.debt));
  return rows;
}

class DebtItem {
  final String transactionId;
  final DateTime occurredAt;
  final TxnType type;
  final int amount;
  final int paidAmount;

  /// Thay doi no: ban = amount - paidAmount; thu no = -amount.
  final int debtDelta;

  const DebtItem({
    required this.transactionId,
    required this.occurredAt,
    required this.type,
    required this.amount,
    required this.paidAmount,
    required this.debtDelta,
  });
}

class DebtDetail {
  final String customerId;
  final String customerName;
  final int debt;
  final List<DebtItem> items;

  const DebtDetail({
    required this.customerId,
    required this.customerName,
    required this.debt,
    required this.items,
  });
}

/// Chi tiet no mot khach (moi nhat truoc). Chi tinh ban va thu no.
DebtDetail computeCustomerDebt(List<TransactionRecord> txns, String customerId, String customerName) {
  final items = <DebtItem>[];
  var debt = 0;
  for (final t in txns) {
    if (t.isDeleted || t.customerId != customerId) continue;
    final int delta;
    if (t.type == TxnType.sale) {
      delta = t.amount - t.paidAmount;
    } else if (t.type == TxnType.debtPayment) {
      delta = -t.amount;
    } else {
      continue;
    }
    debt += delta;
    items.add(DebtItem(
      transactionId: t.id,
      occurredAt: t.occurredAt,
      type: t.type,
      amount: t.amount,
      paidAmount: t.paidAmount,
      debtDelta: delta,
    ));
  }
  items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return DebtDetail(customerId: customerId, customerName: customerName, debt: debt, items: items);
}

/// Tien mang di cho.
class MarketCash {
  final int pigCost;
  final int supplierDebt;
  final int reserve;
  final int total;

  const MarketCash({
    required this.pigCost,
    required this.supplierDebt,
    required this.reserve,
    required this.total,
  });
}

/// Goi y mang di cho: tien lon + no moi + du phong (mac dinh 10%).
/// [pigPrice]: gia du kien MOT con (dong).
MarketCash computeMarketCash({
  required int pigCount,
  required int pigPrice,
  int supplierDebt = 0,
  int reservePercent = 10,
}) {
  final pigCost = pigCount * pigPrice;
  final reserve = (pigCost * reservePercent / 100).round();
  return MarketCash(
    pigCost: pigCost,
    supplierDebt: supplierDebt,
    reserve: reserve,
    total: pigCost + supplierDebt + reserve,
  );
}

/// Lai theo lo.
class BatchProfit {
  final String batchId;
  final int revenue;
  final int buyCost;
  final int otherCost;

  /// = revenue - buyCost - otherCost
  final int profit;

  const BatchProfit({
    required this.batchId,
    required this.revenue,
    required this.buyCost,
    required this.otherCost,
    required this.profit,
  });
}

BatchProfit computeBatchProfit(PigBatch batch, List<TransactionRecord> txns) {
  var revenue = 0;
  for (final t in txns) {
    if (t.isDeleted || t.type != TxnType.sale || t.batchId != batch.id) continue;
    revenue += t.amount;
  }
  return BatchProfit(
    batchId: batch.id,
    revenue: revenue,
    buyCost: batch.buyCost,
    otherCost: batch.otherCost,
    profit: revenue - batch.buyCost - batch.otherCost,
  );
}
