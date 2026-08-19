import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/models/user_model.dart';
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

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required String operatingState,
    required String operatingCity,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentUser = state.user;
      final client = Supabase.instance.client;

      if (currentUser != null) {
        // 1. Update users table in Supabase
        await client.from('users').update({
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phone,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentUser.id);

        // 2. Update delivery_agents table in Supabase
        final agentId = currentUser.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
        try {
          await client.from('delivery_agents').update({
            'operating_state': operatingState,
            'operating_city': operatingCity,
            'vehicle_type': vehicleType,
            'vehicle_plate_number': vehiclePlateNumber,
            'bank_name': bankName,
            'bank_account_number': bankAccountNumber,
            'bank_account_name': bankAccountName,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', agentId);
        } catch (_) {}

        // 3. Update local state
        final updatedUser = UserModel(
          id: currentUser.id,
          authUserId: currentUser.authUserId,
          email: currentUser.email,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          role: currentUser.role,
          companyId: currentUser.companyId,
          deliveryAgentId: currentUser.deliveryAgentId,
          deliveryAgentCode: currentUser.deliveryAgentCode,
          distributionCenterName: currentUser.distributionCenterName,
          lifetimeDeliveriesCount: currentUser.lifetimeDeliveriesCount,
          rating: currentUser.rating,
          personnelType: currentUser.personnelType,
          compensationType: currentUser.compensationType,
          commissionRate: currentUser.commissionRate,
          transportAllowance: currentUser.transportAllowance,
          fuelAllowance: currentUser.fuelAllowance,
          baseSalary: currentUser.baseSalary,
          vehicleType: vehicleType,
          vehiclePlateNumber: vehiclePlateNumber,
          operatingState: operatingState,
          operatingCity: operatingCity,
          bankName: bankName,
          bankAccountNumber: bankAccountNumber,
          bankAccountName: bankAccountName,
          agentStatus: currentUser.agentStatus,
          avatarUrl: avatarUrl ?? currentUser.avatarUrl,
        );

        state = state.copyWith(isLoading: false, user: updatedUser);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
  );
});
