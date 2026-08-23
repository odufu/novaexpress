import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../../domain/entities/dc_transaction_record.dart';

class DCWarehouseBatch {
  final String id;
  final String batchCode;
  final String productName;
  final String sku;
  final String clientName;
  final String waybillNumber;
  final int initialQuantity;
  final int currentQuantity;
  final int allocatedQuantity;
  final String binLocation;
  final DateTime manufactureDate;
  final DateTime expiryDate;
  final String status; // 'good', 'expiring_soon', 'expired'

  const DCWarehouseBatch({
    required this.id,
    required this.batchCode,
    required this.productName,
    required this.sku,
    required this.clientName,
    required this.waybillNumber,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.allocatedQuantity,
    required this.binLocation,
    required this.manufactureDate,
    required this.expiryDate,
    this.status = 'good',
  });

  int get availableQuantity => (currentQuantity - allocatedQuantity).clamp(0, currentQuantity);
  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;

  factory DCWarehouseBatch.fromJson(Map<String, dynamic> json) {
    return DCWarehouseBatch(
      id: json['id']?.toString() ?? '',
      batchCode: json['batch_code']?.toString() ?? json['batchCode'] ?? 'LOT-001',
      productName: json['product_name']?.toString() ?? json['productName'] ?? (json['products'] is Map ? json['products']['name']?.toString() : null) ?? 'Respira Detox Tea',
      sku: json['sku']?.toString() ?? (json['products'] is Map ? json['products']['sku']?.toString() : null) ?? 'SKU-RESP-01',
      clientName: json['client_name']?.toString() ?? json['clientName'] ?? 'NovaCare Labs',
      waybillNumber: json['waybill_number']?.toString() ?? json['waybillNumber'] ?? 'WB-001',
      initialQuantity: (json['initial_quantity'] as num?)?.toInt() ?? (json['initialQuantity'] as num?)?.toInt() ?? 100,
      currentQuantity: (json['current_quantity'] as num?)?.toInt() ?? (json['currentQuantity'] as num?)?.toInt() ?? 100,
      allocatedQuantity: (json['allocated_quantity'] as num?)?.toInt() ?? (json['allocatedQuantity'] as num?)?.toInt() ?? 0,
      binLocation: json['bin_location']?.toString() ?? json['binLocation'] ?? 'A1-B2',
      manufactureDate: json['manufacture_date'] != null ? DateTime.tryParse(json['manufacture_date'].toString()) ?? DateTime.now() : (json['manufactureDate'] != null ? DateTime.tryParse(json['manufactureDate'].toString()) ?? DateTime.now() : DateTime.now()),
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'].toString()) ?? DateTime.now().add(const Duration(days: 365)) : (json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'].toString()) ?? DateTime.now().add(const Duration(days: 365)) : DateTime.now().add(const Duration(days: 365))),
      status: json['status']?.toString() ?? 'good',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_code': batchCode,
      'product_name': productName,
      'sku': sku,
      'client_name': clientName,
      'waybill_number': waybillNumber,
      'initial_quantity': initialQuantity,
      'current_quantity': currentQuantity,
      'allocated_quantity': allocatedQuantity,
      'bin_location': binLocation,
      'manufacture_date': manufactureDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'status': status,
    };
  }
}

class DCReturnItem {
  final String id;
  final String returnTicketNumber;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String productName;
  final int quantity;
  final double amount;
  final String riderName;
  final String returnReason;
  final String qcStatus; // 'pending_qc', 'grade_a_restocked', 'grade_b_scrapped'
  final String? targetBin;
  final DateTime returnedAt;

  const DCReturnItem({
    required this.id,
    required this.returnTicketNumber,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.productName,
    required this.quantity,
    required this.amount,
    required this.riderName,
    required this.returnReason,
    this.qcStatus = 'pending_qc',
    this.targetBin,
    required this.returnedAt,
  });

  DCReturnItem copyWith({
    String? qcStatus,
    String? targetBin,
  }) {
    return DCReturnItem(
      id: id,
      returnTicketNumber: returnTicketNumber,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      productName: productName,
      quantity: quantity,
      amount: amount,
      riderName: riderName,
      returnReason: returnReason,
      qcStatus: qcStatus ?? this.qcStatus,
      targetBin: targetBin ?? this.targetBin,
      returnedAt: returnedAt,
    );
  }

