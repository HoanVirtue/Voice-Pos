import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_spacing.dart';
import '../../batches/providers/batch_providers.dart';
import '../../customers/data/customer_model.dart';
import '../../customers/providers/customer_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../products/providers/product_providers.dart';
import 'txn_draft.dart';
import 'txn_editor_card.dart';

/// Ket qua the xac nhan: luu ([draft] != null) hoac xoa ([delete]); null neu bo qua.
typedef TxnEditorResult = ({TxnDraft? draft, bool delete});

/// Mo the xac nhan/sua giao dich o day man hinh.
Future<TxnEditorResult?> showTxnEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  required TxnDraft draft,
  String saveLabel = 'Lưu',
  bool allowDelete = false,
}) {
  final customers = ref.read(allCustomersProvider).valueOrNull ?? const <Customer>[];
  final products = ref.read(productsProvider).valueOrNull ?? const [];
  final batches = ref.read(batchesProvider).valueOrNull ?? const [];
  final canCreateCustomer = ref.read(permissionsProvider).has(Perm.customersManage);
  return showModalBottomSheet<TxnEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: TxnEditorCard(
          draft: draft,
          customers: customers,
          products: products,
          batches: batches,
          saveLabel: saveLabel,
          onSave: (d) => Navigator.pop(ctx, (draft: d, delete: false)),
          onCancel: () => Navigator.pop(ctx),
          onDelete: allowDelete ? () => Navigator.pop(ctx, (draft: null, delete: true)) : null,
          onCreateCustomer: canCreateCustomer
              ? (name) async {
                  final c = await ref.read(customerRepositoryProvider).create(name: name);
                  return c.id;
                }
              : null,
        ),
      ),
    ),
  );
}
