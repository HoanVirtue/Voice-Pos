import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/customer_model.dart';
import '../providers/customer_providers.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final syncStatus = ref.watch(syncStatusProvider).valueOrNull;
    final canManage = hasPerm(ref, Perm.customersManage);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navCustomers),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ ngay',
            icon: const Icon(Icons.sync, size: 28),
            onPressed: () => ref.read(syncServiceProvider).syncNow(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: const Key('customer_add'),
              onPressed: () => context.push('/customers/new'),
              icon: const Icon(Icons.add, size: 30),
              label: const Text('Thêm khách', style: AppTextStyles.button),
            )
          : null,
      body: Column(
        children: [
          if (syncStatus == SyncStatus.offline)
            const StatusBanner(message: AppStrings.offline, icon: Icons.cloud_off),
          if (pending > 0)
            StatusBanner(
              message: '${AppStrings.pendingSync}: $pending',
              icon: Icons.sync_problem,
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              style: AppTextStyles.body1,
              decoration: const InputDecoration(
                hintText: AppStrings.search,
                prefixIcon: Icon(Icons.search, size: 28),
              ),
              onChanged: (v) => ref.read(customerSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e', style: AppTextStyles.body1)),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Chưa có khách hàng', style: AppTextStyles.body1),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _CustomerTile(
                        customer: list[i],
                        canManage: canManage,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends ConsumerWidget {
  final Customer customer;
  final bool canManage;

  const _CustomerTile({required this.customer, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('customer_${customer.id}'),
      leading: const CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Icon(Icons.person, color: AppColors.primary),
      ),
      title: Text(customer.name),
      subtitle: Text(
        [customer.alias, customer.phone].whereType<String>().join(' · '),
      ),
      trailing: canManage
          ? IconButton(
              tooltip: AppStrings.delete,
              icon: const Icon(Icons.delete_outline, size: 28, color: AppColors.danger),
              onPressed: () => _confirmDelete(context, ref),
            )
          : null,
      onTap: canManage ? () => context.push('/customers/${customer.id}') : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa ${customer.name}?'),
        content: const Text('Khách hàng sẽ được ẩn khỏi danh sách.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel, style: AppTextStyles.body1),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.delete,
              style: TextStyle(fontSize: 20, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(customerRepositoryProvider).softDelete(customer.id);
    }
  }
}
