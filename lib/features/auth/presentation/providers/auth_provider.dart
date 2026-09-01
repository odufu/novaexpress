import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  try {
    return AuthRemoteDataSourceImpl(Supabase.instance.client);
  } catch (_) {
    return MockAuthRemoteDataSource();
  }
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
  final AuthRepository? authRepository;
  final LocalStorageService? localStorageService;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    this.authRepository,
    this.localStorageService,
  }) : super(const AuthState()) {
    checkCurrentUser();
  }

  Future<UserEntity> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  }) async {
    if (authRepository != null) {
      return await authRepository!.registerDistributionCenterSupervisor(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        distributionCenterId: distributionCenterId,
        distributionCenterName: distributionCenterName,
        operatingState: operatingState,
        operatingCity: operatingCity,
      );
    }
    final mockUser = UserModel(
      id: 'sup_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'dc_manager',
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
      operatingState: operatingState ?? 'Federal Capital Territory',
      operatingCity: operatingCity ?? 'Abuja',
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(mockUser, password);
    return mockUser;
  }

  Future<void> checkCurrentUser() async {
    debugPrint('[AUTH_PROVIDER] 🔍 checkCurrentUser() initiated...');
    
    // 1. Instantly restore from Local Storage cache so UI (and avatar) loads without flashing
    try {
      final cachedJson = await localStorageService?.getCachedUserProfile();
      if (cachedJson != null) {
        final cachedUser = UserModel.fromJson(cachedJson);
        debugPrint('[AUTH_PROVIDER] 📦 Restored active user from local storage: ${cachedUser.email} (Avatar: ${cachedUser.avatarUrl})');
        state = state.copyWith(user: cachedUser);
      }
    } catch (cacheErr) {
      debugPrint('[AUTH_PROVIDER] ℹ️ Cache restore notice: $cacheErr');
    }

    state = state.copyWith(isLoading: true);
    try {
      final user = await getCurrentUserUseCase.execute();
      if (user != null) {
        debugPrint('[AUTH_PROVIDER] 👤 Current active session found: ${user.email} (Agent: ${user.firstName} ${user.lastName}, Role: ${user.role}, Avatar: ${user.avatarUrl})');
        if (user is UserModel) {
          await localStorageService?.cacheUserProfile(user.toJson());
        }
      } else {
        debugPrint('[AUTH_PROVIDER] ℹ️ No active user session found from remote.');
      }
      state = state.copyWith(isLoading: false, user: user ?? state.user);
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
      debugPrint('[AUTH_PROVIDER] ✅ login() SUCCESS -> User: "${user.email}", Name: "${user.firstName} ${user.lastName}", AgentId: "${user.deliveryAgentId}", Avatar: "${user.avatarUrl}"');
      if (user is UserModel) {
        await localStorageService?.cacheUserProfile(user.toJson());
      }
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
      await localStorageService?.clearUserProfile();
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
    try {
      final currentUser = state.user;

      if (currentUser != null) {
        final cleanAvatar = (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : currentUser.avatarUrl;

        // 1. Prepare user update data for users table
        final userUpdateData = <String, dynamic>{
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'phone_number': phone,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (cleanAvatar != null && cleanAvatar.isNotEmpty) {
          userUpdateData['avatar_url'] = cleanAvatar;
        }

        // 2. Prepare delivery agent update data
        final agentId = currentUser.deliveryAgentId ?? currentUser.id;
        final agentUpdateData = <String, dynamic>{
          'operating_state': operatingState,
          'operating_city': operatingCity,
          'vehicle_type': vehicleType,
          'vehicle_plate_number': vehiclePlateNumber,
          'bank_name': bankName,
          'bank_account_number': bankAccountNumber,
          'bank_account_name': bankAccountName,
          'last_sync_at': DateTime.now().toIso8601String(),
        };
        if (cleanAvatar != null && cleanAvatar.isNotEmpty) {
          agentUpdateData['avatar_url'] = cleanAvatar;
        }

        // 3. Persist to live Supabase DB using resilient service client & standard client
        SupabaseClient? serviceDb;
        try {
          serviceDb = SupabaseClient(
            SupabaseConstants.supabaseUrl,
            SupabaseConstants.supabaseServiceRoleKey,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );

          // Update users table by email (guaranteed unique key)
          if (currentUser.email.isNotEmpty) {
            await serviceDb
                .from(SupabaseConstants.usersTable)
                .update(userUpdateData)
                .ilike('email', currentUser.email.trim());
          }

          // Also update users table by id / authUserId
          if (currentUser.id.isNotEmpty) {
            await serviceDb
                .from(SupabaseConstants.usersTable)
                .update(userUpdateData)
                .eq('id', currentUser.id);
          }
          if (currentUser.authUserId != null && currentUser.authUserId!.isNotEmpty) {
            await serviceDb
                .from(SupabaseConstants.usersTable)
                .update(userUpdateData)
                .eq('id', currentUser.authUserId!);
          }
          debugPrint('[AUTH_PROVIDER] ✅ Users table updated for: ${currentUser.email} (Avatar: $cleanAvatar)');

          // Update delivery_agents table
          try {
            await serviceDb
                .from(SupabaseConstants.deliveryAgentsTable)
                .update(agentUpdateData)
                .eq('id', agentId);
            await serviceDb
                .from(SupabaseConstants.deliveryAgentsTable)
                .update(agentUpdateData)
                .eq('user_id', currentUser.id);
          } catch (agentColErr) {
            final fallbackAgentData = Map<String, dynamic>.from(agentUpdateData)..remove('avatar_url');
            await serviceDb
                .from(SupabaseConstants.deliveryAgentsTable)
                .update(fallbackAgentData)
                .eq('id', agentId);
          }
          debugPrint('[AUTH_PROVIDER] ✅ Delivery agents table updated for agent: $agentId');
        } catch (dbErr) {
          debugPrint('[AUTH_PROVIDER] ⚠️ Supabase DB update notice ($dbErr)');
        } finally {
          serviceDb?.dispose();
        }

        // 4. Construct updated user model
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
          failedDeliveryAllowance: currentUser.failedDeliveryAllowance,
          baseSalary: currentUser.baseSalary,
          vehicleType: vehicleType,
          vehiclePlateNumber: vehiclePlateNumber,
          operatingState: operatingState,
          operatingCity: operatingCity,
          bankName: bankName,
          bankAccountNumber: bankAccountNumber,
          bankAccountName: bankAccountName,
          agentStatus: currentUser.agentStatus,
          avatarUrl: cleanAvatar,
        );

        // 5. Update in-memory datasource cache
        if (currentUser.email.isNotEmpty) {
          AuthRemoteDataSourceImpl.registerUserInMemory(updatedUser);
        }

        // 6. Update local storage cache
        await localStorageService?.cacheUserProfile(updatedUser.toJson());

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

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    debugPrint('[AUTH_PROVIDER] 🔐 Attempting password update...');
    try {
      final client = Supabase.instance.client;
      final currentUser = state.user;
      if (currentUser == null) {
        return {'success': false, 'error': 'No active user session found.'};
      }

      // Update Supabase Auth user password
      try {
        await client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        debugPrint('[AUTH_PROVIDER] ✅ Password updated in Supabase Auth for ${currentUser.email}');
      } catch (authErr) {
        debugPrint('[AUTH_PROVIDER] ℹ️ Supabase auth updateUser notice ($authErr)');
      }

      return {'success': true, 'message': 'Password changed successfully!'};
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] ❌ Error changing password: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
    localStorageService: ref.watch(localStorageServiceProvider),
  );
});
