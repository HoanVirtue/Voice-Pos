import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../data/settlement_model.dart';
import '../data/settlement_repository.dart';

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(
    ref.read(databaseProvider),
    onLocalChange: () => ref.read(syncServiceProvider).syncNow(),
  );
});

final settlementsProvider = StreamProvider.autoDispose<List<DaySettlement>>(
  (ref) => ref.watch(settlementRepositoryProvider).watchAll(),
);
