import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/vn_format.dart';
import '../../customers/data/customer_model.dart';
import '../../customers/providers/customer_providers.dart';
import '../../reports/report_calculator.dart';
import '../../settlements/data/settlement_model.dart';
import '../../settlements/providers/settlement_providers.dart';
import '../../transactions/providers/transaction_providers.dart';

/// Ngay dang xem o so (`yyyy-MM-dd`, gio VN).
final ledgerDateProvider = StateProvider.autoDispose<String>((ref) => VnTime.today());

/// Toan bo khach (khong loc), dung cho ten, khop giong noi.
final allCustomersProvider = StreamProvider.autoDispose<List<Customer>>(
  (ref) => ref.watch(customerRepositoryProvider).watchAll(),
);

/// Tien dau ngay: lan chot cua chinh ngay do, neu khong co thi tien dem lan chot truoc, neu khong thi 0.
int openingCashFor(List<DaySettlement> settlements, String date) {
  for (final s in settlements) {
    if (s.date == date) return s.openingCash;
  }
  DaySettlement? prev;
  for (final s in settlements) {
    if (s.date.compareTo(date) < 0 && (prev == null || s.date.compareTo(prev.date) > 0)) prev = s;
  }
  return prev?.countedCash ?? 0;
}

final openingCashProvider = Provider.autoDispose.family<int, String>((ref, date) {
  final list = ref.watch(settlementsProvider).valueOrNull ?? const <DaySettlement>[];
  return openingCashFor(list, date);
});

/// Bao cao ngay tinh cuc bo tu giao dich da luu.
final dailyReportProvider = Provider.autoDispose.family<DailyReport, String>((ref, date) {
  final txns = ref.watch(dayTransactionsProvider(date)).valueOrNull ?? const [];
  return computeDaily(txns, date, openingCash: ref.watch(openingCashProvider(date)));
});

/// Cong no theo khach.
final debtsProvider = Provider.autoDispose<List<DebtRow>>((ref) {
  final txns = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final customers = ref.watch(allCustomersProvider).valueOrNull ?? const <Customer>[];
  return computeDebts(txns, {for (final c in customers) c.id: c.name});
});

final customerDebtProvider = Provider.autoDispose.family<DebtDetail, String>((ref, customerId) {
  final txns = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final customers = ref.watch(allCustomersProvider).valueOrNull ?? const <Customer>[];
  final name = customers.where((c) => c.id == customerId).map((c) => c.name).firstOrNull ?? 'Khách';
  return computeCustomerDebt(txns, customerId, name);
});
