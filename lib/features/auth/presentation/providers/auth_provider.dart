import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(Supabase.instance.client);
});

final authRepositoryProvider = Provider((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final loginUseCaseProvider = Provider((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserEntity? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
  }) : super(const AuthState()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    debugPrint('[AUTH_PROVIDER] 🔍 checkCurrentUser() initiated...');
    state = state.copyWith(isLoading: true);
    try {
      final user = await getCurrentUserUseCase.execute();
      if (user != null) {
        debugPrint('[AUTH_PROVIDER] 👤 Current active session found: ${user.email} (Agent: ${user.firstName} ${user.lastName}, Role: ${user.role})');
      } else {
        debugPrint('[AUTH_PROVIDER] ℹ️ No active user session found.');
      }
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] ⚠️ checkCurrentUser() error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    debugPrint('[AUTH_PROVIDER] 🔐 login() initiated with email: "$email"');
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await loginUseCase.execute(email, password);
      debugPrint('[AUTH_PROVIDER] ✅ login() SUCCESS -> User: "${user.email}", Name: "${user.firstName} ${user.lastName}", AgentId: "${user.deliveryAgentId}"');
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] ❌ login() FAILED -> Error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    debugPrint('[AUTH_PROVIDER] 🚪 logout() initiated...');
    state = state.copyWith(isLoading: true);
    try {
      await logoutUseCase.execute();
      debugPrint('[AUTH_PROVIDER] 👋 User session successfully signed out.');
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] ⚠️ logout error: $e');
    }
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
  );
});
