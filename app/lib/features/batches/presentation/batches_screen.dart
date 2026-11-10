import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/money_field.dart';
import '../../reports/report_calculator.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../data/batch_model.dart';
import '../providers/batch_providers.dart';

/// Lo hang (con lon): ngay mua, so con, tien mua, chi phi; hien lai/lo theo cac giao dich ban gan voi lo.
class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = hasPerm(ref, Perm.transactionsView);
    final canManage = hasPerm(ref, Perm.transactionsManage);
    final batches = ref.watch(batchesProvider);
    final txns = ref.watch(allTransactionsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Lô hàng')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: const Key('batch_add'),
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add, size: 30),
              label: const Text('Thêm lô', style: AppTextStyles.button),
            )
          : null,
      body: !canView
          ? const NoPermissionView()
          : batches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e', style: AppTextStyles.body1)),
              data: (list) => list.isEmpty
                  ? const EmptyView(message: 'Chưa có lô hàng nào')
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = list[i];
                        final profit = computeBatchProfit(b, txns);
                        return ListTile(
                          key: Key('batch_${b.id}'),
                          title: Text('${VnTime.dmy(b.date)} · ${b.pigCount} con'),
                          subtitle: Text(
                            'Mua ${formatMoney(b.buyCost)} · chi phí ${formatMoney(b.otherCost)}\n'
                            'Đã bán ${formatMoney(profit.revenue)}',
                            style: AppTextStyles.caption,
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Trailing của ListTile cao tối đa 48px: co lại thay vì tràn khi chữ to.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Lãi', style: AppTextStyles.caption),
                                    Text(
                                      formatMoney(profit.profit),
                                      key: Key('batch_profit_${b.id}'),
                                      style: AppTextStyles.body1SemiBold.copyWith(
                                        color: profit.profit >= 0 ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canManage)
                                IconButton(
                                  tooltip: 'Xóa',
                                  icon: const Icon(Icons.delete_outline, size: 28, color: AppColors.danger),
                                  onPressed: () => _delete(context, ref, b),
                                ),
                            ],
                          ),
                          onTap: canManage ? () => _edit(context, ref, b) : null,
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PigBatch b) async {
    final ok = await confirmDialog(context, title: 'Xóa lô ${VnTime.dmy(b.date)}?');
    if (ok) await ref.read(batchRepositoryProvider).softDelete(b.id);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PigBatch? b) async {
    final result = await showDialog<PigBatch>(
      context: context,
      builder: (_) => _BatchDialog(batch: b),
    );
    if (result == null) return;
    final repo = ref.read(batchRepositoryProvider);
    if (b == null) {
      await repo.create(
        date: result.date,
        pigCount: result.pigCount,
        liveWeightGram: result.liveWeightGram,
        carcassWeightGram: result.carcassWeightGram,
        buyCost: result.buyCost,
        otherCost: result.otherCost,
        note: result.note,
      );
    } else {
      await repo.update(result);
    }
  }
}

class _BatchDialog extends StatefulWidget {
  final PigBatch? batch;

  const _BatchDialog({this.batch});

  @override
  State<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<_BatchDialog> {
  late String _date = widget.batch?.date ?? VnTime.today();
  late final _count = TextEditingController(text: '${widget.batch?.pigCount ?? 1}');
  late final _live = TextEditingController(text: gramToKgInputText(widget.batch?.liveWeightGram));
  late final _carcass = TextEditingController(text: gramToKgInputText(widget.batch?.carcassWeightGram));
  late final _buy = TextEditingController(
      text: widget.batch == null ? '' : moneyToInputText(widget.batch!.buyCost));
  late final _other = TextEditingController(
      text: widget.batch == null ? '' : moneyToInputText(widget.batch!.otherCost));
  late final _note = TextEditingController(text: widget.batch?.note ?? '');

  @override
  void dispose() {
    for (final c in [_count, _live, _carcass, _buy, _other, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final p = _date.split('-').map(int.parse).toList();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(p[0], p[1], p[2]),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _ok() {
    final old = widget.batch;
    Navigator.pop(
      context,
      PigBatch(
        id: old?.id ?? '',
        date: _date,
        pigCount: int.tryParse(_count.text.trim()) ?? 0,
        liveWeightGram: parseWeightInputGram(_live.text),
        carcassWeightGram: parseWeightInputGram(_carcass.text),
        buyCost: parseMoneyInput(_buy.text) ?? 0,
        otherCost: parseMoneyInput(_other.text) ?? 0,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        updatedAt: old?.updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.batch == null ? 'Thêm lô hàng' : 'Sửa lô hàng'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('batch_date'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ngày mua'),
              subtitle: Text(VnTime.dmy(_date), style: AppTextStyles.body1SemiBold),
              trailing: const Icon(Icons.calendar_month, size: 28),
              onTap: _pickDate,
            ),
            TextField(
              key: const Key('batch_count'),
              controller: _count,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body1,
              decoration: const InputDecoration(labelText: 'Số con', suffixText: 'con'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _live,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body1,
              decoration: const InputDecoration(labelText: 'Cân hơi', suffixText: 'kg'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carcass,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body1,
              decoration: const InputDecoration(labelText: 'Cân móc hàm', suffixText: 'kg'),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('batch_buy'),
              child: MoneyField(controller: _buy, label: 'Tiền mua lợn'),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('batch_other'),
              child: MoneyField(controller: _other, label: 'Chi phí mổ, chở, đá...'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              style: AppTextStyles.body1,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: AppTextStyles.body1),
        ),
        TextButton(
          key: const Key('batch_ok'),
          onPressed: _ok,
          child: const Text('Lưu', style: AppTextStyles.body1SemiBold),
        ),
      ],
    );
  }
}
