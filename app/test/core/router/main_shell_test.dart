import 'package:banhang_app/core/router/app_routes.dart';
import 'package:banhang_app/core/sync/sync_providers.dart';
import 'package:banhang_app/core/sync/sync_service.dart';
import 'package:banhang_app/core/widgets/main_shell.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:banhang_app/core/local_db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_harness.dart';

Widget _page(String title) => Scaffold(body: Center(child: Text(title)));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('thanh dieu huong 5 muc: Quay, So, No, Chot so, Khac', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final router = GoRouter(
      initialLocation: AppRoutes.counter,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => MainShell(navigationShell: shell),
          branches: [
            for (final (path, title) in [
              (AppRoutes.counter, 'Trang quầy'),
              (AppRoutes.ledger, 'Trang sổ'),
              (AppRoutes.debts, 'Trang nợ'),
              (AppRoutes.settlement, 'Trang chốt sổ'),
              (AppRoutes.more, 'Trang khác'),
            ])
              StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, __) => _page(title))]),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWith((ref) {
          final s = SyncService(db: db, remote: NoopCustomerRemote(), isOnline: () async => false);
          ref.onDispose(s.dispose);
          return s;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    for (final label in ['Quầy', 'Sổ', 'Nợ', 'Chốt sổ', 'Khác']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget,
          reason: label);
    }
    expect(find.text('Trang quầy'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Nợ')));
    await tester.pumpAndSettle();
    expect(find.text('Trang nợ'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chốt sổ')));
    await tester.pumpAndSettle();
    expect(find.text('Trang chốt sổ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  test('AppRoutes: duong dan khop router', () {
    expect(AppRoutes.debtDetail('abc'), '/debts/abc');
    expect(AppRoutes.customerEdit('x'), '/customers/x');
    expect(AppRoutes.customerNew, '/customers/new');
  });
}
