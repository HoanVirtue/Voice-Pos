import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  runApp(const ProviderScope(child: BanHangApp()));
}

class BanHangApp extends ConsumerStatefulWidget {
  const BanHangApp({super.key});

  @override
  ConsumerState<BanHangApp> createState() => _BanHangAppState();
}

class _BanHangAppState extends ConsumerState<BanHangApp> {
  @override
  void initState() {
    super.initState();
    // Khoi phuc phien tu kho an toan.
    Future.microtask(() => ref.read(authStateProvider.notifier).checkAuth());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final initialized = ref.watch(authStateProvider.select((s) => s.initialized));

    return MaterialApp.router(
      title: 'Bán hàng',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => initialized
          ? (child ?? const SizedBox.shrink())
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
