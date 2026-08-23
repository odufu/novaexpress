import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/dc_fleet_driver.dart';

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
    this.avgDeliveryTimeMin = 24.5,
    this.fuelEfficiencyKmPerL = 9.2,
    this.onScheduleRate = 88.0,
    this.idleCapacityRate = 12.0,
    this.isLoading = false,
    this.selectedDriverId,
  });

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
      avgDeliveryTimeMin: avgDeliveryTimeMin ?? this.avgDeliveryTimeMin,
      fuelEfficiencyKmPerL: fuelEfficiencyKmPerL ?? this.fuelEfficiencyKmPerL,
      onScheduleRate: onScheduleRate ?? this.onScheduleRate,
      idleCapacityRate: idleCapacityRate ?? this.idleCapacityRate,
      isLoading: isLoading ?? this.isLoading,
      selectedDriverId: selectedDriverId ?? this.selectedDriverId,
    );
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

    state = state.copyWith(
      drivers: cached ?? state.drivers,
      warehouseBatches: cachedBatches ?? state.warehouseBatches,
      returnItems: cachedReturns ?? state.returnItems,
    );

    if (cached != null && cached.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cached.length} drivers from local storage cache.');
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
