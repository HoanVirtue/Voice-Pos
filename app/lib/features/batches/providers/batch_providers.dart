import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../data/batch_model.dart';
import '../data/batch_repository.dart';

final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return BatchRepository(
    ref.read(databaseProvider),
    onLocalChange: () => ref.read(syncServiceProvider).syncNow(),
  );
});

final batchesProvider = StreamProvider.autoDispose<List<PigBatch>>(
  (ref) => ref.watch(batchRepositoryProvider).watchAll(),
);
