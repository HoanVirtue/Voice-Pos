import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/vn_format.dart';
import '../data/transaction_model.dart';
import '../data/txn_type.dart';

IconData txnIcon(TxnType t) => switch (t) {
      TxnType.sale => Icons.sell_outlined,
      TxnType.debtPayment => Icons.payments_outlined,
      TxnType.buyPig => Icons.pets_outlined,
      TxnType.expense => Icons.receipt_long_outlined,
      TxnType.cashOut => Icons.north_east,
    };

/// Mot dong giao dich trong so. Cau chua chac (vang) co bieu tuong canh bao.
class TxnTile extends StatelessWidget {
  final TransactionRecord record;
  final String? customerName;
  final String? productName;
  final VoidCallback? onTap;

  const TxnTile({
    super.key,
    required this.record,
    this.customerName,
    this.productName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final who = switch (r.type) {
      TxnType.sale => customerName ?? 'Khách lẻ',
      TxnType.debtPayment => customerName ?? 'Khách',
      _ => r.type.label,
    };
    final detail = <String>[
      if (r.type == TxnType.sale || r.type == TxnType.debtPayment) r.type.label,
      if (r.weightGram != null) formatWeight(r.weightGram!),
      if (productName != null) productName!,
    ];
    final isOut = r.type.isOutflow;
    final amountColor = isOut ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      key: Key('txn_${r.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: r.needsReview ? AppColors.warningLight : AppColors.primaryLight,
        child: Icon(
          r.needsReview ? Icons.warning_amber_rounded : txnIcon(r.type),
          color: r.needsReview ? AppColors.warning : AppColors.primary,
        ),
      ),
      title: Text(who, style: AppTextStyles.body1SemiBold),
      subtitle: Text(
        [VnTime.hm(r.occurredAt), ...detail].join(' · '),
        style: AppTextStyles.caption,
      ),
      // Trailing của ListTile cao tối đa 48px: cột 2 dòng (tiền + "nợ ...") co lại thay vì tràn.
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isOut ? '-' : ''}${formatMoney(r.amount)}',
              style: AppTextStyles.body1SemiBold.copyWith(color: amountColor),
            ),
            if (r.debt > 0)
              Text('nợ ${formatMoney(r.debt)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          ],
        ),
      ),
    );
  }
}
