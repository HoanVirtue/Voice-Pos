import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../data/customer_model.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    ref.read(databaseProvider),
    // Ghi local xong thi day outbox ngay (neu co mang).
    onLocalChange: () => ref.read(syncServiceProvider).syncNow(),
  );
});

final customerSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final customersProvider = StreamProvider.autoDispose<List<Customer>>((ref) {
  final query = ref.watch(customerSearchProvider);
  return ref.watch(customerRepositoryProvider).watchAll(query: query);
});

final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(customerRepositoryProvider).watchPendingCount();
});
