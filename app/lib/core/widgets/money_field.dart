import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/money_input.dart';
import '../utils/vn_format.dart';

/// O nhap tien: go "380" duoc hieu la 380.000 (cach noi o cho) va hien ngay "= 380.000 đ".
/// Dung [parseMoneyInput] tren `controller.text` de lay gia tri.
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<int?>? onChanged;

  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final parsed = parseMoneyInput(text);
        String? helper;
        String? error;
        if (text.isNotEmpty) {
          if (parsed == null) {
            error = 'Chưa hiểu số này';
          } else {
            helper = '= ${formatMoney(parsed)}';
          }
        } else if (required) {
          helper = 'Nhập số tiền';
        }
        return TextField(
          controller: controller,
          style: AppTextStyles.body1,
          keyboardType: TextInputType.text,
          onChanged: (t) => onChanged?.call(parseMoneyInput(t)),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperStyle: AppTextStyles.body2.copyWith(color: AppColors.success),
            errorText: error,
            suffixText: 'đ',
          ),
        );
      },
    );
  }
}
