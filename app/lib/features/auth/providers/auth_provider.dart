import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/app_session_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/datasources/auth_api_service.dart';
import '../data/models/auth_models.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

// Bus tin hieu "phien het han" giua AuthInterceptor va AuthNotifier. Dung stream
// de hai provider khong phu thuoc vong tron.
final sessionExpiredStreamProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.read(secureStorageProvider);
  final expiredController = ref.read(sessionExpiredStreamProvider);
  return DioClient(
    storage: storage,
    onSessionExpired: () => expiredController.add(null),
    onTokenRefreshed: () => ref.read(authRevisionProvider.notifier).state++,
  );
});

final dioProvider = Provider((ref) => ref.read(dioClientProvider).dio);

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(dio: ref.read(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiService: ref.read(authApiServiceProvider),
    storage: ref.read(secureStorageProvider),
  );
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  /// Da thu khoi phuc phien luc mo app xong chua (de router khong nhay /login).
  final bool initialized;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.initialized = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    bool? initialized,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      initialized: initialized ?? this.initialized,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier({required AuthRepository repository, required Ref ref})
      : _repository = repository,
        _ref = ref,
        super(const AuthState());

  /// Khoi phuc phien tu kho an toan.
  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.getStoredUser();
      if (user != null) {
        _bumpAuthRevision();
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          initialized: true,
        );
        return;
      }
    } catch (_) {
      // Roi xuong: ve man dang nhap.
    }
    state = state.copyWith(isLoading: false, initialized: true);
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.login(
        LoginRequest(username: username, password: password),
        rememberMe: rememberMe,
      );
      _ref.read(appSessionProvider.notifier).update((s) => s + 1);
      _bumpAuthRevision();
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        initialized: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    _bumpAuthRevision();
    _ref.read(appSessionProvider.notifier).update((s) => s + 1);
    state = const AuthState(initialized: true);
  }

  /// Interceptor goi khi refresh token het han: storage da bi xoa, chi can dat
  /// lai state de GoRouter chuyen ve /login.
  void forceLogout() {
    _repository.clearStoredSession();
    _bumpAuthRevision();
    state = const AuthState(initialized: true);
  }

  void _bumpAuthRevision() {
    _ref.read(authRevisionProvider.notifier).state++;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    repository: ref.read(authRepositoryProvider),
    ref: ref,
  );
  final sub = ref.read(sessionExpiredStreamProvider).stream
      .listen((_) => notifier.forceLogout());
  ref.onDispose(sub.cancel);
  return notifier;
});
