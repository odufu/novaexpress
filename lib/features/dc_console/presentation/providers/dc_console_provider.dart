import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  DCConsoleNotifier() : super(const DCConsoleState()) {
    _initializeDemoData();
  }

  void _initializeDemoData() {
    final defaultDrivers = [
      const DCFleetDriver(
        id: 'b1111111-1111-4111-8111-111111111111',
        driverCode: 'PDA-7000',
        name: 'Emeka Rider',
        phone: '08012345678',
        email: 'emeka.rider@novaexpress.ng',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        vehicleModel: 'Bajaj Boxer • ABJ-204-XY (Personal)',
        vehiclePlate: 'ABJ-204-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse II & Abuja Central',
        totalAssignedOrders: 53,
        completedOrders: 51,
        routeProgressPercent: 96.0,
        efficiencyRating: 99.2,
        cashInCustody: 953000.0,
        itemsInCustody: 22,
        currentLatitude: 9.0623,
        currentLongitude: 7.4520,
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
        guarantorName: 'Dr. Chidi Okafor',
        guarantorPhone: '08034567890',
      ),
      const DCFleetDriver(
        id: 'drv-002',
        driverCode: 'RDR-102',
        name: 'Babatunde Lawal',
        phone: '08034567890',
        email: 'babatunde.lawal@novaexpress.ng',
        avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
        vehicleModel: 'Haojue 125 • ABJ-894-XA (Company)',
        vehiclePlate: 'ABJ-894-XA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Garki I & II',
        totalAssignedOrders: 15,
        completedOrders: 15,
        routeProgressPercent: 100.0,
        efficiencyRating: 94.1,
        cashInCustody: 45000.0,
        itemsInCustody: 8,
        currentLatitude: 9.0345,
        currentLongitude: 7.4821,
        personnelType: 'in_house_rider',
        compensationType: 'salary',
        commissionRate: 500.0,
        transportAllowance: 800.0,
        failedDeliveryAllowance: 300.0,
        baseSalary: 120000.0,
        upsellBonusPercent: 5.0,
        bankName: 'GTBank',
        bankAccountNumber: '0129482910',
        bankAccountName: 'Babatunde Lawal',
        guarantorName: 'Alhaji Sani Lawal',
        guarantorPhone: '08023456789',
      ),
      const DCFleetDriver(
        id: 'drv-001',
        driverCode: 'RDR-103',
        name: 'Jameson Miller',
        phone: '08023456789',
        email: 'jameson.miller@novaexpress.ng',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        vehicleModel: 'Isuzu NPR • 12-XZ-01 (Company)',
        vehiclePlate: '12-XZ-01',
        vehicleType: 'Van',
        status: 'active',
        assignedZone: 'Wuse II & Zone 4',
        totalAssignedOrders: 18,
        completedOrders: 13,
        routeProgressPercent: 72.0,
        efficiencyRating: 98.4,
        cashInCustody: 145000.0,
        itemsInCustody: 12,
        currentLatitude: 9.0765,
        currentLongitude: 7.3986,
        personnelType: 'in_house_rider',
        compensationType: 'hybrid',
        commissionRate: 800.0,
        transportAllowance: 1200.0,
        failedDeliveryAllowance: 400.0,
        baseSalary: 140000.0,
        upsellBonusPercent: 8.0,
        bankName: 'Zenith Bank',
        bankAccountNumber: '1029384756',
        bankAccountName: 'Jameson Miller',
        guarantorName: 'Mrs. Janet Miller',
        guarantorPhone: '08091112233',
      ),
      const DCFleetDriver(
        id: 'drv-003',
        driverCode: 'PDA-7002',
        name: 'Marcus Reid',
        phone: '08045678901',
        email: 'marcus.reid@novaexpress.ng',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        vehicleModel: 'Toyota Corolla • 09-RR-45 (Personal)',
        vehiclePlate: '09-RR-45',
        vehicleType: 'Car',
        status: 'delayed',
        assignedZone: 'Maitama & Ministers Hill',
        totalAssignedOrders: 20,
        completedOrders: 7,
        routeProgressPercent: 34.0,
        efficiencyRating: 82.0,
        cashInCustody: 95000.0,
        itemsInCustody: 16,
        currentLatitude: 9.0882,
        currentLongitude: 7.4933,
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1200.0,
        transportAllowance: 2000.0,
        failedDeliveryAllowance: 500.0,
        baseSalary: 0.0,
        upsellBonusPercent: 10.0,
        bankName: 'Access Bank',
        bankAccountNumber: '0098765432',
        bankAccountName: 'Marcus Reid',
        guarantorName: 'Pastor David Reid',
        guarantorPhone: '08033334455',
      ),
    ];

    final defaultBatches = [
      DCWarehouseBatch(
        id: 'batch-001',
        batchCode: 'BATCH-RSP-2026',
        productName: 'Respira Detox Tea',
        sku: 'RSP-DTX-01',
        clientName: 'Novacare Organics',
        waybillNumber: 'WAY-2026-0819',
        initialQuantity: 1000,
        currentQuantity: 840,
        allocatedQuantity: 120,
        binLocation: 'BIN-A1-04',
        manufactureDate: DateTime.now().subtract(const Duration(days: 60)),
        expiryDate: DateTime.now().add(const Duration(days: 670)),
      ),
      DCWarehouseBatch(
        id: 'batch-002',
        batchCode: 'BATCH-GRZ-2026',
        productName: 'Grazer Herbal Tea',
        sku: 'GRZ-HBT-02',
        clientName: 'Novacare Organics',
        waybillNumber: 'WAY-2026-0819',
        initialQuantity: 1500,
        currentQuantity: 1250,
        allocatedQuantity: 210,
        binLocation: 'BIN-A1-08',
        manufactureDate: DateTime.now().subtract(const Duration(days: 45)),
        expiryDate: DateTime.now().add(const Duration(days: 685)),
      ),
      DCWarehouseBatch(
        id: 'batch-003',
        batchCode: 'BATCH-SLM-2026',
        productName: 'SlimFit Detox Blend',
        sku: 'SLM-DTX-03',
        clientName: 'PharmaPlus Global',
        waybillNumber: 'WAY-2026-0815',
        initialQuantity: 800,
        currentQuantity: 520,
        allocatedQuantity: 60,
        binLocation: 'BIN-B2-12',
        manufactureDate: DateTime.now().subtract(const Duration(days: 90)),
        expiryDate: DateTime.now().add(const Duration(days: 420)),
      ),
    ];

    final defaultReturns = [
      DCReturnItem(
        id: 'ret-001',
        returnTicketNumber: 'RET-00109',
        orderNumber: 'TRK-8920',
        customerName: 'Mrs. Folake Adebayo',
        customerPhone: '08051112233',
        productName: 'Grazer Herbal Tea (1 Pack)',
        quantity: 1,
        amount: 18000.0,
        riderName: 'Emeka Rider',
        returnReason: 'Customer requested reschedule after office close',
        qcStatus: 'pending_qc',
        returnedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      DCReturnItem(
        id: 'ret-002',
        returnTicketNumber: 'RET-00108',
        orderNumber: 'TRK-8915',
        customerName: 'Alhaji Bello Kano',
        customerPhone: '08039998877',
        productName: 'Respira Detox Tea (2 Packs)',
        quantity: 2,
        amount: 30000.0,
        riderName: 'Marcus Reid',
        returnReason: 'Outer seal broken in transit',
        qcStatus: 'grade_b_scrapped',
        returnedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];

    state = state.copyWith(
      drivers: defaultDrivers,
      warehouseBatches: defaultBatches,
      returnItems: defaultReturns,
    );
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
      drivers: [driver, ...state.drivers],
    );
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