  factory DCReturnItem.fromJson(Map<String, dynamic> json) {
    return DCReturnItem(
      id: json['id']?.toString() ?? '',
      returnTicketNumber: json['return_ticket_number']?.toString() ?? json['returnTicketNumber'] ?? 'RET-001',
      orderNumber: json['order_number']?.toString() ?? json['orderNumber'] ?? 'NX-001',
      customerName: json['customer_name']?.toString() ?? json['customerName'] ?? 'Customer',
      customerPhone: json['customer_phone']?.toString() ?? json['customerPhone'] ?? '',
      productName: json['product_name']?.toString() ?? json['productName'] ?? 'Product',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      riderName: json['rider_name']?.toString() ?? json['riderName'] ?? 'Rider',
      returnReason: json['return_reason']?.toString() ?? json['returnReason'] ?? 'Customer unreachable',
      qcStatus: json['qc_status']?.toString() ?? json['qcStatus'] ?? 'pending_qc',
      targetBin: json['target_bin']?.toString() ?? json['targetBin'],
      returnedAt: json['returned_at'] != null ? DateTime.tryParse(json['returned_at'].toString()) ?? DateTime.now() : (json['returnedAt'] != null ? DateTime.tryParse(json['returnedAt'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'return_ticket_number': returnTicketNumber,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'product_name': productName,
      'quantity': quantity,
      'amount': amount,
      'rider_name': riderName,
      'return_reason': returnReason,
      'qc_status': qcStatus,
      'target_bin': targetBin,
      'returned_at': returnedAt.toIso8601String(),
    };
  }
}

class DCConsoleState {
  final String activeHubId;
  final String activeHubName;
  final String activeHubCode;
  final int activeTabIndex; // 0..6
  final bool isSidebarCollapsed;
  final String searchQuery;
  final String fleetFilter; // 'all', 'active', 'at_rest', 'delayed'
  final List<DCFleetDriver> drivers;
  final List<DCWarehouseBatch> warehouseBatches;
  final List<DCReturnItem> returnItems;
  final List<DCPayoutClaim> payoutClaims;
  final double avgDeliveryTimeMin;
  final double fuelEfficiencyKmPerL;
  final double onScheduleRate;
  final double idleCapacityRate;
  final bool isLoading;
  final String? selectedDriverId;

  const DCConsoleState({
    this.activeHubId = '22222222-2222-4222-8222-222222222222',
    this.activeHubName = 'Wuse Distribution Center',
    this.activeHubCode = 'DC-WUSE-01',
    this.activeTabIndex = 0,
    this.isSidebarCollapsed = false,
    this.searchQuery = '',
    this.fleetFilter = 'all',
    this.drivers = const [],
    this.warehouseBatches = const [],
    this.returnItems = const [],
    this.payoutClaims = const [],
    this.transactions = const [],
    this.transactionFilter = 'all',
    this.transactionStatusFilter = 'all',
    this.avgDeliveryTimeMin = 24.5,
    this.fuelEfficiencyKmPerL = 9.2,
    this.onScheduleRate = 88.0,
    this.idleCapacityRate = 12.0,
    this.isLoading = false,
    this.selectedDriverId,
  });

  final List<DCTransactionRecord> transactions;
  final String transactionFilter; // 'all', 'paystack', 'cash', 'remittance', 'payout'
  final String transactionStatusFilter; // 'all', 'verified', 'pending', 'disbursed'

  DCConsoleState copyWith({
    String? activeHubId,
    String? activeHubName,
    String? activeHubCode,
    int? activeTabIndex,
    bool? isSidebarCollapsed,
    String? searchQuery,
    String? fleetFilter,
    List<DCFleetDriver>? drivers,
    List<DCWarehouseBatch>? warehouseBatches,
    List<DCReturnItem>? returnItems,
    List<DCPayoutClaim>? payoutClaims,
    List<DCTransactionRecord>? transactions,
    String? transactionFilter,
    String? transactionStatusFilter,
    double? avgDeliveryTimeMin,
    double? fuelEfficiencyKmPerL,
    double? onScheduleRate,
    double? idleCapacityRate,
    bool? isLoading,
    String? selectedDriverId,
  }) {
    return DCConsoleState(
      activeHubId: activeHubId ?? this.activeHubId,
      activeHubName: activeHubName ?? this.activeHubName,
      activeHubCode: activeHubCode ?? this.activeHubCode,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      searchQuery: searchQuery ?? this.searchQuery,
      fleetFilter: fleetFilter ?? this.fleetFilter,
      drivers: drivers ?? this.drivers,
      warehouseBatches: warehouseBatches ?? this.warehouseBatches,
      returnItems: returnItems ?? this.returnItems,
      payoutClaims: payoutClaims ?? this.payoutClaims,
      transactions: transactions ?? this.transactions,
      transactionFilter: transactionFilter ?? this.transactionFilter,
      transactionStatusFilter: transactionStatusFilter ?? this.transactionStatusFilter,
      avgDeliveryTimeMin: avgDeliveryTimeMin ?? this.avgDeliveryTimeMin,
      fuelEfficiencyKmPerL: fuelEfficiencyKmPerL ?? this.fuelEfficiencyKmPerL,
      onScheduleRate: onScheduleRate ?? this.onScheduleRate,
      idleCapacityRate: idleCapacityRate ?? this.idleCapacityRate,
      isLoading: isLoading ?? this.isLoading,
      selectedDriverId: selectedDriverId ?? this.selectedDriverId,
    );
  }

  List<DCTransactionRecord> get filteredTransactions {
    var list = transactions;
    if (transactionFilter != 'all') {
      if (transactionFilter == 'paystack') {
        list = list.where((t) => t.isPaystack).toList();
      } else if (transactionFilter == 'cash') {
        list = list.where((t) => t.isCashPod).toList();
      } else if (transactionFilter == 'remittance') {
        list = list.where((t) => t.isRemittance).toList();
      } else if (transactionFilter == 'payout') {
        list = list.where((t) => t.isPayout).toList();
      }
    }

    if (transactionStatusFilter != 'all') {
      if (transactionStatusFilter == 'verified') {
        list = list.where((t) => t.isVerified).toList();
      } else if (transactionStatusFilter == 'pending') {
        list = list.where((t) => t.isPending).toList();
      }
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((t) =>
          t.transactionCode.toLowerCase().contains(q) ||
          (t.orderNumber != null && t.orderNumber!.toLowerCase().contains(q)) ||
          (t.productName != null && t.productName!.toLowerCase().contains(q)) ||
          (t.customerName != null && t.customerName!.toLowerCase().contains(q)) ||
          (t.customerPhone != null && t.customerPhone!.toLowerCase().contains(q)) ||
          t.riderName.toLowerCase().contains(q) ||
          t.riderCode.toLowerCase().contains(q) ||
          (t.gatewayReference != null && t.gatewayReference!.toLowerCase().contains(q))).toList();
    }
    return list;
  }

  List<DCFleetDriver> get filteredDrivers {
    var list = drivers;
    if (fleetFilter != 'all') {
      list = list.where((d) => d.status.toLowerCase() == fleetFilter.toLowerCase()).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.driverCode.toLowerCase().contains(q) ||
          d.vehicleModel.toLowerCase().contains(q) ||
          d.assignedZone.toLowerCase().contains(q)).toList();
    }
    return list;
  }
}

class DCConsoleNotifier extends StateNotifier<DCConsoleState> {
  final LocalStorageService _storageService;

  DCConsoleNotifier([LocalStorageService? storageService])
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(const DCConsoleState()) {
    _initDrivers();
  }

  Future<void> _initDrivers() async {
    // 1. Instant hydration from persistent local cache
    final cached = await _storageService.getCachedFleetDrivers();
    final cachedBatches = await _storageService.getCachedWarehouseBatches();
    final cachedReturns = await _storageService.getCachedReturnItems();
    final cachedPayouts = await _storageService.getCachedPayoutClaims();
    final cachedTxns = await _storageService.getCachedDcTransactions();

    state = state.copyWith(
      drivers: cached ?? state.drivers,
      warehouseBatches: cachedBatches ?? state.warehouseBatches,
      returnItems: cachedReturns ?? state.returnItems,
      payoutClaims: cachedPayouts ?? state.payoutClaims,
      transactions: cachedTxns ?? state.transactions,
    );

    if (cached != null && cached.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cached.length} drivers from local storage cache.');
    }
    if (cachedPayouts != null && cachedPayouts.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cachedPayouts.length} payout claims from local storage cache.');
    }
    if (cachedTxns != null && cachedTxns.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cachedTxns.length} DC transactions from local storage cache.');
    }

