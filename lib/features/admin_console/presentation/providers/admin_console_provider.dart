import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../domain/entities/admin_models.dart';

@immutable
class AdminConsoleState {
  final int activeTab;
  final String searchQuery;
  final String roleFilter;
  final String statusFilter;
  final String hubFilter;
  final String auditLogActionFilter;
  final String auditLogRoleFilter;
  final String auditLogHubFilter;
  final String auditLogDateFilter;
  final List<AdminUserItem> users;
  final List<AdminDistributionCenter> distributionCenters;
  final List<AdminMerchant> merchants;
  final AdminAppSettings appSettings;
  final AdminServerSettings serverSettings;
  final List<AdminRoutingTariff> routingTariffs;
  final List<AdminAuditLog> auditLogs;
  final bool isLoading;
  final bool isSaving;
  final String? statusMessage;
  final DateTime? lastSyncedAt;

  const AdminConsoleState({
    this.activeTab = 0,
    this.searchQuery = '',
    this.roleFilter = 'all',
    this.statusFilter = 'all',
    this.hubFilter = 'all',
    this.auditLogActionFilter = 'all',
    this.auditLogRoleFilter = 'all',
    this.auditLogHubFilter = 'all',
    this.auditLogDateFilter = 'all',
    this.users = const [],
    this.distributionCenters = const [],
    this.merchants = const [],
    this.appSettings = const AdminAppSettings(),
    this.serverSettings = const AdminServerSettings(),
    this.routingTariffs = const [],
    this.auditLogs = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.statusMessage,
    this.lastSyncedAt,
  });

