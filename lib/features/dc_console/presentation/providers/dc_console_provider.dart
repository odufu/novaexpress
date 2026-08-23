import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
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

  static const List<DCFleetDriver> defaultFleetDrivers = [
    DCFleetDriver(
      id: 'b1111111-1111-4111-8111-111111111111',
      driverCode: 'PDA-7000',
      name: 'Emeka Rider',
      phone: '08012345678',
      email: 'emeka.rider@novaexpress.ng',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      vehicleModel: 'Bajaj Boxer 100 (Personal)',
      vehiclePlate: 'ABJ-204-XY',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Wuse 2 & Abuja Central',
      totalAssignedOrders: 6,
      completedOrders: 4,
      routeProgressPercent: 66.7,
      efficiencyRating: 98.5,
      cashInCustody: 55000.0,
      itemsInCustody: 14,
      currentLatitude: 9.0765,
      currentLongitude: 7.4832,
      personnelType: 'pda',
      compensationType: 'commission',
      commissionRate: 1000.0,
      transportAllowance: 1500.0,
      failedDeliveryAllowance: 500.0,
      baseSalary: 0.0,
      upsellBonusPercent: 10.0,
      bankName: 'Kuda Microfinance Bank',
      bankAccountNumber: '2019847291',
      bankAccountName: 'Emeka Rider',
      guarantorName: 'Chief Nnamdi Okafor',
      guarantorPhone: '08034567890',
    ),
    DCFleetDriver(
      id: 'b2222222-2222-4222-8222-222222222222',
      driverCode: 'PDA-7588',
      name: 'Sanni Abacha',
      phone: '08098765432',
      email: 'sanni.abacha@novaexpress.ng',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      vehicleModel: 'TVS HLX Plus (Personal)',
      vehiclePlate: 'ABJ-892-KT',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Maitama & Garki',
      totalAssignedOrders: 4,
      completedOrders: 3,
      routeProgressPercent: 75.0,
      efficiencyRating: 99.1,
      cashInCustody: 44000.0,
      itemsInCustody: 8,
      currentLatitude: 9.0882,
      currentLongitude: 7.4933,
      personnelType: 'pda',
      compensationType: 'commission',
      commissionRate: 1000.0,
      transportAllowance: 1500.0,
      failedDeliveryAllowance: 500.0,
      baseSalary: 0.0,
      upsellBonusPercent: 10.0,
      bankName: 'GTBank',
      bankAccountNumber: '0129847291',
      bankAccountName: 'Sanni Abacha',
      guarantorName: 'Alhaji Musa Abacha',
      guarantorPhone: '08023456789',
    ),
    DCFleetDriver(
      id: 'b3333333-3333-4333-8333-333333333333',
      driverCode: 'RDR-102',
      name: 'Babatunde Lawal',
      phone: '08022223344',
      email: 'babatunde.lawal@novaexpress.ng',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      vehicleModel: 'Haojue 125 (Company Fleet)',
      vehiclePlate: 'ABJ-501-AB',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Garki & Asokoro',
      totalAssignedOrders: 5,
      completedOrders: 5,
      routeProgressPercent: 100.0,
      efficiencyRating: 97.8,
      cashInCustody: 68000.0,
      itemsInCustody: 0,
      currentLatitude: 9.0345,
      currentLongitude: 7.4891,
      personnelType: 'in_house_rider',
      compensationType: 'salary',
      commissionRate: 500.0,
      transportAllowance: 800.0,
      failedDeliveryAllowance: 300.0,
      baseSalary: 120000.0,
      upsellBonusPercent: 5.0,
      bankName: 'Zenith Bank',
      bankAccountNumber: '1019283746',
      bankAccountName: 'Babatunde Lawal',
      guarantorName: 'Mr. Femi Lawal',
      guarantorPhone: '08098761234',
    ),
  ];

  const DCConsoleState({
    this.activeHubId = '22222222-2222-4222-8222-222222222222',
    this.activeHubName = 'Wuse Distribution Center',
    this.activeHubCode = 'DC-WUSE-01',
    this.activeTabIndex = 0,
    this.isSidebarCollapsed = false,
    this.searchQuery = '',
    this.fleetFilter = 'all',
    this.drivers = defaultFleetDrivers,
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
  DCConsoleNotifier() : super(const DCConsoleState()) {
    _initDrivers();
  }

  void _initDrivers() {
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (!isTest) {
      loadDriversFromDatabase();
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
    state = state.copyWith(
      warehouseBatches: [batch, ...state.warehouseBatches],
    );
  }

  void addDriver(DCFleetDriver driver) {
    state = state.copyWith(
      drivers: [driver, ...state.drivers.where((d) => d.id != driver.id && d.driverCode != driver.driverCode && (driver.email.isEmpty || d.email != driver.email))],
    );
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
        // Merge with existing drivers
        final merged = [...dbDrivers];
        for (final local in state.drivers) {
          if (!merged.any((d) => d.id == local.id || d.driverCode == local.driverCode || (d.email.isNotEmpty && d.email == local.email))) {
            merged.add(local);
          }
        }
        state = state.copyWith(drivers: merged);
        debugPrint('[DC_CONSOLE_PROVIDER] 🚚 Loaded ${dbDrivers.length} active fleet drivers from live Supabase DB.');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supabase fleet fetch notice ($e). Active local drivers retained.');
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
  }
}

final dcConsoleProvider = StateNotifierProvider<DCConsoleNotifier, DCConsoleState>((ref) {
  return DCConsoleNotifier();
});
