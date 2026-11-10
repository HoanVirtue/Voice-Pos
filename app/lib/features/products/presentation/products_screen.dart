import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/money_field.dart';
import '../data/product_model.dart';
import '../providers/product_providers.dart';

/// Quan ly mon hang (ba chi, nac vai...) va gia/kg.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = hasPerm(ref, Perm.transactionsView);
    final canManage = hasPerm(ref, Perm.transactionsManage);
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Món hàng')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: const Key('product_add'),
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add, size: 30),
              label: const Text('Thêm món', style: AppTextStyles.button),
            )
          : null,
      body: !canView
          ? const NoPermissionView()
          : products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e', style: AppTextStyles.body1)),
              data: (list) => list.isEmpty
                  ? const EmptyView(message: 'Chưa có món hàng. Thêm ba chỉ, nạc vai, sườn...')
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return ListTile(
                          key: Key('product_${p.id}'),
                          title: Text(p.name),
                          subtitle: p.alias == null ? null : Text('Còn gọi: ${p.alias}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${formatMoney(p.pricePerKg)}/kg', style: AppTextStyles.body1SemiBold),
                              if (canManage)
                                IconButton(
                                  tooltip: 'Xóa',
                                  icon: const Icon(Icons.delete_outline, size: 28, color: AppColors.danger),
                                  onPressed: () => _delete(context, ref, p),
                                ),
                            ],
                          ),
                          onTap: canManage ? () => _edit(context, ref, p) : null,
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Product p) async {
    final ok = await confirmDialog(context, title: 'Xóa ${p.name}?',
        message: 'Món sẽ được ẩn khỏi danh sách. Các giao dịch cũ vẫn giữ nguyên.');
    if (ok) await ref.read(productRepositoryProvider).softDelete(p.id);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Product? p) async {
    final result = await showDialog<_ProductForm>(
      context: context,
      builder: (_) => _ProductDialog(product: p),
    );
    if (result == null) return;
    final repo = ref.read(productRepositoryProvider);
    if (p == null) {
      await repo.create(name: result.name, alias: result.alias, pricePerKg: result.price);
    } else {
      await repo.update(Product(
        id: p.id,
        name: result.name,
        alias: result.alias,
        pricePerKg: result.price,
        updatedAt: p.updatedAt,
      ));
    }
  }
}

class _ProductForm {
  final String name;
  final String? alias;
  final int price;
  const _ProductForm(this.name, this.alias, this.price);
}

class _ProductDialog extends StatefulWidget {
  final Product? product;

  const _ProductDialog({this.product});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _alias = TextEditingController(text: widget.product?.alias ?? '');
  late final _price = TextEditingController(
      text: widget.product == null ? '' : moneyToInputText(widget.product!.pricePerKg));
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    _price.dispose();
    super.dispose();
  }

  void _ok() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên món');
      return;
    }
    Navigator.pop(context, _ProductForm(name, _alias.text.trim().isEmpty ? null : _alias.text.trim(),
        parseMoneyInput(_price.text) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Thêm món' : 'Sửa món'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('product_name'),
              controller: _name,
              style: AppTextStyles.body1,
              decoration: InputDecoration(labelText: 'Tên món', errorText: _error),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('product_alias'),
              controller: _alias,
              style: AppTextStyles.body1,
              decoration: const InputDecoration(labelText: 'Tên gọi khác (vd: ba rọi)'),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('product_price'),
              child: MoneyField(controller: _price, label: 'Giá một kg'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: AppTextStyles.body1),
        ),
        TextButton(
          key: const Key('product_ok'),
          onPressed: _ok,
          child: const Text('Lưu', style: AppTextStyles.body1SemiBold),
        ),
      ],
    );
  }
}
