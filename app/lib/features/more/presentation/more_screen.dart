import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';

/// Muc "Khac": cac man quan ly it dung hang ngay.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final items = <(IconData, String, String, String, bool)>[
      (Icons.people_outline, AppStrings.navCustomers, 'Danh bạ khách quen', AppRoutes.customers,
          perms.has(Perm.customersView)),
      (Icons.inventory_2_outlined, 'Món hàng', 'Ba chỉ, nạc vai... và giá một kg', AppRoutes.products,
          perms.has(Perm.transactionsView)),
      (Icons.pets_outlined, 'Lô hàng', 'Con lợn mua về, lãi theo lô', AppRoutes.batches,
          perms.has(Perm.transactionsView)),
      (Icons.shopping_cart_outlined, 'Tiền đi chợ', 'Tính tiền cần mang đi mua lợn', AppRoutes.marketCash,
          perms.hasAny([Perm.reportsView, Perm.transactionsView])),
      (Icons.account_circle_outlined, AppStrings.navSettings, 'Đồng bộ, đăng xuất', AppRoutes.account, true),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Khác')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final (icon, title, subtitle, route, enabled) = items[i];
          return ListTile(
            key: Key('more_$route'),
            enabled: enabled,
            leading: Icon(icon, size: 32, color: enabled ? AppColors.primary : AppColors.textMuted),
            title: Text(title),
            subtitle: Text(enabled ? subtitle : 'Chưa có quyền', style: AppTextStyles.body2),
            trailing: const Icon(Icons.chevron_right, size: 32),
            onTap: enabled ? () => context.push(route) : null,
          );
        },
      ),
    );
  }
}