  AdminConsoleState copyWith({
    int? activeTab,
    String? searchQuery,
    String? roleFilter,
    String? statusFilter,
    String? hubFilter,
    String? auditLogActionFilter,
    String? auditLogRoleFilter,
    String? auditLogHubFilter,
    String? auditLogDateFilter,
    List<AdminUserItem>? users,
    List<AdminDistributionCenter>? distributionCenters,
    List<AdminMerchant>? merchants,
    AdminAppSettings? appSettings,
    AdminServerSettings? serverSettings,
    List<AdminRoutingTariff>? routingTariffs,
    List<AdminAuditLog>? auditLogs,
    bool? isLoading,
    bool? isSaving,
    String? statusMessage,
    DateTime? lastSyncedAt,
  }) {
    return AdminConsoleState(
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      hubFilter: hubFilter ?? this.hubFilter,
      auditLogActionFilter: auditLogActionFilter ?? this.auditLogActionFilter,
      auditLogRoleFilter: auditLogRoleFilter ?? this.auditLogRoleFilter,
      auditLogHubFilter: auditLogHubFilter ?? this.auditLogHubFilter,
      auditLogDateFilter: auditLogDateFilter ?? this.auditLogDateFilter,
      users: users ?? this.users,
      distributionCenters: distributionCenters ?? this.distributionCenters,
      merchants: merchants ?? this.merchants,
      appSettings: appSettings ?? this.appSettings,
      serverSettings: serverSettings ?? this.serverSettings,
      routingTariffs: routingTariffs ?? this.routingTariffs,
      auditLogs: auditLogs ?? this.auditLogs,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      statusMessage: statusMessage ?? this.statusMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  // Filtered lists
  List<AdminUserItem> get filteredUsers {
    return users.where((u) {
      if (roleFilter != 'all' && u.role.toLowerCase() != roleFilter.toLowerCase()) {
        return false;
      }
      if (statusFilter != 'all' && u.status.toLowerCase() != statusFilter.toLowerCase()) {
        return false;
      }
      if (hubFilter != 'all' && u.distributionCenterId != hubFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesName = u.fullName.toLowerCase().contains(q);
        final matchesEmail = u.email.toLowerCase().contains(q);
        final matchesPhone = u.phone.toLowerCase().contains(q);
        final matchesCode = (u.deliveryAgentCode ?? '').toLowerCase().contains(q) ||
            (u.closerCode ?? '').toLowerCase().contains(q);
        return matchesName || matchesEmail || matchesPhone || matchesCode;
      }
      return true;
    }).toList();
  }

  List<AdminDistributionCenter> get filteredDistributionCenters {
    return distributionCenters.where((dc) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return dc.name.toLowerCase().contains(q) ||
            dc.code.toLowerCase().contains(q) ||
            dc.city.toLowerCase().contains(q) ||
            dc.state.toLowerCase().contains(q) ||
            dc.supervisorName.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<AdminMerchant> get filteredMerchants {
    return merchants.where((m) {
      if (statusFilter != 'all' && m.status.toLowerCase() != statusFilter.toLowerCase()) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return m.businessName.toLowerCase().contains(q) ||
            m.contactName.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.phone.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<AdminRoutingTariff> get filteredTariffs {
    return routingTariffs.where((t) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return t.stateName.toLowerCase().contains(q) ||
            t.assignedHubName.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<AdminAuditLog> get filteredAuditLogs {
    return auditLogs.where((log) {
      // Role filter
      if (auditLogRoleFilter != 'all') {
        final r = log.actorRole.toLowerCase();
        final target = auditLogRoleFilter.toLowerCase();
        if (target == 'dc_manager') {
          if (!r.contains('dc_manager') && !r.contains('dc_admin') && !r.contains('supervisor')) {
            return false;
          }
        } else if (!r.contains(target)) {
          return false;
        }
      }

      // Action Category filter
      if (auditLogActionFilter != 'all') {
        final act = log.action.toUpperCase();
        if (auditLogActionFilter == 'users') {
          if (!act.contains('USER') && !act.contains('ADMIN') && !act.contains('ONBOARD')) return false;
        } else if (auditLogActionFilter == 'finance') {
          if (!act.contains('REMIT') && !act.contains('EXPENSE') && !act.contains('EXPENDITURE') && !act.contains('PAYOUT') && !act.contains('SETTLEMENT')) return false;
        } else if (auditLogActionFilter == 'orders') {
          if (!act.contains('ORDER') && !act.contains('DISPATCH') && !act.contains('ROUTE') && !act.contains('ASSIGN')) return false;
        } else if (auditLogActionFilter == 'stock') {
          if (!act.contains('STOCK') && !act.contains('TRANSFER') && !act.contains('INVENTORY')) return false;
        } else if (auditLogActionFilter == 'policy') {
          if (!act.contains('POLICY') && !act.contains('TARIFF') && !act.contains('SETTINGS') && !act.contains('CREDENTIALS')) return false;
        } else if (!act.contains(auditLogActionFilter.toUpperCase())) {
          return false;
        }
      }

      // Hub Filter
      if (auditLogHubFilter != 'all') {
        final matchesHubId = log.distributionCenterId == auditLogHubFilter;
        final matchesHubName = (log.distributionCenterName ?? '').toLowerCase().contains(auditLogHubFilter.toLowerCase());
        if (!matchesHubId && !matchesHubName) return false;
      }

      // Date Filter
      if (auditLogDateFilter != 'all') {
        final now = DateTime.now();
        if (auditLogDateFilter == 'today') {
          final isToday = log.timestamp.year == now.year &&
              log.timestamp.month == now.month &&
              log.timestamp.day == now.day;
          if (!isToday) return false;
        } else if (auditLogDateFilter == 'week') {
          if (now.difference(log.timestamp).inDays > 7) return false;
        } else if (auditLogDateFilter == 'month') {
          if (now.difference(log.timestamp).inDays > 30) return false;
        }
      }

      // Search Query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchActor = log.actorName.toLowerCase().contains(q) ||
            log.actorEmail.toLowerCase().contains(q) ||
            log.actorRole.toLowerCase().contains(q);
        final matchAction = log.action.toLowerCase().contains(q);
        final matchResource = log.resource.toLowerCase().contains(q);
        final matchDetails = log.details.toLowerCase().contains(q);
        final matchDc = (log.distributionCenterName ?? '').toLowerCase().contains(q);
        final matchIp = log.ipAddress.toLowerCase().contains(q);

        return matchActor || matchAction || matchResource || matchDetails || matchDc || matchIp;
      }

      return true;
    }).toList();
  }
}

class AdminConsoleNotifier extends StateNotifier<AdminConsoleState> {
  final AdminRemoteDataSource _dataSource;

  AdminConsoleNotifier(this._dataSource) : super(const AdminConsoleState()) {
    loadAll();
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index, searchQuery: '');
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setRoleFilter(String role) {
    state = state.copyWith(roleFilter: role);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  void setHubFilter(String hubId) {
    state = state.copyWith(hubFilter: hubId);
  }

  void setAuditLogRoleFilter(String role) {
    state = state.copyWith(auditLogRoleFilter: role);
  }

  void setAuditLogActionFilter(String action) {
    state = state.copyWith(auditLogActionFilter: action);
  }

  void setAuditLogHubFilter(String hub) {
    state = state.copyWith(auditLogHubFilter: hub);
  }

  void setAuditLogDateFilter(String date) {
    state = state.copyWith(auditLogDateFilter: date);
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final usersFuture = _dataSource.fetchUsers();
      final dcsFuture = _dataSource.fetchDistributionCenters();
      final merchantsFuture = _dataSource.fetchMerchants();
      final auditLogsFuture = _dataSource.fetchAuditLogs();
      final pingFuture = _dataSource.pingDatabase();

      final users = await usersFuture;
      final dcs = await dcsFuture;
      final merchants = await merchantsFuture;
      final auditLogs = await auditLogsFuture;
      final pingMs = await pingFuture;

      state = state.copyWith(
        users: users,
        distributionCenters: dcs,
        merchants: merchants,
        routingTariffs: AdminRemoteDataSource.defaultRoutingTariffs,
        auditLogs: auditLogs,
        serverSettings: state.serverSettings.copyWith(
          lastPingMs: pingMs,
          isDbHealthy: true,
          lastSyncTime: DateTime.now(),
        ),
        isLoading: false,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AdminConsoleNotifier] loadAll error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleUserStatus(String userId) async {
    final userIndex = state.users.indexWhere((u) => u.id == userId);
    if (userIndex == -1) return;

    final currentUser = state.users[userIndex];
    final newStatus = currentUser.status == 'active' ? 'suspended' : 'active';

    final updatedList = List<AdminUserItem>.from(state.users);
    updatedList[userIndex] = currentUser.copyWith(status: newStatus);

    state = state.copyWith(users: updatedList);
    _logAudit(
      action: newStatus == 'active' ? 'ACTIVATE_USER' : 'SUSPEND_USER',
      resource: 'Users',
      details: '${currentUser.fullName} (${currentUser.role}) set to $newStatus',
    );

    await _dataSource.updateUserStatus(userId, newStatus);
  }

  Future<void> saveUser(AdminUserItem user) async {
    final existingIndex = state.users.indexWhere((u) => u.id == user.id);
    final updatedList = List<AdminUserItem>.from(state.users);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = user;
      _logAudit(
        action: 'UPDATE_USER',
        resource: 'Users',
        details: 'Updated role/details for ${user.fullName} (${user.role})',
      );
    } else {
      updatedList.insert(0, user);
      _logAudit(
        action: 'CREATE_USER',
        resource: 'Users',
        details: 'Onboarded user ${user.fullName} with role ${user.role}',
      );
    }

    state = state.copyWith(users: updatedList);
    await _dataSource.updateUserRoleAndHub(
      user.id,
      user.role,
      user.distributionCenterId,
      user.distributionCenterName,
    );
  }

  void saveDistributionCenter(AdminDistributionCenter dc) {
    final existingIndex = state.distributionCenters.indexWhere((d) => d.id == dc.id);
    final updatedList = List<AdminDistributionCenter>.from(state.distributionCenters);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = dc;
      _logAudit(
        action: 'UPDATE_HUB',
        resource: 'DistributionCenters',
        details: 'Updated Hub settings for ${dc.name} (${dc.code})',
      );
    } else {
      updatedList.add(dc);
      _logAudit(
        action: 'CREATE_HUB',
        resource: 'DistributionCenters',
        details: 'Commissioned new Hub ${dc.name} in ${dc.state}',
      );
    }

    state = state.copyWith(distributionCenters: updatedList);
  }

  void saveMerchant(AdminMerchant merchant) {
    final existingIndex = state.merchants.indexWhere((m) => m.id == merchant.id);
    final updatedList = List<AdminMerchant>.from(state.merchants);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = merchant;
      _logAudit(
        action: 'UPDATE_MERCHANT',
        resource: 'Merchants',
        details: 'Modified settings for ${merchant.businessName}',
      );
    } else {
      updatedList.insert(0, merchant);
      _logAudit(
        action: 'ONBOARD_MERCHANT',
        resource: 'Merchants',
        details: 'Onboarded merchant ${merchant.businessName} (Tier: ${merchant.tier})',
      );
    }

    state = state.copyWith(merchants: updatedList);
  }

  void updateAppSettings(AdminAppSettings newSettings) {
    state = state.copyWith(appSettings: newSettings);
    _logAudit(
      action: 'UPDATE_POLICY',
      resource: 'AppSettings',
      details: 'Updated dispatch & proof-of-delivery enforcement policies.',
    );
  }

  void updateServerSettings(AdminServerSettings newSettings) {
    state = state.copyWith(serverSettings: newSettings);
    _logAudit(
      action: 'UPDATE_CREDENTIALS',
      resource: 'ServerSettings',
      details: 'Rotated server gateway keys or webhook configurations.',
    );
  }

  void updateRoutingTariff(AdminRoutingTariff tariff) {
    final existingIndex = state.routingTariffs.indexWhere((t) => t.stateName == tariff.stateName);
    final updatedList = List<AdminRoutingTariff>.from(state.routingTariffs);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = tariff;
      _logAudit(
        action: 'UPDATE_TARIFF',
        resource: 'RoutingTariff',
        details: 'Updated rate card and rider commission for ${tariff.stateName}',
      );
      state = state.copyWith(routingTariffs: updatedList);
    }
  }

  Future<void> pingServer() async {
    final ping = await _dataSource.pingDatabase();
    state = state.copyWith(
      serverSettings: state.serverSettings.copyWith(
        lastPingMs: ping,
        isDbHealthy: true,
        lastSyncTime: DateTime.now(),
      ),
    );
  }

  void _logAudit({
    required String action,
    required String resource,
    required String details,
    String? actorName,
    String? actorEmail,
    String? actorRole,
    String? distributionCenterId,
    String? distributionCenterName,
  }) {
    final newLog = AdminAuditLog(
      id: 'LOG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      timestamp: DateTime.now(),
      actorName: actorName ?? 'Super Admin',
      actorEmail: actorEmail ?? 'emeraldcodelines@gmail.com',
      actorRole: actorRole ?? 'super_admin',
      action: action,
      resource: resource,
      details: details,
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
    );
    state = state.copyWith(
      auditLogs: [newLog, ...state.auditLogs],
    );
    _dataSource.recordAuditLog(newLog);
  }
}

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSource();
});

final adminConsoleProvider =
    StateNotifierProvider<AdminConsoleNotifier, AdminConsoleState>((ref) {
  final dataSource = ref.watch(adminRemoteDataSourceProvider);
  return AdminConsoleNotifier(dataSource);
});