    // 2. Fetch fresh real data from live Supabase DB
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (!isTest) {
      await loadDriversFromDatabase();
      await loadPayoutClaimsFromDatabase();
      await loadTransactionsFromDatabase();
    }
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarCollapsed: !state.isSidebarCollapsed);
  }

  void setSidebarCollapsed(bool collapsed) {
    state = state.copyWith(isSidebarCollapsed: collapsed);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFleetFilter(String filter) {
    state = state.copyWith(fleetFilter: filter);
  }

  void selectDriver(String? driverId) {
    state = state.copyWith(selectedDriverId: driverId);
  }

  void switchHub(String hubName, String hubCode, String hubId) {
    state = state.copyWith(
      activeHubName: hubName,
      activeHubCode: hubCode,
      activeHubId: hubId,
    );
  }

  void addBatch(DCWarehouseBatch batch) {
    final updated = [batch, ...state.warehouseBatches];
    state = state.copyWith(warehouseBatches: updated);
    _storageService.cacheWarehouseBatches(updated);
  }

  void addDriver(DCFleetDriver driver) {
    final updated = [
      driver,
      ...state.drivers.where((d) => d.id != driver.id && d.driverCode != driver.driverCode && (driver.email.isEmpty || d.email != driver.email)),
    ];
    state = state.copyWith(drivers: updated);
    _storageService.cacheFleetDrivers(updated);
  }

  Future<void> loadDriversFromDatabase() async {
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (isTest) return;

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final response = await dbClient
          .from(SupabaseConstants.deliveryAgentsTable)
          .select('*, users(first_name, last_name, email, phone_number, avatar_url)')
          .order('created_at', ascending: false);

      final List<DCFleetDriver> dbDrivers = [];
      for (final item in response as List) {
        try {
          final driver = DCFleetDriver.fromJson(item as Map<String, dynamic>);
          dbDrivers.add(driver);
        } catch (parseErr) {
          debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Parse notice for driver row: $parseErr');
        }
      }

      if (dbDrivers.isNotEmpty) {
        final Map<String, DCFleetDriver> driverMap = {};
        // 1. Keep any newly added local drivers that aren't yet loaded
        for (final d in state.drivers) {
          final key = d.email.isNotEmpty ? d.email.toLowerCase() : d.driverCode;
          driverMap[key] = d;
        }
        // 2. Overlay / update with authoritative DB drivers
        for (final d in dbDrivers) {
          final key = d.email.isNotEmpty ? d.email.toLowerCase() : d.driverCode;
          driverMap[key] = d;
        }
        final mergedList = driverMap.values.toList();

        state = state.copyWith(drivers: mergedList, isLoading: false);
        await _storageService.cacheFleetDrivers(mergedList);
        debugPrint('[DC_CONSOLE_PROVIDER] 🚚 Loaded ${dbDrivers.length} active fleet drivers from live Supabase DB (Total active fleet: ${mergedList.length}) and updated local cache.');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supabase fleet fetch notice ($e). Local cached drivers retained.');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> loadPayoutClaimsFromDatabase() async {
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (isTest) return;

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final response = await dbClient
          .from('payout_requests')
          .select('*, delivery_agents(agent_code, current_cod_balance, direct_transfer_balance, users(first_name, last_name, email, phone))')
          .order('created_at', ascending: false);

      final List<DCPayoutClaim> dbClaims = [];
      for (final item in response as List) {
        try {
          final claim = DCPayoutClaim.fromJson(item as Map<String, dynamic>);
          dbClaims.add(claim);
        } catch (parseErr) {
          debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Parse notice for payout claim: $parseErr');
        }
      }

      if (dbClaims.isNotEmpty) {
        state = state.copyWith(payoutClaims: dbClaims);
        await _storageService.cachePayoutClaims(dbClaims);
        debugPrint('[DC_CONSOLE_PROVIDER] 💰 Loaded ${dbClaims.length} live payout claims from Supabase DB.');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supabase payout claims fetch notice ($e).');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> approvePayoutClaim(String claimId, {String? disbursementRef}) async {
    final ref = disbursementRef ?? 'DISB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    
    // 1. Optimistically update local state & cache
    final updated = state.payoutClaims.map((c) {
      if (c.id == claimId) {
        return c.copyWith(status: 'approved', disbursementRef: ref);
      }
      return c;
    }).toList();
    state = state.copyWith(payoutClaims: updated);
    await _storageService.cachePayoutClaims(updated);

    // 2. Persist to live Supabase DB
    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await dbClient
          .from('payout_requests')
          .update({
            'status': 'approved',
            'disbursement_ref': ref,
          })
          .eq('id', claimId);

      // Find claim to notify rider
      final claim = state.payoutClaims.firstWhere((c) => c.id == claimId, orElse: () => updated.first);
      if (claim.riderId.isNotEmpty) {
        try {
          await dbClient.from('notifications').insert({
            'company_id': '11111111-1111-4111-8111-111111111111',
            'delivery_agent_id': claim.riderId,
            'title': 'Payout Claim Approved ✓',
            'message': 'Your withdrawal request of ₦${claim.requestedAmount.toStringAsFixed(0)} (Ref: $ref) has been approved for transfer to ${claim.bankName}.',
            'category': 'finance',
            'action_route': '/cash/history',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Payout claim $claimId approved in live Supabase DB (Ref: $ref).');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Payout approval notice ($e).');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> rejectPayoutClaim(String claimId, {String? reason}) async {
    final note = reason ?? 'Claim rejected by DC supervisor review.';

    // 1. Optimistically update local state & cache
    final updated = state.payoutClaims.map((c) {
      if (c.id == claimId) {
        return c.copyWith(status: 'rejected', dcNotes: note);
      }
      return c;
    }).toList();
    state = state.copyWith(payoutClaims: updated);
    await _storageService.cachePayoutClaims(updated);

    // 2. Persist to live Supabase DB
    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await dbClient
          .from('payout_requests')
          .update({
            'status': 'rejected',
            'dc_notes': note,
          })
          .eq('id', claimId);

      final claim = state.payoutClaims.firstWhere((c) => c.id == claimId, orElse: () => updated.first);
      if (claim.riderId.isNotEmpty) {
        try {
          await dbClient.from('notifications').insert({
            'company_id': '11111111-1111-4111-8111-111111111111',
            'delivery_agent_id': claim.riderId,
            'title': 'Payout Claim Returned ⚠️',
            'message': 'Your withdrawal request of ₦${claim.requestedAmount.toStringAsFixed(0)} requires attention: $note',
            'category': 'finance',
            'action_route': '/cash/history',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Payout claim $claimId marked rejected in Supabase DB.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Payout rejection notice ($e).');
    } finally {
      dbClient?.dispose();
    }
  }

  void setTransactionFilter(String filter) {
    state = state.copyWith(transactionFilter: filter);
  }

  void setTransactionStatusFilter(String filter) {
    state = state.copyWith(transactionStatusFilter: filter);
  }

  Future<void> loadTransactionsFromDatabase() async {
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (isTest) return;

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final List<DCTransactionRecord> allTxns = [];

      // 1. Fetch Paystack Transactions
      try {
        final pstkRes = await dbClient
            .from(SupabaseConstants.paystackTransactionsTable)
            .select('*, delivery_agents(agent_code, current_cod_balance, users(first_name, last_name)), orders(order_number, customer_name, customer_phone, delivery_city, delivery_state, products(name))')
            .order('created_at', ascending: false)
            .limit(50);

        for (final row in (pstkRes as List)) {
          try {
            allTxns.add(DCTransactionRecord.fromJson(row));
          } catch (_) {}
        }
      } catch (_) {}

      // 2. Fetch Rider General Transactions
      try {
        final riderTxnRes = await dbClient
            .from('rider_transactions')
            .select('*, delivery_agents(agent_code, current_cod_balance, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);

        for (final row in (riderTxnRes as List)) {
          try {
            allTxns.add(DCTransactionRecord.fromJson(row));
          } catch (_) {}
        }
      } catch (_) {}

      // 3. Fetch Cash Remittances
      try {
        final remRes = await dbClient
            .from(SupabaseConstants.cashRemittancesTable)
            .select('*, delivery_agents(agent_code, current_cod_balance, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);

        for (final row in (remRes as List)) {
          try {
            final isVerified = row['is_verified'] == true || row['status'] == 'verified';
            allTxns.add(DCTransactionRecord(
              id: row['id']?.toString() ?? '',
              transactionCode: row['remittance_number']?.toString() ?? 'REM-${row['id']?.toString().substring(0, 5)}',
              riderId: row['delivery_agent_id']?.toString() ?? '',
              riderName: (row['delivery_agents'] is Map && row['delivery_agents']['users'] is Map)
                  ? '${row['delivery_agents']['users']['first_name'] ?? ''} ${row['delivery_agents']['users']['last_name'] ?? ''}'.trim()
                  : 'Delivery Agent',
              riderCode: (row['delivery_agents'] is Map) ? row['delivery_agents']['agent_code']?.toString() ?? 'PDA-7000' : 'PDA-7000',
              amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
              category: 'remittance',
              paymentMethod: row['payment_method']?.toString() ?? 'bank_transfer',
              gatewayReference: row['reference_number']?.toString(),
              channel: row['payment_method']?.toString() == 'paystack' ? 'Titan Trust / Paystack' : 'Bank Transfer Handover',
              status: isVerified ? 'verified' : (row['status']?.toString() ?? 'pending'),
              isCredit: false,
              notes: row['notes']?.toString(),
              createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
            ));
          } catch (_) {}
        }
      } catch (_) {}

      // 4. Fetch Delivered / Prepaid Orders
      try {
        final ordersRes = await dbClient
            .from(SupabaseConstants.ordersTable)
            .select('*, products(name), delivery_agents(agent_code, users(first_name, last_name))')
            .or('status.eq.delivered,payment_status.eq.paid')
            .order('updated_at', ascending: false)
            .limit(50);

        for (final ord in (ordersRes as List)) {
          final isPstk = (ord['payment_type']?.toString().contains('direct') == true) ||
              (ord['delivery_notes']?.toString().contains('Paystack') == true) ||
              (ord['delivery_notes']?.toString().contains('Monnify') == true);
          final pMethod = isPstk ? 'paystack' : (ord['payment_type']?.toString() ?? 'cash');

          allTxns.add(DCTransactionRecord(
            id: 'ord-txn-${ord['id']}',
            transactionCode: 'ORD-${ord['order_number']}',
            orderNumber: ord['order_number']?.toString(),
            orderId: ord['id']?.toString(),
            productName: (ord['products'] is Map) ? ord['products']['name']?.toString() : 'Respira Health Formula',
            customerName: ord['customer_name']?.toString(),
            customerPhone: ord['customer_phone']?.toString(),
            deliveryLocation: '${ord['delivery_city'] ?? ''}, ${ord['delivery_state'] ?? ''}'.trim(),
            riderId: ord['delivery_agent_id']?.toString() ?? '',
            riderName: (ord['delivery_agents'] is Map && ord['delivery_agents']['users'] is Map)
                ? '${ord['delivery_agents']['users']['first_name'] ?? ''} ${ord['delivery_agents']['users']['last_name'] ?? ''}'.trim()
                : 'Joel Rider',
            riderCode: (ord['delivery_agents'] is Map) ? ord['delivery_agents']['agent_code']?.toString() ?? 'PDA-7000' : 'PDA-7000',
            amount: (ord['total_amount'] as num?)?.toDouble() ?? 0.0,
            commission: (ord['agent_commission'] as num?)?.toDouble() ?? 1000.0,
            transportAllowance: (ord['agent_transport_allowance'] as num?)?.toDouble() ?? 1500.0,
            category: isPstk ? 'paystack_direct' : 'cash_pod',
            paymentMethod: pMethod,
            gatewayReference: 'PSTK-${ord['order_number']}',
            channel: isPstk ? 'Titan Trust / Paystack' : 'Cash in Hand (COD)',
            status: ord['status']?.toString() == 'delivered' ? 'verified' : 'pending',
            isCredit: true,
            notes: ord['delivery_notes']?.toString(),
            createdAt: ord['updated_at'] != null ? DateTime.tryParse(ord['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
          ));
        }
      } catch (_) {}

      // Deduplicate by transactionCode & sort chronologically descending
      final seenCodes = <String>{};
      final uniqueTxns = <DCTransactionRecord>[];
      for (final txn in allTxns) {
        if (!seenCodes.contains(txn.transactionCode)) {
          seenCodes.add(txn.transactionCode);
          uniqueTxns.add(txn);
        }
      }
      uniqueTxns.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (uniqueTxns.isNotEmpty) {
        state = state.copyWith(transactions: uniqueTxns);
        await _storageService.cacheDcTransactions(uniqueTxns);
        debugPrint('[DC_CONSOLE_PROVIDER] ✅ Loaded ${uniqueTxns.length} consolidated DC transactions from live DB.');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Error loading DC transactions ($e).');
    } finally {
      dbClient?.dispose();
    }
  }

  void gradeReturn(String returnId, String qcStatus, String? binLocation) {
    final updated = state.returnItems.map((r) {
      if (r.id == returnId) {
        return r.copyWith(qcStatus: qcStatus, targetBin: binLocation);
      }
      return r;
    }).toList();
    state = state.copyWith(returnItems: updated);
    _storageService.cacheReturnItems(updated);
  }
}

final dcConsoleProvider = StateNotifierProvider<DCConsoleNotifier, DCConsoleState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return DCConsoleNotifier(storage);
});
