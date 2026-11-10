import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/money_field.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../reports/report_calculator.dart';
import '../../transactions/data/txn_type.dart';
import '../../transactions/providers/transaction_providers.dart';

/// Chi tiet no cua mot khach + nut "Thu no".
class DebtDetailScreen extends ConsumerWidget {
  final String customerId;

  const DebtDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDebtProvider(customerId));
    final canManage = hasPerm(ref, Perm.transactionsManage);

    return Scaffold(
      appBar: AppBar(title: Text(detail.customerName)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Text('Đang nợ', style: AppTextStyles.body1),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatMoney(detail.debt),
                    key: const Key('debt_detail_total'),
                    style: AppTextStyles.display.copyWith(
                      color: detail.debt > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      key: const Key('debt_collect'),
                      icon: const Icon(Icons.payments_outlined, size: 28),
                      label: const Text('Thu nợ'),
                      onPressed: () => _collect(context, ref, detail),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (detail.items.isEmpty)
            const EmptyView(message: 'Chưa có giao dịch với khách này')
          else
            for (final i in detail.items)
              ListTile(
                key: Key('debt_item_${i.transactionId}'),
                leading: Icon(i.type == TxnType.sale ? Icons.sell_outlined : Icons.payments_outlined),
                title: Text(i.type == TxnType.sale ? 'Mua hàng ${formatMoney(i.amount)}' : 'Trả nợ ${formatMoney(i.amount)}'),
                subtitle: Text(
                  '${VnTime.dmy(VnTime.dateString(i.occurredAt))} ${VnTime.hm(i.occurredAt)}'
                  '${i.type == TxnType.sale ? ' · đã trả ${formatMoney(i.paidAmount)}' : ''}',
                  style: AppTextStyles.caption,
                ),
                trailing: Text(
                  '${i.debtDelta > 0 ? '+' : ''}${formatMoney(i.debtDelta)}',
                  style: AppTextStyles.body1SemiBold.copyWith(
                    color: i.debtDelta > 0 ? AppColors.danger : AppColors.success,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _collect(BuildContext context, WidgetRef ref, DebtDetail detail) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _CollectDialog(defaultAmount: detail.debt > 0 ? detail.debt : 0, name: detail.customerName),
    );
    if (amount == null || amount <= 0) return;
    await ref.read(transactionRepositoryProvider).create(
          type: TxnType.debtPayment,
          customerId: detail.customerId,
          amount: amount,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thu nợ ${formatMoney(amount)}')),
      );
    }
  }
}

class _CollectDialog extends StatefulWidget {
  final int defaultAmount;
  final String name;

  const _CollectDialog({required this.defaultAmount, required this.name});

  @override
  State<_CollectDialog> createState() => _CollectDialogState();
}

class _CollectDialogState extends State<_CollectDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.defaultAmount > 0 ? moneyToInputText(widget.defaultAmount) : '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.name} trả nợ'),
      content: KeyedSubtree(
        key: const Key('collect_amount'),
        child: MoneyField(controller: _c, label: 'Số tiền trả', required: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: AppTextStyles.body1),
        ),
        TextButton(
          key: const Key('collect_ok'),
          onPressed: () => Navigator.pop(context, parseMoneyInput(_c.text)),
          child: const Text('Thu nợ', style: AppTextStyles.body1SemiBold),
        ),
      ],
    );
  }
}
