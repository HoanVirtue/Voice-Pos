import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/customer_model.dart';
import '../providers/customer_providers.dart';

/// Form tao/sua khach. [customerId] == null: tao moi.
class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _alias = TextEditingController();
  final _note = TextEditingController();

  Customer? _existing;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await ref.read(customerRepositoryProvider).getById(widget.customerId!);
    if (!mounted) return;
    if (c != null) {
      _existing = c;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _alias.text = c.alias ?? '';
      _note.text = c.note ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _alias.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(customerRepositoryProvider);
    if (_existing != null) {
      await repo.update(_existing!.copyWith(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        alias: _alias.text.trim(),
        note: _note.text.trim(),
      ));
    } else {
      await repo.create(
        name: _name.text,
        phone: _phone.text,
        alias: _alias.text,
        note: _note.text,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      key: const Key('customer_name'),
                      controller: _name,
                      label: 'Tên khách',
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.required(v, label: 'Tên khách'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      key: const Key('customer_phone'),
                      controller: _phone,
                      label: 'Số điện thoại (không bắt buộc)',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: Validators.optionalPhone,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _alias,
                      label: 'Biệt danh / chỗ ngồi (không bắt buộc)',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _note,
                      label: 'Ghi chú (không bắt buộc)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      key: const Key('customer_save'),
                      label: AppStrings.save,
                      isLoading: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
