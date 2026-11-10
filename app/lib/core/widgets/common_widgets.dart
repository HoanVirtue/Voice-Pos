import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// Hien khi tai khoan khong co quyen xem man hinh.
class NoPermissionView extends StatelessWidget {
  final String message;

  const NoPermissionView({super.key, this.message = 'Tài khoản chưa có quyền dùng mục này.'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, style: AppTextStyles.body1, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Man trong ("chua co ...").
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.body1.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The so lieu to (nhan + gia tri) dung o dau so / chot so.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final Key? valueKey;

  const StatTile({super.key, required this.label, required this.value, this.color, this.valueKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body1)),
          Text(
            value,
            key: valueKey,
            style: AppTextStyles.body1SemiBold.copyWith(color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Hop xac nhan xoa; tra true neu dong y.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Xóa',
  String cancelLabel = 'Hủy',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message, style: AppTextStyles.body1),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: AppTextStyles.body1),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(fontSize: 20, color: AppColors.danger)),
        ),
      ],
    ),
  );
  return ok == true;
}
