import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/data/customer_model.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../products/data/product_model.dart';
import '../../products/providers/product_providers.dart';
import '../parser/market_parser.dart';

/// Danh sach khach (kem no hien tai) cho bo phan tich cau noi.
final parserCustomersProvider = Provider.autoDispose<List<ParserCustomer>>((ref) {
  final customers = ref.watch(allCustomersProvider).valueOrNull ?? const <Customer>[];
  final debts = {for (final d in ref.watch(debtsProvider)) d.customerId: d.debt};
  return [
    for (final c in customers)
      ParserCustomer(id: c.id, name: c.name, alias: c.alias, debt: debts[c.id]),
  ];
});

final parserProductsProvider = Provider.autoDispose<List<ParserProduct>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
  return [
    for (final p in products)
      ParserProduct(id: p.id, name: p.name, alias: p.alias, pricePerKg: p.pricePerKg),
  ];
});
