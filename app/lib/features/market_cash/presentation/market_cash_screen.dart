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

/// Tien di cho: so con can mua x gia mot con + no moi + du phong (mac dinh 10%).
class MarketCashScreen extends ConsumerStatefulWidget {
  const MarketCashScreen({super.key});

  @override
  ConsumerState<MarketCashScreen> createState() => _MarketCashScreenState();
}

class _MarketCashScreenState extends ConsumerState<MarketCashScreen> {
  final _count = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _supplierDebt = TextEditingController();
  final _percent = TextEditingController(text: '10');

  @override
  void dispose() {
    _count.dispose();
    _price.dispose();
    _supplierDebt.dispose();
    _percent.dispose();
    super.dispose();
  }

  MarketCash _compute() => computeMarketCash(
        pigCount: int.tryParse(_count.text.trim()) ?? 0,
        pigPrice: parseMoneyInput(_price.text) ?? 0,
        supplierDebt: parseMoneyInput(_supplierDebt.text) ?? 0,
        reservePercent: int.tryParse(_percent.text.trim()) ?? 0,
      );

  Future<void> _record(MarketCash m) async {
    final count = int.tryParse(_count.text.trim()) ?? 0;
    await ref.read(transactionRepositoryProvider).create(
          type: TxnType.cashOut,
          amount: m.total,
          note: count > 0 ? 'Đi chợ mua $count con' : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã ghi mang đi chợ ${formatMoney(m.total)}')));
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final canView = perms.hasAny([Perm.reportsView, Perm.transactionsView]);
    final canManage = perms.has(Perm.transactionsManage);
    final cashInHand = ref.watch(dailyReportProvider(VnTime.today())).cashInHand;

    return Scaffold(
      appBar: AppBar(title: const Text('Tiền đi chợ')),
      body: !canView
          ? const NoPermissionView()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextField(
                  key: const Key('market_count'),
                  controller: _count,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.body1,
                  decoration: const InputDecoration(labelText: 'Số con cần mua', suffixText: 'con'),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const Key('market_price'),
                  child: MoneyField(controller: _price, label: 'Giá dự kiến một con'),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const Key('market_debt'),
                  child: MoneyField(controller: _supplierDebt, label: 'Nợ mối cần trả'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('market_percent'),
                  controller: _percent,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.body1,
                  decoration: const InputDecoration(labelText: 'Dự phòng', suffixText: '%'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AnimatedBuilder(
                  animation: Listenable.merge([_count, _price, _supplierDebt, _percent]),
                  builder: (context, _) {
                    final m = _compute();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            StatTile(label: 'Tiền mua lợn', value: formatMoney(m.pigCost)),
                            StatTile(label: 'Nợ mối', value: formatMoney(m.supplierDebt)),
                            StatTile(label: 'Dự phòng', value: formatMoney(m.reserve)),
                            const Divider(),
                            StatTile(
                              label: 'Cần mang đi',
                              value: formatMoney(m.total),
                              valueKey: const Key('market_total'),
                              color: AppColors.primary,
                            ),
                            StatTile(
                              label: 'Két hiện có (theo sổ hôm nay)',
                              value: formatMoney(cashInHand),
                              color: cashInHand >= m.total ? AppColors.success : AppColors.warning,
                            ),
                            if (canManage) ...[
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton(
                                key: const Key('market_record'),
                                onPressed: m.total > 0 ? () => _record(m) : null,
                                child: const Text('Ghi mang tiền đi'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
