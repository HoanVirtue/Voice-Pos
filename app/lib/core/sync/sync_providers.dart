import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/customers/data/customer_remote.dart';
import '../local_db/app_database.dart';
import 'sync_service.dart';
import 'syncers.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final customerRemoteProvider = Provider<CustomerRemote>((ref) {
  return CustomerApiService(dio: ref.read(dioProvider));
});

/// Song cung man hinh chinh (MainShell watch no). Tat khi dang xuat.
final syncServiceProvider = Provider.autoDispose<SyncService>((ref) {
  final service = SyncService(
    db: ref.read(databaseProvider),
    remote: ref.read(customerRemoteProvider),
    syncers: buildSyncers(ref.read(dioProvider)),
    connectivity: Connectivity(),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider.autoDispose<SyncStatus>((ref) async* {
  final service = ref.watch(syncServiceProvider);
  yield service.status;
  yield* service.statusStream;
});
