import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.read(databaseProvider),
    onLocalChange: () => ref.read(syncServiceProvider).syncNow(),
  );
});

/// Moi giao dich chua xoa (cong no, bao cao).
final allTransactionsProvider = StreamProvider.autoDispose<List<TransactionRecord>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

/// Giao dich cua mot ngay VN (`yyyy-MM-dd`).
final dayTransactionsProvider =
    StreamProvider.autoDispose.family<List<TransactionRecord>, String>(
  (ref, date) => ref.watch(transactionRepositoryProvider).watchDay(date),
);
