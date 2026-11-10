import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/money_field.dart';
import '../../batches/data/batch_model.dart';
import '../../customers/data/customer_model.dart';
import '../../products/data/product_model.dart';
import '../data/txn_type.dart';
import '../parser/market_parser.dart' show ParseLevel;
import 'txn_draft.dart';

/// The xac nhan / sua giao dich: hien ket qua hieu duoc (xanh/vang/do), cho sua moi truong roi luu.
class TxnEditorCard extends StatefulWidget {
  final TxnDraft draft;
  final List<Customer> customers;
  final List<Product> products;
  final List<PigBatch> batches;
  final String saveLabel;
  final ValueChanged<TxnDraft> onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  /// Tao khach moi tu ten nghe duoc; tra id khach vua tao.
  final Future<String?> Function(String name)? onCreateCustomer;

  const TxnEditorCard({
    super.key,
    required this.draft,
    required this.customers,
    this.products = const [],
    this.batches = const [],
    this.saveLabel = 'Lưu',
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.onCreateCustomer,
  });

  @override
  State<TxnEditorCard> createState() => _TxnEditorCardState();
}

class _TxnEditorCardState extends State<TxnEditorCard> {
  late TxnType _type;
  String? _customerId;
  String? _productId;
  String? _batchId;
  String? _unmatchedName;
  late final TextEditingController _weight;
  late final TextEditingController _amount;
  late final TextEditingController _paid;
  late final TextEditingController _note;
  late bool _paidFollowsAmount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _type = d.type;
    _customerId = d.customerId;
    _productId = d.productId;
    _batchId = d.batchId;
    _unmatchedName = d.unmatchedCustomerName;
    _weight = TextEditingController(text: gramToKgInputText(d.weightGram));
    _amount = TextEditingController(text: d.amount > 0 ? moneyToInputText(d.amount) : '');
    _paid = TextEditingController(text: moneyToInputText(d.paidAmount));
    _note = TextEditingController(text: d.note ?? '');
    _paidFollowsAmount = d.paidAmount == d.amount;
    _amount.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _weight.dispose();
    _amount.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (_paidFollowsAmount && _type == TxnType.sale) {
      final a = parseMoneyInput(_amount.text);
      _paid.text = a == null ? '' : moneyToInputText(a);
    }
  }

  void _setPaid(int value) {
    _paid.text = moneyToInputText(value);
    final a = parseMoneyInput(_amount.text);
    setState(() => _paidFollowsAmount = a != null && a == value);
  }

  (Color, Color, IconData, String) _levelStyle() {
    switch (widget.draft.level) {
      case ParseLevel.green:
        return (AppColors.successLight, AppColors.success, Icons.check_circle, 'Đã hiểu – kiểm tra rồi bấm Lưu');
      case ParseLevel.yellow:
        return (AppColors.warningLight, AppColors.warning, Icons.warning_amber_rounded, 'Chưa chắc – xem kỹ trước khi lưu');
      case ParseLevel.red:
        return (AppColors.dangerLight, AppColors.danger, Icons.error_outline, 'Không hiểu hết – nhập tay giúp nhé');
    }
  }

  void _save() {
    final amount = parseMoneyInput(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Nhập số tiền');
      return;
    }
    final isSale = _type == TxnType.sale;
    final paid = isSale ? (parseMoneyInput(_paid.text) ?? amount) : amount;
    if (isSale && paid > amount) {
      setState(() => _error = 'Tiền trả không được lớn hơn tiền hàng');
      return;
    }
    if (_type == TxnType.debtPayment && _customerId == null) {
      setState(() => _error = 'Thu nợ phải chọn khách');
      return;
    }
    if (isSale && paid < amount && _customerId == null) {
      setState(() => _error = 'Ghi nợ phải chọn khách');
      return;
    }
    final d = widget.draft
      ..type = _type
      ..customerId = _customerId
      ..productId = isSale ? _productId : null
      ..batchId = _batchId
      ..weightGram = isSale ? parseWeightInputGram(_weight.text) : null
      ..amount = amount
      ..paidAmount = paid
      ..note = _note.text.trim().isEmpty ? null : _note.text.trim();
    widget.onSave(d);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final (bg, fg, icon, text) = _levelStyle();
    final isSale = _type == TxnType.sale;
    final ids = widget.customers.map((c) => c.id).toSet();
    final customerValue = ids.contains(_customerId) ? _customerId : null;
    final productValue = widget.products.any((p) => p.id == _productId) ? _productId : null;
    final batchValue = widget.batches.any((b) => b.id == _batchId) ? _batchId : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('txn_level'),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(text, style: AppTextStyles.body2.copyWith(color: fg))),
            ],
          ),
        ),
        if (d.rawText != null && d.rawText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Nghe được: “${d.rawText}”',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in TxnType.values)
              ChoiceChip(
                key: Key('txn_type_${t.apiName}'),
                label: Text(t.label, style: AppTextStyles.body2),
                selected: _type == t,
                onSelected: (_) => setState(() {
                  _type = t;
                  if (t != TxnType.sale) _paidFollowsAmount = true;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_type == TxnType.sale || _type == TxnType.debtPayment) ...[
          DropdownButtonFormField<String?>(
            key: ValueKey('txn_customer_$_customerId'),
            initialValue: customerValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _type == TxnType.debtPayment ? 'Khách trả nợ' : 'Khách',
            ),
            style: AppTextStyles.body1.copyWith(color: AppColors.textPrimary),
            items: [
              if (_type == TxnType.sale)
                const DropdownMenuItem<String?>(value: null, child: Text('Khách lẻ')),
              for (final c in widget.customers)
                DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _customerId = v),
          ),
          if (_unmatchedName != null && widget.onCreateCustomer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('txn_add_customer'),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Thêm “$_unmatchedName” vào danh bạ', style: AppTextStyles.body2),
              onPressed: () async {
                final name = _unmatchedName!;
                final id = await widget.onCreateCustomer!(name);
                if (id != null && mounted) {
                  setState(() {
                    _customerId = id;
                    _unmatchedName = null;
                  });
                }
              },
            ),
          ] else if (d.ambiguousCustomerIds.isNotEmpty && _customerId == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Có nhiều khách trùng tên – chọn đúng khách.',
                style: AppTextStyles.body2.copyWith(color: AppColors.warning)),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        if (isSale) ...[
          DropdownButtonFormField<String?>(
            key: ValueKey('txn_product_$_productId'),
            initialValue: productValue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Món'),
            style: AppTextStyles.body1.copyWith(color: AppColors.textPrimary),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('(không chọn)')),
              for (final p in widget.products)
                DropdownMenuItem<String?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _productId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('txn_weight'),
            controller: _weight,
            style: AppTextStyles.body1,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Số cân', suffixText: 'kg'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_type == TxnType.buyPig && widget.batches.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            key: ValueKey('txn_batch_$_batchId'),
            initialValue: batchValue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lô hàng'),
            style: AppTextStyles.body1.copyWith(color: AppColors.textPrimary),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('(không chọn)')),
              for (final b in widget.batches)
                DropdownMenuItem<String?>(
                    value: b.id, child: Text('${VnTime.dmy(b.date)} · ${b.pigCount} con')),
            ],
            onChanged: (v) => setState(() => _batchId = v),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        KeyedSubtree(
          key: const Key('txn_amount'),
          child: MoneyField(
            controller: _amount,
            label: _type == TxnType.sale ? 'Tổng tiền' : 'Số tiền',
            required: true,
          ),
        ),
        if (isSale) ...[
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: const Key('txn_paid'),
            child: MoneyField(
              controller: _paid,
              label: 'Đã trả',
              onChanged: (v) {
                final a = parseMoneyInput(_amount.text);
                setState(() => _paidFollowsAmount = v != null && a != null && v == a);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('txn_paid_all'),
                  onPressed: () => _setPaid(parseMoneyInput(_amount.text) ?? 0),
                  child: const Text('Trả hết', style: AppTextStyles.body2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: const Key('txn_paid_none'),
                  onPressed: () => _setPaid(0),
                  child: const Text('Ghi nợ hết', style: AppTextStyles.body2),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('txn_note'),
          controller: _note,
          style: AppTextStyles.body1,
          decoration: const InputDecoration(labelText: 'Ghi chú'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, key: const Key('txn_error'), style: AppTextStyles.body1.copyWith(color: AppColors.danger)),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          key: const Key('txn_save'),
          onPressed: _save,
          child: Text(widget.saveLabel),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('txn_cancel'),
                onPressed: widget.onCancel,
                child: const Text('Bỏ qua'),
              ),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: const Key('txn_delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 2),
                  ),
                  onPressed: widget.onDelete,
                  child: const Text('Xóa'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
