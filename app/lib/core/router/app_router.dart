import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/account_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/counter/counter_screen.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/batches/presentation/batches_screen.dart';
import '../../features/debts/presentation/debt_detail_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/ledger/presentation/ledger_screen.dart';
import '../../features/market_cash/presentation/market_cash_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/settlements/presentation/settlement_screen.dart';
import '../widgets/main_shell.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Redirect theo auth: chua dang nhap -> /login; da dang nhap ma o /login -> /counter.
/// Trong luc chua khoi phuc phien xong thi giu nguyen (app hien man cho).
String? appRedirect(AuthState auth, String location) {
  if (!auth.initialized) return null;
  final onLogin = location == AppRoutes.login;
  if (!auth.isAuthenticated) return onLogin ? null : AppRoutes.login;
  if (onLogin) return AppRoutes.counter;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.counter,
    refreshListenable: refresh,
    redirect: (context, state) =>
        appRedirect(ref.read(authStateProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.counter, builder: (_, __) => const CounterScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.ledger, builder: (_, __) => const LedgerScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.debts, builder: (_, __) => const DebtsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.settlement, builder: (_, __) => const SettlementScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.more, builder: (_, __) => const MoreScreen()),
          ]),
        ],
      ),
      // Cac man hinh toan man hinh, nam ngoai thanh dieu huong (co nut quay lai).
      GoRoute(
        path: AppRoutes.customers,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CustomerListScreen(),
      ),
      GoRoute(
        path: AppRoutes.products,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ProductsScreen(),
      ),
      GoRoute(
        path: AppRoutes.batches,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BatchesScreen(),
      ),
      GoRoute(
        path: AppRoutes.marketCash,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const MarketCashScreen(),
      ),
      GoRoute(
        path: AppRoutes.account,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: '/debts/:customerId',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => DebtDetailScreen(customerId: state.pathParameters['customerId']!),
      ),
      // Form toan man hinh, nam ngoai thanh dieu huong.
      GoRoute(
        path: AppRoutes.customerNew,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            CustomerFormScreen(customerId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
