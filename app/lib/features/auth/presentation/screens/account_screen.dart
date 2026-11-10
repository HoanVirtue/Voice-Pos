import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final sync = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.idle;
    final syncText = switch (sync) {
      SyncStatus.idle => AppStrings.synced,
      SyncStatus.syncing => AppStrings.syncing,
      SyncStatus.offline => 'Offline',
      SyncStatus.error => 'Lỗi đồng bộ',
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(user?.displayName ?? '', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [user?.username, user?.role]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(' · '),
            style: AppTextStyles.body1,
          ),
          const SizedBox(height: AppSpacing.xl),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Đồng bộ'),
            subtitle: Text(syncText),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 28),
              onPressed: () => ref.read(syncServiceProvider).syncNow(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Máy chủ'),
            subtitle: Text(
              '${AppConfig.environment.name} · ${AppConfig.environment.baseUrl}',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            key: const Key('logout'),
            label: AppStrings.signOut,
            outlined: true,
            icon: Icons.logout,
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
