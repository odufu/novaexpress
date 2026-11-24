import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/uuid_helper.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/entities/agent_daily_sale_record.dart';
import '../../domain/entities/crm_agents_roster.dart';

@immutable
class AdminConsoleState {
  final int activeTab;
  final String searchQuery;
  final String roleFilter;
  final String statusFilter;
  final String hubFilter;
  final String agentStatusFilter;
  final String auditLogActionFilter;
  final String auditLogRoleFilter;
  final String auditLogHubFilter;
  final String auditLogDateFilter;
  final String expenseWarehouseFilter;
  final String expenseCategoryFilter;
  final String stockMerchantFilter;
  final String stockHubFilter;
  final String stockHealthFilter;
  final String agentMerchantFilter;
  final String agentHubFilter;
  final String merchantTierFilter;
  final String selectedRegion;
  final List<AdminUserItem> users;
  final List<AdminDistributionCenter> distributionCenters;
  final List<AdminMerchant> merchants;
  final List<AdminLogisticsAgent> agents;
  final List<AdminGlobalStockItem> globalStock;
  final List<AdminWarehouseExpense> expenses;
  final List<AdminSettlementReconciliation> settlementReconciliations;
  final AdminAppSettings appSettings;
  final AdminServerSettings serverSettings;
  final List<AdminRoutingTariff> routingTariffs;
  final List<AdminAuditLog> auditLogs;
  final List<AgentDailySaleRecord> dailySales;
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
    this.agentStatusFilter = 'all',
    this.auditLogActionFilter = 'all',
    this.auditLogRoleFilter = 'all',
    this.auditLogHubFilter = 'all',
    this.auditLogDateFilter = 'all',
    this.expenseWarehouseFilter = 'all',
    this.expenseCategoryFilter = 'all',
    this.stockMerchantFilter = 'all',
    this.stockHubFilter = 'all',
    this.stockHealthFilter = 'all',
    this.agentMerchantFilter = 'all',
    this.agentHubFilter = 'all',
    this.merchantTierFilter = 'all',
    this.selectedRegion = 'all',
    this.users = const [],
    this.distributionCenters = const [],
    this.merchants = const [],
    this.agents = const [],
    this.globalStock = const [],
    this.expenses = const [],
    this.settlementReconciliations = const [],
    this.appSettings = const AdminAppSettings(),
    this.serverSettings = const AdminServerSettings(),
    this.routingTariffs = const [],
    this.auditLogs = const [],
    this.dailySales = const [],
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
    String? agentStatusFilter,
    String? auditLogActionFilter,
    String? auditLogRoleFilter,
    String? auditLogHubFilter,
    String? auditLogDateFilter,
    String? expenseWarehouseFilter,
    String? expenseCategoryFilter,
    String? stockMerchantFilter,
    String? stockHubFilter,
    String? stockHealthFilter,
    String? agentMerchantFilter,
    String? agentHubFilter,
    String? merchantTierFilter,
    String? selectedRegion,
    List<AdminUserItem>? users,
    List<AdminDistributionCenter>? distributionCenters,
    List<AdminMerchant>? merchants,
    List<AdminLogisticsAgent>? agents,
    List<AdminGlobalStockItem>? globalStock,
    List<AdminWarehouseExpense>? expenses,
    List<AdminSettlementReconciliation>? settlementReconciliations,
    AdminAppSettings? appSettings,
    AdminServerSettings? serverSettings,
    List<AdminRoutingTariff>? routingTariffs,
    List<AdminAuditLog>? auditLogs,
    List<AgentDailySaleRecord>? dailySales,
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
      agentStatusFilter: agentStatusFilter ?? this.agentStatusFilter,
      auditLogActionFilter: auditLogActionFilter ?? this.auditLogActionFilter,
      auditLogRoleFilter: auditLogRoleFilter ?? this.auditLogRoleFilter,
      auditLogHubFilter: auditLogHubFilter ?? this.auditLogHubFilter,
      auditLogDateFilter: auditLogDateFilter ?? this.auditLogDateFilter,
      expenseWarehouseFilter:
          expenseWarehouseFilter ?? this.expenseWarehouseFilter,
      expenseCategoryFilter:
          expenseCategoryFilter ?? this.expenseCategoryFilter,
      stockMerchantFilter: stockMerchantFilter ?? this.stockMerchantFilter,
      stockHubFilter: stockHubFilter ?? this.stockHubFilter,
      stockHealthFilter: stockHealthFilter ?? this.stockHealthFilter,
      agentMerchantFilter: agentMerchantFilter ?? this.agentMerchantFilter,
      agentHubFilter: agentHubFilter ?? this.agentHubFilter,
      merchantTierFilter: merchantTierFilter ?? this.merchantTierFilter,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      users: users ?? this.users,
      distributionCenters: distributionCenters ?? this.distributionCenters,
      merchants: merchants ?? this.merchants,
      agents: agents ?? this.agents,
      globalStock: globalStock ?? this.globalStock,
      expenses: expenses ?? this.expenses,
      settlementReconciliations:
          settlementReconciliations ?? this.settlementReconciliations,
      appSettings: appSettings ?? this.appSettings,
      serverSettings: serverSettings ?? this.serverSettings,
      routingTariffs: routingTariffs ?? this.routingTariffs,
      auditLogs: auditLogs ?? this.auditLogs,
      dailySales: dailySales ?? this.dailySales,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      statusMessage: statusMessage ?? this.statusMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  // Filtered lists
  List<AdminUserItem> get filteredUsers {
    return users.where((u) {
      if (roleFilter != 'all' &&
          u.role.toLowerCase() != roleFilter.toLowerCase()) {
        return false;
      }
      if (statusFilter != 'all' &&
          u.status.toLowerCase() != statusFilter.toLowerCase()) {
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
        final matchesCode =
            (u.deliveryAgentCode ?? '').toLowerCase().contains(q) ||
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
      if (statusFilter != 'all' &&
          m.status.toLowerCase() != statusFilter.toLowerCase()) {
        return false;
      }
      if (merchantTierFilter != 'all' &&
          m.tier.toLowerCase() != merchantTierFilter.toLowerCase()) {
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

  List<AdminGlobalStockItem> get filteredGlobalStock {
    return globalStock.where((item) {
      if (stockMerchantFilter != 'all') {
        final f = stockMerchantFilter.toLowerCase();
        final matchesId = item.merchantId.toLowerCase() == f;
        final matchesName = item.merchantName.toLowerCase().contains(f);
        if (!matchesId && !matchesName) return false;
      }
      if (stockHubFilter != 'all') {
        final inHub = item.dcStockBreakdown.keys.any((k) =>
            k.toLowerCase().contains(stockHubFilter.toLowerCase()) &&
            (item.dcStockBreakdown[k] ?? 0) > 0);
        if (!inHub) return false;
      }
      if (stockHealthFilter != 'all') {
        if (stockHealthFilter == 'low_stock' && item.lowStockDcCount == 0)
          return false;
        if (stockHealthFilter == 'critical' && item.totalStock > 1000)
          return false;
        if (stockHealthFilter == 'adequate' && item.lowStockDcCount > 0)
          return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = item.productName.toLowerCase().contains(q);
        final matchSku = item.sku.toLowerCase().contains(q);
        final matchMerchant = item.merchantName.toLowerCase().contains(q);
        return matchName || matchSku || matchMerchant;
      }
      return true;
    }).toList();
  }

  /// All Stock Holders (DC Shelves + 114 CRM Logistics Agents) for Multi-Hub Stock DataTable
  List<AdminStockHolderRow> get stockHolderRows {
    final List<AdminStockHolderRow> rows = [];

    // 1. Distribution Center Warehouse Shelves
    // Abuja Central DC Shelf
    final Map<String, int> abujaQuantities = {};
    double abujaTotalValuation = 0.0;
    int abujaTotalUnits = 0;
    for (final item in globalStock) {
      final qty = item.dcStockBreakdown['Abuja Central DC'] ??
          item.dcStockBreakdown['Abuja'] ??
          0;
      abujaQuantities[item.sku] = qty;
      abujaTotalUnits += qty;
      abujaTotalValuation += (qty * item.unitPrice);
    }
    rows.add(AdminStockHolderRow(
      id: 'shelf-dc-abuja',
      name: 'Abuja Central DC (Warehouse Shelf)',
      code: 'DC-ABJ-01',
      type: AdminStockHolderType.dcShelf,
      hubName: 'Abuja Central DC',
      hubId: 'DC-ABJ-01',
      assignedMerchantIds: merchants.map((m) => m.id).toList(),
      assignedMerchantNames: merchants.map((m) => m.businessName).toList(),
      contactPerson: 'Engr. Bello (Abuja DC Manager)',
      phone: '+234 803 222 1100',
      productQuantities: abujaQuantities,
      totalUnits: abujaTotalUnits,
      totalValueNaira: abujaTotalValuation,
      status: 'operational',
    ));

    // Lagos Central DC Shelf
    final Map<String, int> lagosQuantities = {};
    double lagosTotalValuation = 0.0;
    int lagosTotalUnits = 0;
    for (final item in globalStock) {
      final qty = item.dcStockBreakdown['Lagos Central DC'] ??
          item.dcStockBreakdown['Lagos Grand Hub'] ??
          item.dcStockBreakdown['Lagos'] ??
          0;
      lagosQuantities[item.sku] = qty;
      lagosTotalUnits += qty;
      lagosTotalValuation += (qty * item.unitPrice);
    }
    rows.add(AdminStockHolderRow(
      id: 'shelf-dc-lagos',
      name: 'Lagos Central DC (Warehouse Shelf)',
      code: 'DC-LAG-01',
      type: AdminStockHolderType.dcShelf,
      hubName: 'Lagos Central DC',
      hubId: 'DC-LAG-01',
      assignedMerchantIds: merchants.map((m) => m.id).toList(),
      assignedMerchantNames: merchants.map((m) => m.businessName).toList(),
      contactPerson: 'Babatunde Adeleke (Lagos Hub Head)',
      phone: '+234 802 111 9900',
      productQuantities: lagosQuantities,
      totalUnits: lagosTotalUnits,
      totalValueNaira: lagosTotalValuation,
      status: 'operational',
    ));

    // 2. Logistics Agents (Internal Fleet & 3PLs)
    for (final agent in agents) {
      final Map<String, int> agentQuantities = {};
      double agentTotalValuation = 0.0;
      int agentTotalUnits = 0;

      for (final item in globalStock) {
        int qty = 0;
        if (agent.heldStock.containsKey(item.sku)) {
          qty = agent.heldStock[item.sku]!;
        } else if (agent.heldStock.containsKey(item.productName)) {
          qty = agent.heldStock[item.productName]!;
        } else if (item.agentStockBreakdown.containsKey(agent.name)) {
          qty = item.agentStockBreakdown[agent.name]!;
        } else {
          for (final entry in agent.heldStock.entries) {
            if (item.productName.toLowerCase().contains(entry.key.toLowerCase()) ||
                entry.key.toLowerCase().contains(item.productName.toLowerCase())) {
              qty = entry.value;
              break;
            }
          }
        }
        agentQuantities[item.sku] = qty;
        agentTotalUnits += qty;
        agentTotalValuation += (qty * item.unitPrice);
      }

      AdminStockHolderType holderType;
      if (agent.type == 'internal_logistics') {
        holderType = AdminStockHolderType.internalFleet;
      } else if (agent.type == '3pl_partner') {
        holderType = AdminStockHolderType.external3pl;
      } else if (agent.type == 'distributor_agent') {
        holderType = AdminStockHolderType.distributorAgent;
      } else {
        holderType = AdminStockHolderType.riderAgent;
      }

      final hubName = agent.assignedWarehouseName ??
          (agent.assignedWarehouseId == 'DC-LAG-01'
              ? 'Lagos Central DC'
              : 'Abuja Central DC');
      final hubId = agent.assignedWarehouseId ??
          (hubName.contains('Lagos') ? 'DC-LAG-01' : 'DC-ABJ-01');

      rows.add(AdminStockHolderRow(
        id: agent.id,
        name: agent.name,
        code: agent.agentCode,
        type: holderType,
        hubName: hubName,
        hubId: hubId,
        assignedMerchantIds: agent.assignedMerchantIds,
        assignedMerchantNames: agent.assignedMerchantNames,
        contactPerson: agent.contactPerson,
        phone: agent.phone,
        productQuantities: agentQuantities,
        totalUnits: agentTotalUnits,
        totalValueNaira: agentTotalValuation,
        status: agent.status,
        lastBalancedAt: agent.lastBalancedAt,
        agentRef: agent,
      ));
    }

    return rows;
  }

  /// Filtered Stock Holders for Multi-Hub Stock DataTable
  List<AdminStockHolderRow> get filteredStockHolderRows {
    return stockHolderRows.where((row) {
      // 1. Merchant filter
      if (stockMerchantFilter != 'all') {
        final f = stockMerchantFilter.toLowerCase();
        if (!row.isDcShelf) {
          final isAssigned = row.assignedMerchantIds
                  .any((m) => m.toLowerCase() == f) ||
              row.assignedMerchantNames
                  .any((m) => m.toLowerCase().contains(f));
          final hasMerchantStock = globalStock
              .where((p) =>
                  p.merchantId.toLowerCase() == f ||
                  p.merchantName.toLowerCase().contains(f))
              .any((p) => row.quantityForSku(p.sku) > 0);
          if (!isAssigned && !hasMerchantStock) return false;
        }
      }

      // 2. Hub / Warehouse filter
      if (stockHubFilter != 'all') {
        final f = stockHubFilter.toLowerCase();
        final matchesHub = row.hubName.toLowerCase().contains(f) ||
            row.hubId.toLowerCase().contains(f);
        if (!matchesHub) return false;

        // Strict rule: Lagos Central DC strictly excludes NovaXpress Logistics fleet
        if (f.contains('lagos') && row.isInternalFleet) {
          return false;
        }
      }

      // 3. Custodian Type / Health filter
      if (stockHealthFilter != 'all') {
        if (stockHealthFilter == 'dc_shelves' && !row.isDcShelf) return false;
        if (stockHealthFilter == 'agents' && row.isDcShelf) return false;
        if (stockHealthFilter == 'internal_fleet' && !row.isInternalFleet) {
          return false;
        }
        if (stockHealthFilter == '3pl_partner' && !row.is3pl) return false;
        if (stockHealthFilter == 'holding_stock' && row.totalUnits == 0) {
          return false;
        }
        if (stockHealthFilter == 'zero_stock' && row.totalUnits > 0) return false;
        if (stockHealthFilter == 'low_stock' && row.totalUnits > 50) return false;
      }

      // 4. Search query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = row.name.toLowerCase().contains(q);
        final matchCode = row.code.toLowerCase().contains(q);
        final matchContact = row.contactPerson.toLowerCase().contains(q);
        final matchPhone = row.phone.toLowerCase().contains(q);
        final matchHub = row.hubName.toLowerCase().contains(q);
        return matchName || matchCode || matchContact || matchPhone || matchHub;
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
          if (!r.contains('dc_manager') &&
              !r.contains('dc_admin') &&
              !r.contains('supervisor')) {
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
          if (!act.contains('USER') &&
              !act.contains('ADMIN') &&
              !act.contains('ONBOARD')) return false;
        } else if (auditLogActionFilter == 'finance') {
          if (!act.contains('REMIT') &&
              !act.contains('EXPENSE') &&
              !act.contains('EXPENDITURE') &&
              !act.contains('PAYOUT') &&
              !act.contains('SETTLEMENT')) return false;
        } else if (auditLogActionFilter == 'orders') {
          if (!act.contains('ORDER') &&
              !act.contains('DISPATCH') &&
              !act.contains('ROUTE') &&
              !act.contains('ASSIGN')) return false;
        } else if (auditLogActionFilter == 'stock') {
          if (!act.contains('STOCK') &&
              !act.contains('TRANSFER') &&
              !act.contains('INVENTORY')) return false;
        } else if (auditLogActionFilter == 'policy') {
          if (!act.contains('POLICY') &&
              !act.contains('TARIFF') &&
              !act.contains('SETTINGS') &&
              !act.contains('CREDENTIALS')) return false;
        } else if (!act.contains(auditLogActionFilter.toUpperCase())) {
          return false;
        }
      }

      // Hub Filter
      if (auditLogHubFilter != 'all') {
        final matchesHubId = log.distributionCenterId == auditLogHubFilter;
        final matchesHubName = (log.distributionCenterName ?? '')
            .toLowerCase()
            .contains(auditLogHubFilter.toLowerCase());
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
        final matchDc =
            (log.distributionCenterName ?? '').toLowerCase().contains(q);
        final matchIp = log.ipAddress.toLowerCase().contains(q);

        return matchActor ||
            matchAction ||
            matchResource ||
            matchDetails ||
            matchDc ||
            matchIp;
      }

      return true;
    }).toList();
  }

  List<AdminLogisticsAgent> get filteredAgents {
    return agents.where((a) {
      if (agentStatusFilter != 'all' &&
          a.status.toLowerCase() != agentStatusFilter.toLowerCase()) {
        return false;
      }
      if (agentHubFilter != 'all') {
        final hubF = agentHubFilter.toLowerCase();
        final matchesHub = a.assignedWarehouseId?.toLowerCase() == hubF ||
            (a.assignedWarehouseName ?? '').toLowerCase().contains(hubF);
        if (!matchesHub) {
          return false;
        }
        // Strict operational scoping: Abuja DC uses NovaXpress logistics fleet in its agent roster,
        // but Lagos Central branch does NOT use NovaXpress logistics.
        if ((hubF == 'dc-lag-01' || hubF.contains('lagos')) &&
            (a.type == 'internal_logistics' ||
                a.name.toLowerCase().contains('novaxpress'))) {
          return false;
        }
      }
      if (agentMerchantFilter != 'all') {
        final f = agentMerchantFilter.toLowerCase();
        final merchant = merchants.firstWhere(
          (m) =>
              m.id.toLowerCase() == f ||
              m.businessName.toLowerCase().contains(f),
          orElse: () => const AdminMerchant(
              id: '', businessName: '', contactName: '', phone: '', email: ''),
        );
        final matchesAssigned = a.assignedMerchantIds.contains(f) ||
            (merchant.id.isNotEmpty && a.assignedMerchantIds.contains(merchant.id)) ||
            (merchant.businessName.isNotEmpty &&
                a.assignedMerchantNames.any((n) => n.toLowerCase().contains(f))) ||
            (merchant.id.isNotEmpty && merchant.assignedAgentIds.contains(a.id)) ||
            (merchant.id.isNotEmpty &&
                merchant.assignedAgentNames
                    .any((n) => a.name.toLowerCase().contains(n.toLowerCase())));
        if (!matchesAssigned) return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = a.name.toLowerCase().contains(q);
        final matchCode = a.agentCode.toLowerCase().contains(q);
        final matchPerson = a.contactPerson.toLowerCase().contains(q);
        final matchPhone = a.phone.toLowerCase().contains(q);
        final matchEmail = a.email.toLowerCase().contains(q);
        return matchName ||
            matchCode ||
            matchPerson ||
            matchPhone ||
            matchEmail;
      }
      return true;
    }).toList();
  }

  List<AdminMerchant> get pendingApprovalMerchants =>
      merchants.where((m) => m.status.toLowerCase() == 'pending').toList();
  List<AdminLogisticsAgent> get pendingApprovalAgents =>
      agents.where((a) => a.isPendingApproval).toList();

  List<AdminWarehouseExpense> get filteredExpenses {
    return expenses.where((exp) {
      if (expenseWarehouseFilter != 'all' &&
          exp.warehouseId != expenseWarehouseFilter) {
        return false;
      }
      if (expenseCategoryFilter != 'all' &&
          exp.category != expenseCategoryFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return exp.title.toLowerCase().contains(q) ||
            exp.warehouseName.toLowerCase().contains(q) ||
            exp.receiptNumber.toLowerCase().contains(q) ||
            exp.recordedBy.toLowerCase().contains(q) ||
            exp.notes.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }
}

class AdminConsoleNotifier extends StateNotifier<AdminConsoleState> {
  final AdminRemoteDataSource _dataSource;
  final Ref _ref;

  AdminConsoleNotifier(this._dataSource, this._ref)
      : super(const AdminConsoleState(
          distributionCenters: [],
          merchants: [],
          agents: [],
          globalStock: [],
          expenses: [],
          settlementReconciliations: [],
        )) {
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

  void setAgentStatusFilter(String status) {
    state = state.copyWith(agentStatusFilter: status);
  }

  void setSelectedRegion(String region) {
    state = state.copyWith(
      selectedRegion: region,
      hubFilter: region,
      stockHubFilter: region == 'all'
          ? 'all'
          : (region.contains('ABJ') ? 'Abuja' : 'Lagos'),
      agentHubFilter: region,
      auditLogHubFilter: region,
    );
  }

  void setHubFilter(String hubId) {
    state = state.copyWith(hubFilter: hubId);
  }

  void setExpenseWarehouseFilter(String whId) {
    state = state.copyWith(expenseWarehouseFilter: whId);
  }

  void setExpenseCategoryFilter(String cat) {
    state = state.copyWith(expenseCategoryFilter: cat);
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

  void setStockMerchantFilter(String merchantId) {
    state = state.copyWith(stockMerchantFilter: merchantId);
  }

  void setStockHubFilter(String hubId) {
    state = state.copyWith(stockHubFilter: hubId);
  }

  void setStockHealthFilter(String health) {
    state = state.copyWith(stockHealthFilter: health);
  }

  void setAgentMerchantFilter(String merchantId) {
    state = state.copyWith(agentMerchantFilter: merchantId);
  }

  void setAgentHubFilter(String hubId) {
    state = state.copyWith(agentHubFilter: hubId);
  }

  void setMerchantTierFilter(String tier) {
    state = state.copyWith(merchantTierFilter: tier);
  }

  void setGlobalStock(List<AdminGlobalStockItem> stock) {
    state = state.copyWith(globalStock: stock);
  }

  Future<void> onboardProduct({
    required String name,
    required String sku,
    required String merchantId,
    required String merchantName,
    required double unitPrice,
    required int abujaShelfQty,
    required int lagosShelfQty,
    int? kanoShelfQty,
    int? phcShelfQty,
    Map<String, int>? initialAgentCustody,
  }) async {
    final newItem = await _dataSource.onboardProduct(
      name: name,
      sku: sku,
      merchantId: merchantId,
      merchantName: merchantName,
      unitPrice: unitPrice,
      abujaShelfQty: abujaShelfQty,
      lagosShelfQty: lagosShelfQty,
      kanoShelfQty: kanoShelfQty,
      phcShelfQty: phcShelfQty,
      initialAgentCustody: initialAgentCustody,
    );

    final updated = [newItem, ...state.globalStock];
    state = state.copyWith(globalStock: updated);
    _logAudit(
      action: 'ONBOARD_PRODUCT',
      resource: 'Inventory',
      details:
          'Onboarded new product $name ($sku) for merchant $merchantName with ${newItem.totalWarehouseStock} warehouse shelf units',
    );
  }

  void recordInboundBatchQA({
    required String sku,
    required String batchNumber,
    required String producerName,
    required int totalUnitsReceived,
    required int abujaSplit,
    required int lagosSplit,
    required int sampleUnitsTested,
    required String colorDilationCheck,
    required String grindConsistencyCheck,
    required String packagingCheck,
    required String overallQualityRating,
    required int quarantinedUnits,
    required String qcNotes,
    required String inspectorName,
  }) {
    final netAcceptedUnits = totalUnitsReceived - quarantinedUnits;
    final idx = state.globalStock.indexWhere((p) => p.sku == sku);
    String prodName = 'Consignment SKU $sku';
    if (idx >= 0) {
      final current = state.globalStock[idx];
      prodName = current.productName;
      final newDcMap = Map<String, int>.from(current.dcStockBreakdown);
      newDcMap['Abuja Central DC'] =
          (newDcMap['Abuja Central DC'] ?? 0) + abujaSplit;
      final lagosNet = (lagosSplit - quarantinedUnits).clamp(0, 999999);
      newDcMap['Lagos Central DC'] =
          (newDcMap['Lagos Central DC'] ?? 0) + lagosNet;
      newDcMap['Lagos Grand Hub'] =
          (newDcMap['Lagos Grand Hub'] ?? 0) + lagosNet;

      final newTotalWarehouse = current.totalWarehouseStock + netAcceptedUnits;
      final updatedItem = current.copyWith(
        totalWarehouseStock: newTotalWarehouse,
        totalStock: newTotalWarehouse + current.totalRiderCustodyStock,
        dcStockBreakdown: newDcMap,
      );

      final updatedList = List<AdminGlobalStockItem>.from(state.globalStock);
      updatedList[idx] = updatedItem;
      state = state.copyWith(globalStock: updatedList);
    }

    _logAudit(
      action: 'INBOUND_BATCH_QC_INSPECTION',
      resource: 'Inventory',
      details:
          'Received Batch $batchNumber ($totalUnitsReceived units) for $prodName from $producerName. QC Grade: $overallQualityRating by $inspectorName. Net Accepted: $netAcceptedUnits ($abujaSplit Abuja, ${(lagosSplit - quarantinedUnits)} Lagos). Quarantined: $quarantinedUnits. Notes: $qcNotes',
    );
  }

  void setAuditLogDateFilter(String date) {
    state = state.copyWith(auditLogDateFilter: date);
  }

  Future<void> recordWarehouseExpense({
    required String warehouseId,
    required String warehouseName,
    required String title,
    required String category,
    required double amount,
    required String recordedBy,
    String? receiptNumber,
    String? notes,
  }) async {
    final newExp = AdminWarehouseExpense(
      id: 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      title: title,
      category: category,
      amount: amount,
      recordedBy: recordedBy,
      recordedAt: DateTime.now(),
      status: 'approved',
      receiptNumber: receiptNumber ??
          'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      notes: notes ?? '',
    );

    final updated = [newExp, ...state.expenses];
    state = state.copyWith(expenses: updated);

    _logAudit(
      action: 'RECORD_WAREHOUSE_EXPENSE',
      resource: 'Expenses',
      details:
          'Recorded expense "₦${amount.toStringAsFixed(0)} - $title" for $warehouseName',
      distributionCenterId: warehouseId,
      distributionCenterName: warehouseName,
    );
  }

  Future<Map<String, dynamic>> recordAgentDailyBalance({
    required String agentId,
    required Map<String, int> confirmedStock,
    String? notes,
  }) async {
    final idx = state.agents.indexWhere((a) => a.id == agentId);
    if (idx < 0) return {'success': false, 'message': 'Agent not found.'};

    final agent = state.agents[idx];
    final updatedAgent = agent.copyWith(
      heldStock: confirmedStock,
      lastBalancedAt: DateTime.now(),
    );

    final updatedList = List<AdminLogisticsAgent>.from(state.agents);
    updatedList[idx] = updatedAgent;

    // Recalculate global stock agent breakdown
    final updatedStock = state.globalStock.map((gItem) {
      final newAgentBreakdown =
          Map<String, int>.from(gItem.agentStockBreakdown);
      if (confirmedStock.containsKey(gItem.productName)) {
        newAgentBreakdown[agent.name] = confirmedStock[gItem.productName] ?? 0;
      }
      return gItem.copyWith(agentStockBreakdown: newAgentBreakdown);
    }).toList();

    state = state.copyWith(
      agents: updatedList,
      globalStock: updatedStock,
    );

    // Persist agent custody to Supabase delivery_agents table & cache
    _dataSource.updateLogisticsAgent(updatedAgent);

    _logAudit(
      action: 'RECORD_AGENT_STOCK_BALANCE',
      resource: 'Agents',
      details:
          'Logged daily stock balance for agent ${agent.name}. Count confirmed for ${confirmedStock.length} products.',
      distributionCenterId: agent.assignedWarehouseId,
      distributionCenterName: agent.assignedWarehouseName,
    );

    return {
      'success': true,
      'message': 'Daily stock balance updated and synced across the platform.'
    };
  }

  Future<void> registerLogisticsAgent({
    required String name,
    required String agentCode,
    required String type,
    required String contactPerson,
    required String phone,
    required String email,
    required double deliveryFee,
    required double failedDeliveryFee,
    required String assignedWarehouseId,
    required String assignedWarehouseName,
    required List<String> coverageStates,
    List<String> assignedMerchantIds = const [],
    List<String> assignedMerchantNames = const [],
    double commissionRate = 0.0,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    final newAgent = AdminLogisticsAgent(
      id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      agentCode: agentCode,
      type: type,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      deliveryFee: deliveryFee,
      failedDeliveryFee: failedDeliveryFee,
      assignedWarehouseId: assignedWarehouseId,
      assignedWarehouseName: assignedWarehouseName,
      assignedMerchantIds: assignedMerchantIds,
      assignedMerchantNames: assignedMerchantNames,
      commissionRate: commissionRate,
      coverageStates: coverageStates,
      bankName: bankName ?? '',
      accountNumber: accountNumber ?? '',
      accountName: accountName ?? '',
      status: 'active',
      rating: 5.0,
      totalDeliveries: 0,
      totalRemittedNaira: 0.0,
      heldStock: const {},
      createdAt: DateTime.now(),
    );

    final updatedList = [newAgent, ...state.agents];

    // If merchants are assigned, also sync merchants list
    List<AdminMerchant> updatedMerchants = state.merchants;
    if (assignedMerchantIds.isNotEmpty) {
      updatedMerchants = state.merchants.map((m) {
        if (assignedMerchantIds.contains(m.id)) {
          final currentIds = List<String>.from(m.assignedAgentIds);
          final currentNames = List<String>.from(m.assignedAgentNames);
          if (!currentIds.contains(newAgent.id)) currentIds.add(newAgent.id);
          if (!currentNames.contains(newAgent.name)) currentNames.add(newAgent.name);
          return m.copyWith(assignedAgentIds: currentIds, assignedAgentNames: currentNames);
        }
        return m;
      }).toList();
    }

    state = state.copyWith(agents: updatedList, merchants: updatedMerchants);

    _logAudit(
      action: 'REGISTER_LOGISTICS_AGENT',
      resource: 'Logistics Agents',
      details:
          'Registered new logistics agent $name ($agentCode) under $assignedWarehouseName - Delivery: ₦${deliveryFee.toStringAsFixed(0)}, Failed: ₦${failedDeliveryFee.toStringAsFixed(0)}, Commission: $commissionRate%',
      distributionCenterId: assignedWarehouseId,
      distributionCenterName: assignedWarehouseName,
    );
  }

  /// Update individual agent details, fees, commissions, and merchant attachments
  Future<void> updateLogisticsAgent(AdminLogisticsAgent updatedAgent) async {
    final idx = state.agents.indexWhere(
        (a) => a.id == updatedAgent.id || a.agentCode == updatedAgent.agentCode);
    if (idx >= 0) {
      final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
      updatedAgents[idx] = updatedAgent;

      // Sync merchants state to match agent's assignedMerchantIds
      final updatedMerchants = state.merchants.map((m) {
        final shouldBeAssigned = updatedAgent.assignedMerchantIds.contains(m.id) ||
            updatedAgent.assignedMerchantNames.any((n) =>
                n.toLowerCase() == m.businessName.toLowerCase() ||
                n.toLowerCase().contains(m.businessName.toLowerCase()) ||
                m.businessName.toLowerCase().contains(n.toLowerCase()));
        final currentAgentIds = List<String>.from(m.assignedAgentIds);
        final currentAgentNames = List<String>.from(m.assignedAgentNames);
        if (shouldBeAssigned) {
          if (!currentAgentIds.contains(updatedAgent.id)) {
            currentAgentIds.add(updatedAgent.id);
          }
          if (!currentAgentNames.contains(updatedAgent.name)) {
            currentAgentNames.add(updatedAgent.name);
          }
        } else {
          currentAgentIds.remove(updatedAgent.id);
          currentAgentNames.remove(updatedAgent.name);
        }
        return m.copyWith(
          assignedAgentIds: currentAgentIds,
          assignedAgentNames: currentAgentNames,
        );
      }).toList();

      state = state.copyWith(agents: updatedAgents, merchants: updatedMerchants);

      await _dataSource.updateLogisticsAgent(updatedAgent);

      _logAudit(
        action: 'UPDATE_AGENT_DETAILS',
        resource: 'Logistics Agents',
        details:
            'Updated details for ${updatedAgent.name} (${updatedAgent.agentCode}) - Delivery: ₦${updatedAgent.deliveryFee.toStringAsFixed(0)}, Failed: ₦${updatedAgent.failedDeliveryFee.toStringAsFixed(0)}, Commission: ${updatedAgent.commissionRate}%, Hub: ${updatedAgent.assignedWarehouseName}',
        distributionCenterId: updatedAgent.assignedWarehouseId,
        distributionCenterName: updatedAgent.assignedWarehouseName,
      );
    } else {
      final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
      updatedAgents.insert(0, updatedAgent);
      state = state.copyWith(agents: updatedAgents);
      await _dataSource.updateLogisticsAgent(updatedAgent);
    }
  }

  /// Update physical stock custody allocation for an agent.
  /// Recomputes global stock totals, rider custody figures, updates agent heldStock,
  /// generates an immutable audit record with operator accountability, and persists to backend.
  Future<void> updateAgentCustodyStock({
    required String agentId,
    required Map<String, int> newHeldStock,
    required String operatorName,
    String? reason,
  }) async {
    final idx = state.agents.indexWhere((a) => a.id == agentId);
    if (idx < 0) return;

    final agent = state.agents[idx];
    final cleanHeldStock = <String, int>{};
    newHeldStock.forEach((key, val) {
      if (val > 0) cleanHeldStock[key] = val;
    });

    final updatedAgent = agent.copyWith(
      heldStock: cleanHeldStock,
      lastBalancedAt: DateTime.now(),
    );
    final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
    updatedAgents[idx] = updatedAgent;

    // Recalculate globalStock for all products based on updated agents list
    final updatedGlobalStock = state.globalStock.map((prod) {
      final newQtyForAgent = cleanHeldStock[prod.sku] ??
          cleanHeldStock[prod.id] ??
          cleanHeldStock[prod.productName] ??
          0;

      final updatedAgentBreakdown = Map<String, int>.from(prod.agentStockBreakdown);
      if (newQtyForAgent > 0) {
        updatedAgentBreakdown[agent.name] = newQtyForAgent;
      } else {
        updatedAgentBreakdown.remove(agent.name);
      }

      // Recompute total custody for this product across all agents
      int newCustodyTotal = 0;
      for (final a in updatedAgents) {
        final q = a.heldStock[prod.sku] ??
            a.heldStock[prod.id] ??
            a.heldStock[prod.productName] ??
            0;
        newCustodyTotal += q;
      }

      return prod.copyWith(
        agentStockBreakdown: updatedAgentBreakdown,
        totalRiderCustodyStock: newCustodyTotal,
        totalStock: prod.totalWarehouseStock + newCustodyTotal,
      );
    }).toList();

    state = state.copyWith(
      agents: updatedAgents,
      globalStock: updatedGlobalStock,
    );

    // Save agent changes to backend
    _dataSource.updateLogisticsAgent(updatedAgent);

    // Detailed changes breakdown for audit log and persistent stock ledger entries
    final changesList = <String>[];
    final allKeys = {...agent.heldStock.keys, ...cleanHeldStock.keys};
    final targetWarehouse = agent.assignedWarehouseName ?? 'Abuja Central DC';
    final targetClientId = agent.assignedMerchantIds.isNotEmpty
        ? agent.assignedMerchantIds.first
        : '00000000-0000-4000-8000-791731264594';

    for (final key in allKeys) {
      final oldQty = agent.heldStock[key] ?? 0;
      final newQty = cleanHeldStock[key] ?? 0;
      if (oldQty != newQty) {
        final diff = newQty - oldQty;
        changesList.add('$key: $oldQty -> $newQty (${diff >= 0 ? "+$diff" : "$diff"} units)');

        // Persist immutable audit entry into Supabase client_stock_ledger_entries table
        _dataSource.persistStockLedgerEntry(
          clientId: targetClientId,
          warehouse: targetWarehouse,
          itemCode: key,
          itemName: key,
          itemGroup: 'Custody Rebalance',
          voucherType: 'inventory_adjustment',
          voucherNo: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
          qtyChange: diff.toDouble(),
          incomingQty: diff > 0 ? diff.toDouble() : 0.0,
          outgoingQty: diff < 0 ? (-diff).toDouble() : 0.0,
          valuationRate: 15000.0,
          totalValue: (diff.abs() * 15000.0),
          notes:
              'Manual custody adjustment for ${agent.name} (${agent.agentCode}) by $operatorName. $diff units. Reason: ${reason ?? "Direct custody adjustment"}',
        );
      }
    }

    _logAudit(
      action: 'UPDATE_AGENT_CUSTODY_STOCK',
      resource: 'Inventory',
      details:
          'Stock custody modified for ${agent.name} (${agent.agentCode}) by $operatorName. Changes: ${changesList.isEmpty ? "No quantity changes" : changesList.join(", ")}${reason != null && reason.isNotEmpty ? " • Reason: $reason" : ""}',
      distributionCenterId: agent.assignedWarehouseId,
      distributionCenterName: agent.assignedWarehouseName,
    );
  }

  /// Allocate physical inventory from Central DC Shelves to an Agent (e.g. NovaXpress Logistics NX-ABJ-01 or 3PL partner)
  Future<bool> allocateStockFromWarehouseToAgent({
    required String agentId,
    required String sku,
    required int units,
    required String operatorName,
    String? sourceDcName,
    String? notes,
  }) async {
    if (units <= 0) return false;
    final agentIdx = state.agents.indexWhere((a) => a.id == agentId || a.agentCode == agentId);
    if (agentIdx < 0) return false;

    final targetAgent = state.agents[agentIdx];
    final updatedHeldStock = Map<String, int>.from(targetAgent.heldStock);
    final currentQty = updatedHeldStock[sku] ?? 0;
    updatedHeldStock[sku] = currentQty + units;

    final effectiveDc = sourceDcName ?? targetAgent.assignedWarehouseName ?? 'Abuja Central DC';

    // 1. Update Global Stock to deduct from DC shelf and add to custody
    final updatedGlobalStock = state.globalStock.map((prod) {
      if (prod.sku.toLowerCase() == sku.toLowerCase() || prod.productName.toLowerCase() == sku.toLowerCase() || prod.id == sku) {
        final currentDcStock = prod.dcStockBreakdown[effectiveDc] ?? prod.totalWarehouseStock;
        final newDcStock = (currentDcStock - units).clamp(0, 9999999);
        final updatedDcMap = Map<String, int>.from(prod.dcStockBreakdown);
        updatedDcMap[effectiveDc] = newDcStock;

        final updatedAgentMap = Map<String, int>.from(prod.agentStockBreakdown);
        updatedAgentMap[targetAgent.name] = (updatedAgentMap[targetAgent.name] ?? 0) + units;

        final newTotalWarehouse = (prod.totalWarehouseStock - units).clamp(0, 9999999);
        final newTotalCustody = prod.totalRiderCustodyStock + units;

        return prod.copyWith(
          totalWarehouseStock: newTotalWarehouse,
          totalRiderCustodyStock: newTotalCustody,
          totalStock: newTotalWarehouse + newTotalCustody,
          dcStockBreakdown: updatedDcMap,
          agentStockBreakdown: updatedAgentMap,
        );
      }
      return prod;
    }).toList();

    // 2. Update agent
    final updatedAgent = targetAgent.copyWith(
      heldStock: updatedHeldStock,
      lastBalancedAt: DateTime.now(),
    );
    final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
    updatedAgents[agentIdx] = updatedAgent;

    state = state.copyWith(
      agents: updatedAgents,
      globalStock: updatedGlobalStock,
    );

    // 3. Persist agent to DB & cache
    await _dataSource.updateLogisticsAgent(updatedAgent);

    // 4. Record stock movement ledger entry
    final targetClientId = targetAgent.assignedMerchantIds.isNotEmpty
        ? targetAgent.assignedMerchantIds.first
        : '00000000-0000-4000-8000-791731264594';

    await _dataSource.persistStockLedgerEntry(
      clientId: targetClientId,
      warehouse: effectiveDc,
      itemCode: sku,
      itemName: sku,
      itemGroup: 'Warehouse Allocation',
      voucherType: 'dc_agent_replenishment',
      voucherNo: 'ALLOC-${DateTime.now().millisecondsSinceEpoch}',
      qtyChange: units.toDouble(),
      incomingQty: units.toDouble(),
      outgoingQty: 0.0,
      valuationRate: 15000.0,
      totalValue: units * 15000.0,
      notes: 'Replenishment of $units units allocated to ${targetAgent.name} (${targetAgent.agentCode}) by $operatorName. ${notes ?? ""}',
    );

    _logAudit(
      action: 'ALLOCATE_STOCK_TO_AGENT',
      resource: 'Inventory',
      details: 'Allocated $units units of $sku from $effectiveDc to ${targetAgent.name} (${targetAgent.agentCode}) by $operatorName',
      distributionCenterId: targetAgent.assignedWarehouseId,
      distributionCenterName: effectiveDc,
    );

    return true;
  }

  /// Re-allocate physical inventory from one Agent to another (e.g. from 3PL partner to NovaXpress Logistics)
  Future<bool> reallocateStockBetweenAgents({
    required String sourceAgentId,
    required String destinationAgentId,
    required String sku,
    required int units,
    required String operatorName,
    String? reason,
  }) async {
    if (units <= 0 || sourceAgentId == destinationAgentId) return false;

    final srcIdx = state.agents.indexWhere((a) => a.id == sourceAgentId || a.agentCode == sourceAgentId);
    final destIdx = state.agents.indexWhere((a) => a.id == destinationAgentId || a.agentCode == destinationAgentId);
    if (srcIdx < 0 || destIdx < 0) return false;

    final srcAgent = state.agents[srcIdx];
    final destAgent = state.agents[destIdx];

    final srcHeld = Map<String, int>.from(srcAgent.heldStock);
    final srcAvailable = srcHeld[sku] ?? 0;
    if (srcAvailable < units) return false;

    final destHeld = Map<String, int>.from(destAgent.heldStock);

    // Update quantities
    final newSrcQty = srcAvailable - units;
    if (newSrcQty > 0) {
      srcHeld[sku] = newSrcQty;
    } else {
      srcHeld.remove(sku);
    }
    destHeld[sku] = (destHeld[sku] ?? 0) + units;

    final updatedSrc = srcAgent.copyWith(heldStock: srcHeld, lastBalancedAt: DateTime.now());
    final updatedDest = destAgent.copyWith(heldStock: destHeld, lastBalancedAt: DateTime.now());

    final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
    updatedAgents[srcIdx] = updatedSrc;
    updatedAgents[destIdx] = updatedDest;

    // Update agent breakdown in global stock
    final updatedGlobalStock = state.globalStock.map((prod) {
      if (prod.sku.toLowerCase() == sku.toLowerCase() || prod.productName.toLowerCase() == sku.toLowerCase() || prod.id == sku) {
        final updatedBreakdown = Map<String, int>.from(prod.agentStockBreakdown);
        if (newSrcQty > 0) {
          updatedBreakdown[srcAgent.name] = newSrcQty;
        } else {
          updatedBreakdown.remove(srcAgent.name);
        }
        updatedBreakdown[destAgent.name] = (updatedBreakdown[destAgent.name] ?? 0) + units;
        return prod.copyWith(agentStockBreakdown: updatedBreakdown);
      }
      return prod;
    }).toList();

    state = state.copyWith(
      agents: updatedAgents,
      globalStock: updatedGlobalStock,
    );

    // Persist both agents
    await _dataSource.updateLogisticsAgent(updatedSrc);
    await _dataSource.updateLogisticsAgent(updatedDest);

    // Log ledger entry
    final targetClientId = destAgent.assignedMerchantIds.isNotEmpty
        ? destAgent.assignedMerchantIds.first
        : '00000000-0000-4000-8000-791731264594';

    await _dataSource.persistStockLedgerEntry(
      clientId: targetClientId,
      warehouse: destAgent.assignedWarehouseName ?? 'Abuja Central DC',
      itemCode: sku,
      itemName: sku,
      itemGroup: 'Inter-Agent Transfer',
      voucherType: 'agent_reallocation',
      voucherNo: 'REALLOC-${DateTime.now().millisecondsSinceEpoch}',
      qtyChange: units.toDouble(),
      incomingQty: units.toDouble(),
      outgoingQty: 0.0,
      valuationRate: 15000.0,
      totalValue: units * 15000.0,
      notes: 'Transferred $units units of $sku from ${srcAgent.name} (${srcAgent.agentCode}) to ${destAgent.name} (${destAgent.agentCode}) by $operatorName. ${reason ?? ""}',
    );

    _logAudit(
      action: 'REALLOCATE_AGENT_STOCK',
      resource: 'Inventory',
      details: 'Transferred $units units of $sku from ${srcAgent.name} to ${destAgent.name} by $operatorName',
      distributionCenterId: destAgent.assignedWarehouseId,
      distributionCenterName: destAgent.assignedWarehouseName,
    );

    return true;
  }

  /// Assign an agent to multiple merchants
  Future<void> assignAgentToMerchants({
    required String agentId,
    required List<String> merchantIds,
    required List<String> merchantNames,
  }) async {
    final idx = state.agents.indexWhere((a) => a.id == agentId || a.agentCode == agentId);
    if (idx >= 0) {
      final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
      final agent = updatedAgents[idx];
      final newAgent = agent.copyWith(
        assignedMerchantIds: merchantIds,
        assignedMerchantNames: merchantNames,
      );
      updatedAgents[idx] = newAgent;

      final updatedMerchants = state.merchants.map((m) {
        final shouldBeAssigned = merchantIds.contains(m.id) ||
            merchantNames.any((n) =>
                n.toLowerCase() == m.businessName.toLowerCase() ||
                n.toLowerCase().contains(m.businessName.toLowerCase()) ||
                m.businessName.toLowerCase().contains(n.toLowerCase()));
        final currentAgentIds = List<String>.from(m.assignedAgentIds);
        final currentAgentNames = List<String>.from(m.assignedAgentNames);
        if (shouldBeAssigned) {
          if (!currentAgentIds.contains(agent.id)) currentAgentIds.add(agent.id);
          if (!currentAgentNames.contains(agent.name)) currentAgentNames.add(agent.name);
        } else {
          currentAgentIds.remove(agent.id);
          currentAgentNames.remove(agent.name);
        }
        return m.copyWith(
          assignedAgentIds: currentAgentIds,
          assignedAgentNames: currentAgentNames,
        );
      }).toList();

      state = state.copyWith(agents: updatedAgents, merchants: updatedMerchants);

      await _dataSource.updateLogisticsAgent(updatedAgents[idx]);

      _logAudit(
        action: 'ASSIGN_AGENT_MERCHANTS',
        resource: 'Logistics Agents',
        details:
            'Assigned agent ${agent.name} to merchants: ${merchantNames.isEmpty ? "None" : merchantNames.join(", ")}',
        distributionCenterId: agent.assignedWarehouseId,
        distributionCenterName: agent.assignedWarehouseName,
      );
    }
  }

  /// Unassign an agent from a specific merchant
  Future<void> unassignAgentFromMerchant({
    required String agentId,
    required String merchantId,
  }) async {
    final idx = state.agents.indexWhere((a) => a.id == agentId || a.agentCode == agentId);
    if (idx >= 0) {
      final updatedAgents = List<AdminLogisticsAgent>.from(state.agents);
      final agent = updatedAgents[idx];
      final newMIds = List<String>.from(agent.assignedMerchantIds)..remove(merchantId);
      final merchant = state.merchants.firstWhere(
        (m) => m.id == merchantId,
        orElse: () => const AdminMerchant(id: '', businessName: '', contactName: '', phone: '', email: ''),
      );
      final newMNames = List<String>.from(agent.assignedMerchantNames)..remove(merchant.businessName);

      updatedAgents[idx] = agent.copyWith(
        assignedMerchantIds: newMIds,
        assignedMerchantNames: newMNames,
      );

      final updatedMerchants = state.merchants.map((m) {
        if (m.id == merchantId) {
          final newAgentIds = List<String>.from(m.assignedAgentIds)..remove(agent.id);
          final newAgentNames = List<String>.from(m.assignedAgentNames)..remove(agent.name);
          return m.copyWith(assignedAgentIds: newAgentIds, assignedAgentNames: newAgentNames);
        }
        return m;
      }).toList();

      state = state.copyWith(agents: updatedAgents, merchants: updatedMerchants);

      await _dataSource.updateLogisticsAgent(updatedAgents[idx]);

      _logAudit(
        action: 'UNASSIGN_AGENT_MERCHANT',
        resource: 'Logistics Agents',
        details: 'Unassigned agent ${agent.name} from merchant ${merchant.businessName}',
        distributionCenterId: agent.assignedWarehouseId,
        distributionCenterName: agent.assignedWarehouseName,
      );
    }
  }

  /// Record a verified daily sale for an agent, decrement their stock custody,
  /// persist locally & remotely, update network stock metrics, and write audit trail.
  Future<void> recordAgentDailySale(AgentDailySaleRecord sale) async {
    // 1. Locate the selling agent
    final agentIndex = state.agents.indexWhere(
      (a) => a.id == sale.agentId || a.agentCode == sale.agentCode,
    );

    AdminLogisticsAgent? updatedAgent;
    List<AdminLogisticsAgent> updatedAgents = List.from(state.agents);

    if (agentIndex >= 0) {
      final agent = state.agents[agentIndex];
      final newHeldStock = Map<String, int>.from(agent.heldStock);

      for (final item in sale.items) {
        final currentQty = newHeldStock[item.sku] ??
            newHeldStock[item.productName] ??
            0;
        final netBalanced = currentQty + sale.replenishedUnits - item.quantity - sale.returnedUnits;
        final newQty = netBalanced > 0 ? netBalanced : 0;
        newHeldStock[item.sku] = newQty;
      }

      updatedAgent = agent.copyWith(
        heldStock: newHeldStock,
        totalDeliveries: agent.totalDeliveries + 1,
        totalRemittedNaira: agent.totalRemittedNaira + sale.totalAmount,
        lastBalancedAt: DateTime.now(),
      );
      updatedAgents[agentIndex] = updatedAgent;
    }

    // 2. Decrement rider custody in globalStock, and deduct any DC replenishment from warehouse shelves
    final targetDc = sale.dcName ?? 'Abuja Central DC';
    final updatedGlobalStock = state.globalStock.map((prod) {
      final saleItem = sale.items.cast<AgentDailySaleItem?>().firstWhere(
            (i) => i?.sku.toLowerCase() == prod.sku.toLowerCase() ||
                i?.productName.toLowerCase() == prod.productName.toLowerCase(),
            orElse: () => null,
          );
      if (saleItem != null && (saleItem.quantity > 0 || sale.replenishedUnits > 0)) {
        final newBreakdown = Map<String, int>.from(prod.agentStockBreakdown);
        if (updatedAgent != null) {
          final curAgentHeld = updatedAgent.heldStock[prod.sku] ??
              updatedAgent.heldStock[prod.productName] ??
              0;
          if (curAgentHeld > 0) {
            newBreakdown[updatedAgent.name] = curAgentHeld;
          } else {
            newBreakdown.remove(updatedAgent.name);
          }
        }

        // Deduct DC replenishment from warehouse shelf if replenished
        final newDcBreakdown = Map<String, int>.from(prod.dcStockBreakdown);
        int newWhStock = prod.totalWarehouseStock;
        if (sale.replenishedUnits > 0) {
          final currentDcQty = newDcBreakdown[targetDc] ?? 0;
          final decrementedDc = (currentDcQty - sale.replenishedUnits) > 0
              ? (currentDcQty - sale.replenishedUnits)
              : 0;
          newDcBreakdown[targetDc] = decrementedDc;
          newWhStock = newDcBreakdown.values.fold(0, (sum, q) => sum + q);
        }

        int newCustodyTotal = 0;
        for (final a in updatedAgents) {
          newCustodyTotal += (a.heldStock[prod.sku] ?? a.heldStock[prod.productName] ?? 0);
        }

        return prod.copyWith(
          agentStockBreakdown: newBreakdown,
          dcStockBreakdown: newDcBreakdown,
          totalWarehouseStock: newWhStock,
          totalRiderCustodyStock: newCustodyTotal,
          totalStock: newWhStock + newCustodyTotal,
        );
      }
      return prod;
    }).toList();

    // 3. Update state with new sale log, updated agent, and updated stock
    final updatedDailySales = [sale, ...state.dailySales];
    state = state.copyWith(
      dailySales: updatedDailySales,
      agents: updatedAgents,
      globalStock: updatedGlobalStock,
    );

    // 4. Persist updated agent custody and ledger movements
    if (updatedAgent != null) {
      await _dataSource.updateLogisticsAgent(updatedAgent);
    }

    final resolvedMerchantId = (sale.merchantId != null && sale.merchantId!.isNotEmpty)
        ? sale.merchantId!
        : (updatedAgent?.assignedMerchantIds.isNotEmpty == true
            ? updatedAgent!.assignedMerchantIds.first
            : '00000000-0000-4000-8000-791731264594');
    final resolvedWarehouse =
        sale.dcName ?? updatedAgent?.assignedWarehouseName ?? 'Abuja Central DC';

    // Persist ledger entries for each item sold
    for (final item in sale.items) {
      if (item.quantity > 0) {
        _dataSource.persistStockLedgerEntry(
          clientId: resolvedMerchantId,
          warehouse: resolvedWarehouse,
          itemCode: item.sku,
          itemName: item.productName,
          itemGroup: sale.merchantName ?? 'Client Goods',
          voucherType: 'sales_order_delivery',
          voucherNo: sale.orderReference,
          qtyChange: -(item.quantity.toDouble()),
          incomingQty: 0.0,
          outgoingQty: item.quantity.toDouble(),
          valuationRate: item.unitPrice,
          totalValue: item.subtotal,
          notes:
              'Delivered sale by ${sale.agentName} (${sale.agentCode}) to ${sale.customerName} (${sale.deliveryLocation}) • Logged by ${sale.loggedBy}',
        );
      }
    }

    // If DC replenishment units were supplied, record inbound to agent and update DC balance
    if (sale.replenishedUnits > 0 && sale.items.isNotEmpty) {
      final primaryItem = sale.items.first;
      _dataSource.persistStockLedgerEntry(
        clientId: resolvedMerchantId,
        warehouse: resolvedWarehouse,
        itemCode: primaryItem.sku,
        itemName: primaryItem.productName,
        itemGroup: sale.merchantName ?? 'Client Goods',
        voucherType: 'purchase_receipt',
        voucherNo: 'REPL-${sale.orderReference}',
        qtyChange: sale.replenishedUnits.toDouble(),
        incomingQty: sale.replenishedUnits.toDouble(),
        outgoingQty: 0.0,
        valuationRate: primaryItem.unitPrice,
        totalValue: sale.replenishedUnits * primaryItem.unitPrice,
        notes:
            'DC warehouse replenishment issued to ${sale.agentName} (${sale.agentCode}) • Waybill: ${sale.notes ?? "Standard restock"} • Logged by ${sale.loggedBy}',
      );

      _dataSource.updateClientStockBalance(
        itemCode: primaryItem.sku,
        warehouse: resolvedWarehouse,
        qtyDelta: -(sale.replenishedUnits.toDouble()),
        valuationRate: primaryItem.unitPrice,
      );
    }

    // 5. Persist daily sales list to SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializedList = updatedDailySales.take(200).map((s) => s.toJson()).toList();
      await prefs.setString('nova_agent_daily_sales', jsonEncode(serializedList));
    } catch (e) {
      debugPrint('[AdminConsoleNotifier] Error caching daily sales: $e');
    }

    // 6. Write immutable audit log
    _logAudit(
      action: 'RECORD_AGENT_DAILY_SALE',
      resource: 'Daily Sales & Custody',
      details:
          'Logged daily sale ${sale.orderReference} for agent ${sale.agentName} (${sale.agentCode}). Sold ${sale.totalUnits} units (₦${sale.totalAmount.toStringAsFixed(2)}). Deducted units from agent physical custody.',
      distributionCenterId: updatedAgent?.assignedWarehouseId,
      distributionCenterName: updatedAgent?.assignedWarehouseName,
    );
  }

  Future<void> createDistributionCenterBranch({
    required String name,
    required String code,
    required String city,
    required String stateName,
    required String address,
    required String supervisorName,
    required int capacity,
    List<String> assignedAgents = const [],
  }) async {
    final newDc = AdminDistributionCenter(
      id: 'DC-${code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')}',
      code: code,
      name: name,
      city: city,
      state: stateName,
      address: address,
      supervisorName: supervisorName,
      capacity: capacity,
      activeRiders: 0,
      currentStockCount: 0,
      vaultBalance: 0.0,
      status: 'operational',
      isGrandDc: false,
      assignedAgentNames: assignedAgents,
    );

    saveDistributionCenter(newDc);
  }

  void approveMerchant(String merchantId) {
    final idx = state.merchants.indexWhere((m) => m.id == merchantId);
    if (idx >= 0) {
      final updated = List<AdminMerchant>.from(state.merchants);
      updated[idx] = updated[idx].copyWith(status: 'active');
      state = state.copyWith(merchants: updated);
      _logAudit(
        action: 'APPROVE_MERCHANT',
        resource: 'Merchants',
        details:
            'Approved merchant ${updated[idx].businessName} to go live on NovaXpress Platform',
      );
    }
  }

  void rejectMerchant(String merchantId) {
    final idx = state.merchants.indexWhere((m) => m.id == merchantId);
    if (idx >= 0) {
      final updated = List<AdminMerchant>.from(state.merchants);
      final bizName = updated[idx].businessName;
      updated.removeAt(idx);
      state = state.copyWith(merchants: updated);
      _logAudit(
        action: 'REJECT_MERCHANT',
        resource: 'Merchants',
        details: 'Rejected merchant registration for $bizName',
      );
    }
  }

  void approveAgent(String agentId) {
    final idx = state.agents.indexWhere((a) => a.id == agentId);
    if (idx >= 0) {
      final updated = List<AdminLogisticsAgent>.from(state.agents);
      updated[idx] = updated[idx].copyWith(status: 'active');
      state = state.copyWith(agents: updated);
      _logAudit(
        action: 'APPROVE_LOGISTICS_AGENT',
        resource: 'Logistics Agents',
        details:
            'Approved agent ${updated[idx].name} to begin dispatching on NovaXpress Network',
      );
    }
  }

  void suspendAgent(String agentId) {
    final idx = state.agents.indexWhere((a) => a.id == agentId);
    if (idx >= 0) {
      final updated = List<AdminLogisticsAgent>.from(state.agents);
      final newStatus =
          updated[idx].status == 'active' ? 'suspended' : 'active';
      updated[idx] = updated[idx].copyWith(status: newStatus);
      state = state.copyWith(agents: updated);
      _logAudit(
        action: newStatus == 'suspended'
            ? 'SUSPEND_LOGISTICS_AGENT'
            : 'ACTIVATE_LOGISTICS_AGENT',
        resource: 'Logistics Agents',
        details: 'Changed status of agent ${updated[idx].name} to $newStatus',
      );
    }
  }

  void toggleAgentStatus(String agentId) => suspendAgent(agentId);

  Future<void> assignMerchantsToAgent({
    required String agentId,
    required List<String> merchantIds,
    List<String>? merchantNames,
  }) async {
    final mNames = merchantNames ??
        state.merchants
            .where((m) => merchantIds.contains(m.id))
            .map((m) => m.businessName)
            .toList();
    await assignAgentToMerchants(
      agentId: agentId,
      merchantIds: merchantIds,
      merchantNames: mNames,
    );
  }

  void triggerDaily10pmSettlement() {
    final updatedSettlements = List<AdminSettlementReconciliation>.from(
        state.settlementReconciliations);
    final todayIdx =
        updatedSettlements.indexWhere((s) => s.status == 'awaiting_cutoff');
    if (todayIdx >= 0) {
      final todayRec = updatedSettlements[todayIdx];
      updatedSettlements[todayIdx] = AdminSettlementReconciliation(
        id: todayRec.id,
        date: todayRec.date,
        totalGrossCodCollected: todayRec.totalGrossCodCollected,
        totalCourierDeliveryFees: todayRec.totalCourierDeliveryFees,
        totalFuelAllowances: todayRec.totalFuelAllowances,
        totalPlatformCommissions: todayRec.totalPlatformCommissions,
        totalNetMerchantPayout: todayRec.totalNetMerchantPayout,
        totalOrdersSettled: todayRec.totalOrdersSettled,
        participatingAgentsCount: todayRec.participatingAgentsCount,
        participatingMerchantsCount: todayRec.participatingMerchantsCount,
        status: 'settled',
        settledAt: DateTime.now(),
      );
      state = state.copyWith(settlementReconciliations: updatedSettlements);
      _logAudit(
        action: 'EXECUTE_10PM_SETTLEMENT',
        resource: 'Settlements',
        details:
            'Reconciled and settled ₦${todayRec.totalNetMerchantPayout.toStringAsFixed(0)} net merchant payouts across ${todayRec.participatingMerchantsCount} merchants on or before 10pm cut-off',
      );
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final usersFuture = _dataSource.fetchUsers();
      final dcsFuture = _dataSource.fetchDistributionCenters();
      final merchantsFuture = _dataSource.fetchMerchants();
      final agentsFuture = _dataSource.fetchLogisticsAgents();
      final globalStockFuture = _dataSource.fetchGlobalStock();
      final auditLogsFuture = _dataSource.fetchAuditLogs();
      final pingFuture = _dataSource.pingDatabase();

      final users = await usersFuture;
      final dcs = await dcsFuture;
      final merchants = await merchantsFuture;
      final agents = await agentsFuture;
      final globalStock = await globalStockFuture;
      final auditLogs = await auditLogsFuture;
      final pingMs = await pingFuture;

      if (!mounted) return;

      final activeAgents = agents.isNotEmpty
          ? agents
          : state.agents;
      final rawStock = globalStock.isNotEmpty
          ? globalStock
          : state.globalStock;

      // Synchronize merchants with activeAgents
      final syncedMerchants = merchants.map((m) {
        final servingAgents = activeAgents.where((a) =>
            a.assignedMerchantIds.contains(m.id) ||
            a.assignedMerchantNames.any((n) =>
                n.toLowerCase() == m.businessName.toLowerCase() ||
                n.toLowerCase().contains(m.businessName.toLowerCase()) ||
                m.businessName.toLowerCase().contains(n.toLowerCase()))).toList();

        if (servingAgents.isNotEmpty) {
          final sAgentIds = servingAgents.map((a) => a.id).toSet().toList();
          final sAgentNames = servingAgents.map((a) => a.name).toSet().toList();
          return m.copyWith(
            assignedAgentIds: sAgentIds,
            assignedAgentNames: sAgentNames,
          );
        }
        return m;
      }).toList();

      // Ensure activeAgents have clean merchant business names
      final syncedAgents = activeAgents.map((a) {
        if (a.assignedMerchantIds.isNotEmpty && a.assignedMerchantNames.isEmpty) {
          final mNames = a.assignedMerchantIds.map((mId) {
            final match = syncedMerchants.cast<AdminMerchant?>().firstWhere(
                  (m) => m?.id == mId,
                  orElse: () => null,
                );
            if (match != null) return match.businessName;
            if (mId.toLowerCase().contains('novacare')) return 'Novacare Limited';
            if (mId.toLowerCase().contains('shop') || mId.toLowerCase().contains('eleven')) return 'Shop Eleven Limited';
            if (mId.toLowerCase().contains('leafora')) return 'Leafora Direct';
            return mId;
          }).toList();
          return a.copyWith(assignedMerchantNames: mNames);
        }
        return a;
      }).toList();

      // Synchronize agent held custody into global stock metrics
      final synchronizedStock = rawStock.map((prod) {
        final agentBreakdown = <String, int>{};
        int custodyTotal = 0;
        for (final a in syncedAgents) {
          final q = a.heldStock[prod.sku] ??
              a.heldStock[prod.id] ??
              a.heldStock[prod.productName] ??
              0;
          if (q > 0) {
            agentBreakdown[a.name] = q;
            custodyTotal += q;
          }
        }
        return prod.copyWith(
          agentStockBreakdown: agentBreakdown,
          totalRiderCustodyStock: custodyTotal,
          totalStock: prod.totalWarehouseStock + custodyTotal,
        );
      }).toList();

      // Load cached daily sales
      List<AgentDailySaleRecord> cachedDailySales = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawSales = prefs.getString('nova_agent_daily_sales');
        if (rawSales != null) {
          final decoded = jsonDecode(rawSales);
          if (decoded is List) {
            cachedDailySales = decoded
                .map((m) => AgentDailySaleRecord.fromJson(
                    Map<String, dynamic>.from(m as Map)))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('[AdminConsoleNotifier] Error loading cached daily sales: $e');
      }

      state = state.copyWith(
        users: users,
        distributionCenters: dcs,
        merchants: syncedMerchants,
        agents: syncedAgents,
        globalStock: synchronizedStock,
        dailySales: cachedDailySales.isNotEmpty ? cachedDailySales : state.dailySales,
        expenses: state.expenses,
        settlementReconciliations: state.settlementReconciliations,
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
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Delete user permanently from database and session records
  Future<bool> deleteUser(String userId) async {
    final success = await _dataSource.deleteUser(userId);
    final user = state.users.where((u) => u.id == userId).firstOrNull;
    final updatedList = state.users.where((u) => u.id != userId).toList();
    state = state.copyWith(users: updatedList);
    _logAudit(
      action: 'DELETE_USER',
      resource: 'Users',
      details: 'Permanently deleted user ${user?.fullName ?? userId} (${user?.email ?? ''})',
    );
    return success;
  }

  /// Delete product from database and active inventory balances
  Future<bool> deleteProduct(String productId, [String? sku]) async {
    final success = await _dataSource.deleteProduct(productId, sku);
    final item = state.globalStock.where((p) => p.productId == productId || p.id == productId).firstOrNull;
    final updatedStock = state.globalStock.where((p) => p.productId != productId && p.id != productId).toList();
    state = state.copyWith(globalStock: updatedStock);
    _logAudit(
      action: 'DELETE_PRODUCT',
      resource: 'Products',
      details: 'Permanently deleted product SKU ${sku ?? item?.sku ?? productId} (${item?.productName ?? ''})',
    );
    return success;
  }

  /// Outright edit and update of product specifications & DC stock allocation
  Future<bool> updateProduct({
    required String productId,
    required String name,
    required String sku,
    required double unitPrice,
    String? merchantId,
    String? merchantName,
    Map<String, int>? dcStocks,
  }) async {
    final success = await _dataSource.updateProduct(
      productId: productId,
      name: name,
      sku: sku,
      unitPrice: unitPrice,
      merchantId: merchantId,
      merchantName: merchantName,
      dcStocks: dcStocks,
    );

    final updatedStock = state.globalStock.map((p) {
      if (p.productId == productId || p.id == productId) {
        final newDcBreakdown = dcStocks != null ? Map<String, int>.from(dcStocks) : p.dcStockBreakdown;
        final totalWh = newDcBreakdown.values.fold(0, (s, q) => s + q);
        return p.copyWith(
          productName: name,
          sku: sku,
          unitPrice: unitPrice,
          merchantId: merchantId ?? p.merchantId,
          merchantName: merchantName ?? p.merchantName,
          dcStockBreakdown: newDcBreakdown,
          totalWarehouseStock: totalWh,
          totalStock: totalWh + p.totalRiderCustodyStock,
        );
      }
      return p;
    }).toList();

    state = state.copyWith(globalStock: updatedStock);
    _logAudit(
      action: 'UPDATE_PRODUCT',
      resource: 'Products',
      details: 'Updated product specifications for $name ($sku) - ${CurrencyFormatter.formatNaira(unitPrice)}',
    );
    return success;
  }

  /// Delete logistics agent / 3PL from delivery_agents table
  Future<bool> deleteLogisticsAgent(String agentId, [String? agentCode]) async {
    final success = await _dataSource.deleteLogisticsAgent(agentId, agentCode);
    final agent = state.agents.where((a) => a.id == agentId || (agentCode != null && a.agentCode == agentCode)).firstOrNull;
    final updatedAgents = state.agents.where((a) => a.id != agentId && (agentCode == null || a.agentCode != agentCode)).toList();
    state = state.copyWith(agents: updatedAgents);
    _logAudit(
      action: 'DELETE_AGENT',
      resource: 'DeliveryAgents',
      details: 'Permanently removed logistics partner ${agent?.name ?? agentId} (${agent?.agentCode ?? ''})',
    );
    return success;
  }

  /// Delete distribution center
  Future<bool> deleteDistributionCenter(String dcId) async {
    final success = await _dataSource.deleteDistributionCenter(dcId);
    final dc = state.distributionCenters.where((d) => d.id == dcId).firstOrNull;
    final updatedList = state.distributionCenters.where((d) => d.id != dcId).toList();
    state = state.copyWith(distributionCenters: updatedList);
    _logAudit(
      action: 'DELETE_DC',
      resource: 'DistributionCenters',
      details: 'Decommissioned distribution center ${dc?.name ?? dcId} (${dc?.code ?? ''})',
    );
    return success;
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
      details:
          '${currentUser.fullName} (${currentUser.role}) set to $newStatus',
    );

    await _dataSource.updateUserStatus(userId, newStatus);
  }

  Future<void> saveUser(AdminUserItem user, [String? password]) async {
    final assignedPassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : 'Password123!';

    // Persist to Supabase Auth, public.users table, in-memory, and local storage
    final persistedUser = await _dataSource.onboardUser(
      user: user,
      password: assignedPassword,
    );

    final existingIndex = state.users.indexWhere((u) =>
        u.id == user.id ||
        u.email.toLowerCase() == user.email.toLowerCase());
    final updatedList = List<AdminUserItem>.from(state.users);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = persistedUser;
      _logAudit(
        action: 'UPDATE_USER',
        resource: 'Users',
        details: 'Updated role/details for ${persistedUser.fullName} (${persistedUser.role})',
      );
    } else {
      updatedList.insert(0, persistedUser);
      _logAudit(
        action: 'CREATE_USER',
        resource: 'Users',
        details: 'Onboarded user ${persistedUser.fullName} with role ${persistedUser.role}',
      );
    }

    state = state.copyWith(users: updatedList);

    await _dataSource.updateUserRoleAndHub(
      persistedUser.id,
      persistedUser.role,
      persistedUser.distributionCenterId,
      persistedUser.distributionCenterName,
    );
  }

  Future<void> saveDistributionCenter(AdminDistributionCenter dc) async {
    final existingIndex =
        state.distributionCenters.indexWhere((d) => d.id == dc.id);
    final updatedList =
        List<AdminDistributionCenter>.from(state.distributionCenters);

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
    await _dataSource.updateDistributionCenter(dc);
  }

  void saveMerchant(AdminMerchant merchant) {
    final existingIndex =
        state.merchants.indexWhere((m) => m.id == merchant.id);
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
        details:
            'Onboarded merchant ${merchant.businessName} (Tier: ${merchant.tier})',
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
    final existingIndex =
        state.routingTariffs.indexWhere((t) => t.stateName == tariff.stateName);
    final updatedList = List<AdminRoutingTariff>.from(state.routingTariffs);

    if (existingIndex >= 0) {
      updatedList[existingIndex] = tariff;
      _logAudit(
        action: 'UPDATE_TARIFF',
        resource: 'RoutingTariff',
        details:
            'Updated rate card and rider commission for ${tariff.stateName}',
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
    if (!mounted) return;
    dynamic currentUser;
    try {
      currentUser = _ref.read(authProvider).user;
    } catch (_) {}

    final effectiveActorName = actorName ?? (currentUser != null && currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Operations Controller');
    final effectiveActorEmail = actorEmail ?? (currentUser != null && currentUser.email.isNotEmpty ? currentUser.email : 'operations@novaxpress.ng');
    final effectiveActorRole = actorRole ?? (currentUser != null && currentUser.role.isNotEmpty ? currentUser.role : 'super_admin');

    final newLog = AdminAuditLog(
      id: UuidHelper.generate(),
      timestamp: DateTime.now(),
      actorName: effectiveActorName,
      actorEmail: effectiveActorEmail,
      actorRole: effectiveActorRole,
      action: action,
      resource: resource,
      details: details,
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
    );
    if (!mounted) return;
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
  return AdminConsoleNotifier(dataSource, ref);
});
