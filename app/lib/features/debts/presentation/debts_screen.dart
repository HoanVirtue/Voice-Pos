import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../ledger/providers/ledger_providers.dart';

/// So no: tung khach dang no bao nhieu (tu cao xuong thap), cham de xem chi tiet va thu no.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final canView = perms.hasAny([Perm.reportsView, Perm.transactionsView]);
    final rows = ref.watch(debtsProvider);
    final total = rows.where((r) => r.debt > 0).fold<int>(0, (s, r) => s + r.debt);

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ nợ')),
      body: !canView
          ? const NoPermissionView()
          : rows.isEmpty
              ? const EmptyView(message: 'Không có khách nào đang nợ', icon: Icons.check_circle_outline)
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.warningLight,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Tổng khách đang nợ', style: AppTextStyles.body1)),
                          Text(
                            formatMoney(total),
                            key: const Key('debts_total'),
                            style: AppTextStyles.h3.copyWith(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return ListTile(
                            key: Key('debt_${r.customerId}'),
                            title: Text(r.customerName),
                            subtitle: Text(
                              'Đã mua ${formatMoney(r.totalSale)} · đã trả ${formatMoney(r.totalPaid + r.totalDebtPayment)}',
                              style: AppTextStyles.caption,
                            ),
                            trailing: Text(
                              formatMoney(r.debt),
                              style: AppTextStyles.body1SemiBold.copyWith(
                                color: r.debt > 0 ? AppColors.danger : AppColors.success,
                              ),
                            ),
                            onTap: () => context.push('/debts/${r.customerId}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
