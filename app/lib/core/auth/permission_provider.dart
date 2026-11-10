import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import 'permissions.dart';

/// Tang moi khi access token tren may doi (dang nhap, dang xuat, gia han ngam):
/// quyen doc lai tu server.
final authRevisionProvider = StateProvider<int>((ref) => 0);

/// Quyen hieu luc lay tu `GET /api/v1/Permission/Mine` (BE tinh lai tu DB).
/// Loi (mat mang...) thi suy tu `role` cua user da dang nhap.
final myPermissionsProvider = FutureProvider<PermissionSet?>((ref) async {
  ref.watch(authRevisionProvider);
  final isAuthed = ref.watch(authStateProvider.select((s) => s.isAuthenticated));
  if (!isAuthed) return null;

  final role = ref.read(authStateProvider).user?.role;
  try {
    final response = await ref.read(dioProvider).get(AppConstants.myPermissionsEndpoint);
    return unwrapResult<PermissionSet>(
      response,
      (r) => PermissionSet.fromMine(r as Map<String, dynamic>),
    );
  } catch (_) {
    return PermissionSet.fromRole(role);
  }
});

/// Quyen hien tai. Trong luc cho server thi tam suy tu role (server van chan that).
final permissionsProvider = Provider<PermissionSet>((ref) {
  final role = ref.watch(authStateProvider.select((s) => s.user?.role));
  return ref.watch(myPermissionsProvider).maybeWhen(
        data: (p) => p ?? PermissionSet.empty,
        orElse: () => PermissionSet.fromRole(role),
      );
});

bool hasPerm(WidgetRef ref, String code) =>
    ref.watch(permissionsProvider).has(code);
