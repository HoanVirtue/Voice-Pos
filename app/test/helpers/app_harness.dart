import 'dart:async';

import 'package:banhang_app/core/auth/permission_provider.dart';
import 'package:banhang_app/core/auth/permissions.dart';
import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:banhang_app/core/sync/sync_providers.dart';
import 'package:banhang_app/core/sync/sync_service.dart';
import 'package:banhang_app/core/theme/app_theme.dart';
import 'package:banhang_app/features/customers/data/customer_model.dart';
import 'package:banhang_app/features/customers/data/customer_remote.dart';
import 'package:banhang_app/modules/voice/providers/voice_input_provider.dart';
import 'package:banhang_app/modules/voice/services/bluetooth_button_service.dart';
import 'package:banhang_app/modules/voice/services/stt_service.dart';
import 'package:banhang_app/modules/voice/services/tts_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStt implements SttService {
  final ctrl = StreamController<SttMessage>.broadcast();

  @override
  Stream<SttMessage> get messages => ctrl.stream;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> connect() async {}
  @override
  Future<void> start({String? recordToPath}) async => ctrl.add(const SttReady());
  @override
  Future<String?> stop() async => null;
  @override
  void dispose() => ctrl.close();
}

class FakeTts implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class NoopCustomerRemote implements CustomerRemote {
  @override
  Future<void> create(Customer customer) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<CustomerPage> list({DateTime? updatedSince, required int page, required int pageSize}) async =>
      const CustomerPage(items: [], hasMore: false);
  @override
  Future<void> update(Customer customer) async {}
}

/// Bao man hinh trong ProviderScope co DB in-memory, quyen day du, khong mang, TTS/STT gia.
Widget appHarness({
  required AppDatabase db,
  required Widget child,
  FakeTts? tts,
  PermissionSet? permissions,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      syncServiceProvider.overrideWith((ref) {
        final s = SyncService(db: db, remote: NoopCustomerRemote(), isOnline: () async => false);
        ref.onDispose(s.dispose);
        return s;
      }),
      permissionsProvider.overrideWithValue(permissions ?? PermissionSet(Perm.all.toSet())),
      ttsServiceProvider.overrideWith((ref) => tts ?? FakeTts()),
      voiceInputProvider.overrideWith((ref) => VoiceInputNotifier(FakeStt())),
      bluetoothButtonProvider.overrideWith((ref) => BluetoothButtonService()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

// ─── Tien ich test man hinh ──────────────────────────────────────────────────

/// Thao tac drift chay nua trong vung gia (do UI goi) nua ngoai: xen ke cho that va tien thoi gian gia.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// TextField ben trong widget gan [key] (cac o nhap tien boc MoneyField trong KeyedSubtree).
Finder fieldIn(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

/// Bam nut o man cuon duoc (goi thang onPressed, tranh nut nam ngoai khung hinh test).
Future<void> pressKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  final w = tester.widget(f);
  if (w is ElevatedButton) {
    w.onPressed!();
  } else if (w is OutlinedButton) {
    w.onPressed!();
  } else if (w is TextButton) {
    w.onPressed!();
  } else {
    await tester.tap(f);
  }
  await tester.pump();
}

/// Test man hinh voi DB in-memory moi: man hinh cao de thay het noi dung, don timer cua drift/snackbar khi xong.
void appTest(String name, Future<void> Function(WidgetTester tester, AppDatabase db) body) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  testWidgets(name, (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.binding.setSurfaceSize(const Size(900, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await body(tester, db);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    // Khong db.close(): DB in-memory, dong trong vung gia co the treo.
  });
}
