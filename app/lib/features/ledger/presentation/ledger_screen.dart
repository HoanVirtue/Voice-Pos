import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../customers/data/customer_model.dart';
import '../../products/data/product_model.dart';
import '../../products/providers/product_providers.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/presentation/txn_draft.dart';
import '../../transactions/presentation/txn_editor_sheet.dart';
import '../../transactions/presentation/txn_tile.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../providers/ledger_providers.dart';

/// So hom nay: tong ket trong ngay + danh sach giao dich; cham mot dong de sua/xoa.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = hasPerm(ref, Perm.transactionsView);
    final canManage = hasPerm(ref, Perm.transactionsManage);
    final date = ref.watch(ledgerDateProvider);
    final today = VnTime.today();

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ hôm nay')),
      body: !canView
          ? const NoPermissionView()
          : Column(
              children: [
                _DateBar(date: date, isToday: date == today),
                Expanded(child: _Body(date: date, canManage: canManage)),
              ],
            ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  final String date;
  final bool isToday;

  const _DateBar({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void shift(int days) =>
        ref.read(ledgerDateProvider.notifier).state = VnTime.addDays(date, days);
    return Container(
      color: AppColors.bgSection,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            key: const Key('ledger_prev'),
            tooltip: 'Ngày trước',
            icon: const Icon(Icons.chevron_left, size: 36),
            onPressed: () => shift(-1),
          ),
          Expanded(
            child: Text(
              isToday ? 'Hôm nay · ${VnTime.dmy(date)}' : VnTime.dmy(date),
              key: const Key('ledger_date'),
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),
          ),
          IconButton(
            key: const Key('ledger_next'),
            tooltip: 'Ngày sau',
            icon: const Icon(Icons.chevron_right, size: 36),
            onPressed: isToday ? null : () => shift(1),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final String date;
  final bool canManage;

  const _Body({required this.date, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(dayTransactionsProvider(date));
    final report = ref.watch(dailyReportProvider(date));
    final customers = ref.watch(allCustomersProvider).valueOrNull ?? const <Customer>[];
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final cNames = {for (final c in customers) c.id: c.name};
    final pNames = {for (final p in products) p.id: p.name};

    return txns.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e', style: AppTextStyles.body1)),
      data: (list) => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          Card(
            margin: const EdgeInsets.all(AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  StatTile(
                    label: 'Doanh thu',
                    value: formatMoney(report.revenue),
                    valueKey: const Key('ledger_revenue'),
                  ),
                  StatTile(label: 'Thu tiền mặt (bán)', value: formatMoney(report.cashSales)),
                  StatTile(
                    label: 'Bán nợ mới',
                    value: formatMoney(report.newDebt),
                    color: report.newDebt > 0 ? AppColors.warning : null,
                  ),
                  StatTile(label: 'Thu nợ cũ', value: formatMoney(report.debtCollected)),
                  StatTile(label: 'Mua lợn + chi khác', value: formatMoney(report.buyPigCost + report.expenseCost)),
                  StatTile(label: 'Mang đi chợ', value: formatMoney(report.cashOut)),
                  const Divider(),
                  StatTile(
                    label: 'Tiền trong két (theo sổ)',
                    value: formatMoney(report.cashInHand),
                    valueKey: const Key('ledger_cash_in_hand'),
                    color: report.cashInHand < 0 ? AppColors.danger : AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: EmptyView(message: 'Chưa có giao dịch nào trong ngày'),
            )
          else
            for (final t in list)
              TxnTile(
                record: t,
                customerName: cNames[t.customerId],
                productName: pNames[t.productId],
                onTap: canManage ? () => _edit(context, ref, t) : null,
              ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, TransactionRecord t) async {
    final result = await showTxnEditorSheet(
      context,
      ref,
      draft: TxnDraft.fromRecord(t),
      saveLabel: 'Lưu sửa',
      allowDelete: true,
    );
    if (result == null) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (result.delete) {
      if (!context.mounted) return;
      final ok = await confirmDialog(context, title: 'Xóa giao dịch này?');
      if (ok) await repo.softDelete(t.id);
      return;
    }
    final d = result.draft!;
    await repo.update(t.copyWith(
      type: d.type,
      customerId: d.customerId,
      productId: d.productId,
      batchId: d.batchId,
      weightGram: d.weightGram,
      amount: d.amount,
      paidAmount: d.paidAmount,
      note: d.note,
      // Da duoc nguoi xem va sua: coi nhu chac chan.
      confidence: 1.0,
    ));
  }
}
