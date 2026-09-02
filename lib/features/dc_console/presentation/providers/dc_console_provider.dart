import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../../domain/entities/distribution_center.dart';

final List<DistributionCenter> defaultDistributionCenters = [
  DistributionCenter(
    id: '22222222-2222-4222-8222-222222222222',
    companyId: '11111111-1111-4111-8111-111111111111',
    name: 'Wuse Central Distribution Hub',
    code: 'DC-ABJ-01',
    state: 'Federal Capital Territory',
    city: 'Abuja',
    address: 'Plot 42, Cadastral Zone B03, Wuse II, Abuja',
    contactPhone: '+234 802 345 6789',
    contactEmail: 'wuse.dc@novaexpress.com',
    managerName: 'Adekunle Supervisor',
    isGrandDc: true,
    isHub: true,
    isActive: true,
    operatingZones: const ['Abuja Municipal (AMAC)', 'AMAC', 'Wuse I', 'Wuse II', 'Maitama', 'Garki', 'Jabi', 'Utako', 'Central Area', 'Guzape'],
    storageCapacityUnits: 50000,
    totalAssignedRiders: 12,
    activeInventoryBatches: 8,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  DistributionCenter(
    id: '33333333-3333-4333-8333-333333333333',
    companyId: '11111111-1111-4111-8111-111111111111',
    name: 'Ikeja Commercial Hub DC',
    code: 'DC-LOS-01',
    state: 'Lagos State',
    city: 'Ikeja',
    address: '12 Mobolaji Bank Anthony Way, Ikeja, Lagos',
    contactPhone: '+234 803 111 2233',
    contactEmail: 'ikeja.dc@novaexpress.com',
    managerName: 'Babajide Olawale',
    isHub: true,
    isActive: true,
    operatingZones: const ['Ikeja', 'Alausa', 'Opebi', 'Allen Avenue', 'Maryland', 'GRA Ikeja', 'Oregun'],
    storageCapacityUnits: 75000,
    totalAssignedRiders: 24,
    activeInventoryBatches: 15,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  DistributionCenter(
    id: '44444444-4444-4444-8444-444444444444',
    companyId: '11111111-1111-4111-8111-111111111111',
    name: 'Port Harcourt Gateway DC',
    code: 'DC-PHC-01',
    state: 'Rivers State',
    city: 'Port Harcourt',
    address: '7 Trans-Amadi Industrial Layout, Port Harcourt',
    contactPhone: '+234 805 777 8899',
    contactEmail: 'phc.dc@novaexpress.com',
    managerName: 'Chinedu Nnamdi',
    isHub: false,
    isActive: true,
    operatingZones: const ['Trans-Amadi', 'GRA Phase 2', 'Old GRA', 'D/Line', 'Rumuokwuta', 'Peter Odili Road'],
    storageCapacityUnits: 30000,
    totalAssignedRiders: 8,
    activeInventoryBatches: 5,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  DistributionCenter(
    id: '55555555-5555-4555-8555-555555555555',
    companyId: '11111111-1111-4111-8111-111111111111',
    name: 'Kano Northern Depot DC',
    code: 'DC-KAN-01',
    state: 'Kano State',
    city: 'Kano',
    address: '18 Bompai Road, Commercial District, Kano',
    contactPhone: '+234 806 444 5566',
    contactEmail: 'kano.dc@novaexpress.com',
    managerName: 'Ibrahim Danladi',
    isHub: false,
    isActive: true,
    operatingZones: const ['Bompai', 'Nassarawa', 'Sabon Gari', 'Fagge', 'Tarauni'],
    storageCapacityUnits: 25000,
    totalAssignedRiders: 6,
    activeInventoryBatches: 4,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
];

final List<DCFleetDriver> defaultFleetDrivers = [
  DCFleetDriver(
    id: 'b1111111-1111-4111-8111-111111111111',
    driverCode: 'PDA-7000',
    name: 'Emeka Rider',
    phone: '08012345678',
    email: 'rider.emeka@novaexpress.com',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    status: 'active',
    assignedZone: 'Abuja Municipal (AMAC)',
    coveredLgas: const ['Abuja Municipal (AMAC)', 'AMAC', 'Wuse II', 'Maitama', 'Garki'],
    vehicleType: 'Motorcycle',
    vehiclePlate: 'ABJ-772-XY',
    vehicleModel: 'Bajaj Boxer 150',
    totalAssignedOrders: 15,
    completedOrders: 12,
    routeProgressPercent: 80.0,
    efficiencyRating: 4.8,
    cashInCustody: 75000.0,
    itemsInCustody: 8,
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    failedDeliveryAllowance: 500.0,
    compensationType: 'commission',
    personnelType: 'pda',
  ),
  DCFleetDriver(
    id: 'b2222222-2222-4222-8222-222222222222',
    driverCode: 'RDR-102',
    name: 'Musa Garba',
    phone: '08023456789',
    email: 'musa.garba@novaexpress.com',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    status: 'active',
    assignedZone: 'Bwari',
    coveredLgas: const ['Bwari', 'Kubwa', 'Dutse'],
    vehicleType: 'Motorcycle',
    vehiclePlate: 'ABJ-102-KW',
    vehicleModel: 'TVS HLX 125',
    totalAssignedOrders: 10,
    completedOrders: 9,
    routeProgressPercent: 90.0,
    efficiencyRating: 4.9,
    cashInCustody: 42000.0,
    itemsInCustody: 5,
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    failedDeliveryAllowance: 500.0,
    compensationType: 'commission',
    personnelType: 'pda',
  ),
];

final List<ClientProfile> defaultRegisteredClients = [
  const ClientProfile(
    id: '33333333-3333-4333-8333-333333333333',
    companyName: 'Novacale Limited',
    contactPerson: 'Dr. Chuka Okafor',
    email: 'client.novacale@novaexpress.ng',
    phone: '08034455667',
    address: 'Plot 12, Commercial Avenue, Central Business District, Abuja',
    city: 'Abuja',
    state: 'Federal Capital Territory',
    code: 'CLI-NOVACALE-01',
    tier: 'enterprise',
    closerLimit: 250,
    isEnterprise: true,
    totalClosersCount: 200,
  ),
  const ClientProfile(
    id: '33333333-3333-4333-8333-333333333334',
    companyName: 'Zenith Herbal Direct',
    contactPerson: 'Madam Stella Balogun',
    email: 'stella@zenithherbal.com',
    phone: '08023344556',
    address: '14 Allen Avenue, Ikeja, Lagos',
    city: 'Ikeja',
    state: 'Lagos State',
    code: 'CLI-ZENITH-02',
    tier: 'standard_merchant',
    closerLimit: 0,
    isEnterprise: false,
    totalClosersCount: 0,
  ),
];

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
  final int activeTabIndex; // 0..10
  final bool isSidebarCollapsed;
  final String searchQuery;
  final String fleetFilter; // 'all', 'active', 'at_rest', 'delayed'
  final List<DistributionCenter> distributionCenters;
  final String? selectedDcId;
  final String dcFilter; // 'all', 'hubs', 'satellites', 'active', 'inactive'
  final String selectedStateFilter; // 'all', 'Abuja FCT', 'Lagos State', etc.
  final List<DCFleetDriver> drivers;
  final List<DCWarehouseBatch> warehouseBatches;
  final List<DCReturnItem> returnItems;
  final List<DCPayoutClaim> payoutClaims;
  final List<ClientProfile> clients;
  final String clientFilter; // 'all', 'enterprise', 'standard'
  final DCFinanceSettings financeSettings;
  final double avgDeliveryTimeMin;
  final double fuelEfficiencyKmPerL;
  final double onScheduleRate;
  final double idleCapacityRate;
  final bool isLoading;
  final String? selectedDriverId;

  const DCConsoleState({
    this.activeHubId = '22222222-2222-4222-8222-222222222222',
    this.activeHubName = 'Wuse Central Distribution Hub',
    this.activeHubCode = 'DC-ABJ-01',
    this.activeTabIndex = 0,
    this.isSidebarCollapsed = false,
    this.searchQuery = '',
    this.fleetFilter = 'all',
    this.distributionCenters = const [],
    this.selectedDcId,
    this.dcFilter = 'all',
    this.selectedStateFilter = 'all',
    this.drivers = const [],
    this.warehouseBatches = const [],
    this.returnItems = const [],
    this.payoutClaims = const [],
    this.clients = const [],
    this.clientFilter = 'all',
    this.transactions = const [],
    this.transactionFilter = 'all',
    this.transactionStatusFilter = 'all',
    this.financeSettings = const DCFinanceSettings(),
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
    List<DistributionCenter>? distributionCenters,
    String? selectedDcId,
    String? dcFilter,
    String? selectedStateFilter,
    List<DCFleetDriver>? drivers,
    List<DCWarehouseBatch>? warehouseBatches,
    List<DCReturnItem>? returnItems,
    List<DCPayoutClaim>? payoutClaims,
    List<ClientProfile>? clients,
    String? clientFilter,
    List<DCTransactionRecord>? transactions,
    String? transactionFilter,
    String? transactionStatusFilter,
    DCFinanceSettings? financeSettings,
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
      distributionCenters: distributionCenters ?? this.distributionCenters,
      selectedDcId: selectedDcId ?? this.selectedDcId,
      dcFilter: dcFilter ?? this.dcFilter,
      selectedStateFilter: selectedStateFilter ?? this.selectedStateFilter,
      drivers: drivers ?? this.drivers,
      warehouseBatches: warehouseBatches ?? this.warehouseBatches,
      returnItems: returnItems ?? this.returnItems,
      payoutClaims: payoutClaims ?? this.payoutClaims,
      clients: clients ?? this.clients,
      clientFilter: clientFilter ?? this.clientFilter,
      transactions: transactions ?? this.transactions,
      transactionFilter: transactionFilter ?? this.transactionFilter,
      transactionStatusFilter: transactionStatusFilter ?? this.transactionStatusFilter,
      financeSettings: financeSettings ?? this.financeSettings,
      avgDeliveryTimeMin: avgDeliveryTimeMin ?? this.avgDeliveryTimeMin,
      fuelEfficiencyKmPerL: fuelEfficiencyKmPerL ?? this.fuelEfficiencyKmPerL,
      onScheduleRate: onScheduleRate ?? this.onScheduleRate,
      idleCapacityRate: idleCapacityRate ?? this.idleCapacityRate,
      isLoading: isLoading ?? this.isLoading,
      selectedDriverId: selectedDriverId ?? this.selectedDriverId,
    );
  }

  List<DistributionCenter> get filteredDistributionCenters {
    var list = distributionCenters.isNotEmpty ? distributionCenters : defaultDistributionCenters;
    if (dcFilter != 'all') {
      if (dcFilter == 'hubs') {
        list = list.where((d) => d.isHub).toList();
      } else if (dcFilter == 'satellites') {
        list = list.where((d) => !d.isHub).toList();
      } else if (dcFilter == 'active') {
        list = list.where((d) => d.isActive).toList();
      } else if (dcFilter == 'inactive') {
        list = list.where((d) => !d.isActive).toList();
      }
    }

    if (selectedStateFilter != 'all') {
      list = list.where((d) => d.state.toLowerCase() == selectedStateFilter.toLowerCase()).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.code.toLowerCase().contains(q) ||
          d.city.toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q) ||
          d.address.toLowerCase().contains(q) ||
          (d.managerName != null && d.managerName!.toLowerCase().contains(q)) ||
          d.operatingZones.any((z) => z.toLowerCase().contains(q))).toList();
    }
    return list;
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

  List<ClientProfile> get filteredClients {
    var list = clients.isNotEmpty ? clients : defaultRegisteredClients;
    if (clientFilter != 'all') {
      if (clientFilter == 'enterprise') {
        list = list.where((c) => c.isEnterprise).toList();
      } else if (clientFilter == 'standard') {
        list = list.where((c) => !c.isEnterprise).toList();
      }
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((c) =>
          c.companyName.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.contactPerson.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.city.toLowerCase().contains(q) ||
          c.state.toLowerCase().contains(q)).toList();
    }
    return list;
  }
}

class DCConsoleNotifier extends StateNotifier<DCConsoleState> {
  final LocalStorageService _storageService;

  static bool get isTestEnvironment {
    try {
      if (WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test')) {
        return true;
      }
    } catch (_) {}
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST') ||
             Platform.environment.containsKey('TEST_PLATFORM');
    } catch (_) {
      return false;
    }
  }

  DCConsoleNotifier([LocalStorageService? storageService])
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(DCConsoleState(
          distributionCenters: defaultDistributionCenters,
          drivers: defaultFleetDrivers,
        )) {
    if (!isTestEnvironment) {
      _initDrivers();
    }
  }

  Future<void> _initDrivers() async {
    // 1. Instant hydration from persistent local cache
    final cachedDcs = await _storageService.getCachedDistributionCenters();
    final cached = await _storageService.getCachedFleetDrivers();
    final cachedFinance = await _storageService.getCachedFinanceSettings();
    final cachedBatches = await _storageService.getCachedWarehouseBatches();
    final cachedReturns = await _storageService.getCachedReturnItems();
    final cachedPayouts = await _storageService.getCachedPayoutClaims();
    final cachedTxns = await _storageService.getCachedDcTransactions();

    if (isTestEnvironment && state.drivers.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      distributionCenters: (cachedDcs != null && cachedDcs.isNotEmpty) ? cachedDcs : defaultDistributionCenters,
      drivers: cached ?? state.drivers,
      financeSettings: cachedFinance ?? state.financeSettings,
      warehouseBatches: cachedBatches ?? state.warehouseBatches,
      returnItems: cachedReturns ?? state.returnItems,
      payoutClaims: cachedPayouts ?? state.payoutClaims,
      transactions: cachedTxns ?? state.transactions,
    );

    // Register all cached drivers into AuthRemoteDataSource in-memory store
    if (cached != null && cached.isNotEmpty) {
      for (final d in cached) {
        final nameParts = d.name.trim().split(' ');
        final fName = nameParts.first;
        final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        AuthRemoteDataSourceImpl.registerUserInMemory(
          UserModel(
            id: d.id,
            email: d.email,
            firstName: fName,
            lastName: lName,
            phone: d.phone,
            role: 'delivery_agent',
            deliveryAgentId: d.id,
            deliveryAgentCode: d.driverCode,
            personnelType: d.personnelType,
            compensationType: d.compensationType,
            commissionRate: d.commissionRate,
            transportAllowance: d.transportAllowance,
            failedDeliveryAllowance: d.failedDeliveryAllowance,
            baseSalary: d.baseSalary,
            vehicleType: d.vehicleType,
            vehiclePlateNumber: d.vehiclePlate,
            bankName: d.bankName,
            bankAccountNumber: d.bankAccountNumber,
            bankAccountName: d.bankAccountName,
            agentStatus: d.status,
            operatingCity: d.assignedZone,
            distributionCenterId: d.distributionCenterId,
          ),
        );
      }
    }

    if (cachedDcs != null && cachedDcs.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cachedDcs.length} distribution centers from local storage cache.');
    }
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cached.length} drivers from local storage cache.');
    }
    if (cachedFinance != null) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated finance & POS settings from local storage cache.');
    }
    if (cachedPayouts != null && cachedPayouts.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cachedPayouts.length} payout claims from local storage cache.');
    }
    if (cachedTxns != null && cachedTxns.isNotEmpty) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚡ Hydrated ${cachedTxns.length} DC transactions from local storage cache.');
    }

    // 2. Fetch fresh real data from live Supabase DB
    if (!isTestEnvironment) {
      await loadDistributionCentersFromDatabase();
      await loadFinanceSettingsFromDatabase();
      await loadDriversFromDatabase();
      await loadPayoutClaimsFromDatabase();
      await loadTransactionsFromDatabase();
      await loadClientsFromDatabase();
    }
  }

  List<DistributionCenter> get distributionCenters => state.distributionCenters.isNotEmpty ? state.distributionCenters : defaultDistributionCenters;
  List<DCFleetDriver> get drivers => state.drivers;
  List<DCWarehouseBatch> get warehouseBatches => state.warehouseBatches;
  List<ClientProfile> get clients => state.clients.isNotEmpty ? state.clients : defaultRegisteredClients;

  DistributionCenter? get grandDc => distributionCenters.firstWhere(
        (dc) => dc.isGrandDc,
        orElse: () => distributionCenters.firstWhere(
          (dc) => dc.code == 'DC-ABJ-01' || dc.isHub,
          orElse: () => distributionCenters.first,
        ),
      );

  bool get isCurrentHubGrandDc =>
      state.activeHubId == grandDc?.id ||
      state.activeHubCode == grandDc?.code ||
      state.activeHubCode == 'DC-ABJ-01' ||
      state.activeHubName.toLowerCase().contains('wuse central') ||
      state.activeHubName.toLowerCase().contains('grand dc');

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

  void setDcFilter(String filter) {
    state = state.copyWith(dcFilter: filter);
  }

  void setClientFilter(String filter) {
    state = state.copyWith(clientFilter: filter);
  }

  void setSelectedStateFilter(String stateName) {
    state = state.copyWith(selectedStateFilter: stateName);
  }

  void selectDriver(String? driverId) {
    state = state.copyWith(selectedDriverId: driverId);
  }

  void selectDistributionCenter(String? dcId) {
    state = state.copyWith(selectedDcId: dcId);
  }

  Future<void> loadClientsFromDatabase() async {
    bool isTest = false;
    if (!kIsWeb) {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }
    if (isTest) return;

    try {
      final dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final response = await dbClient
          .from('clients')
          .select()
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        final dbClients = response.map((c) => ClientProfile.fromJson(c)).toList();
        state = state.copyWith(clients: dbClients);
        debugPrint('[DC_CONSOLE] ⚡ Loaded ${dbClients.length} registered clients from Supabase DB.');
      } else {
        state = state.copyWith(clients: defaultRegisteredClients);
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE] ℹ️ Error loading clients from Supabase: $e');
      if (state.clients.isEmpty) {
        state = state.copyWith(clients: defaultRegisteredClients);
      }
    }
  }

  Future<ClientProfile> createClient({
    required String companyName,
    required String contactPerson,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    required String tier,
    int closerLimit = 250,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final isEnt = tier == 'enterprise';
      final clientId = _generateUuid();
      final suffix = (state.clients.length + 1).toString().padLeft(2, '0');
      final prefix = companyName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
      final codePrefix = prefix.length >= 4 ? prefix.substring(0, 4) : 'CLI';
      final clientCode = 'CLI-$codePrefix-$suffix';

      final newClient = ClientProfile(
        id: clientId,
        companyName: companyName.trim(),
        contactPerson: contactPerson.trim(),
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        city: city.trim(),
        state: stateName.trim(),
        code: clientCode,
        tier: tier,
        closerLimit: isEnt ? closerLimit : 0,
        isEnterprise: isEnt,
        totalClosersCount: 0,
        createdAt: DateTime.now(),
      );

      // Async push to Supabase Cloud DB
      Future.microtask(() async {
        try {
          final dbClient = SupabaseClient(
            SupabaseConstants.supabaseUrl,
            SupabaseConstants.supabaseServiceRoleKey,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );

          // 1. Insert into clients table
          await dbClient.from('clients').insert({
            'id': newClient.id,
            'company_name': newClient.companyName,
            'contact_person': newClient.contactPerson,
            'email': newClient.email,
            'phone': newClient.phone,
            'address': newClient.address,
            'city': newClient.city,
            'state': newClient.state,
            'code': newClient.code,
            'tier': newClient.tier,
            'closer_limit': newClient.closerLimit,
            'is_enterprise': newClient.isEnterprise,
            'is_active': true,
          });

          // 2. Insert client admin into users table
          final nameParts = contactPerson.trim().split(' ');
          await dbClient.from('users').insert({
            'id': newClient.id,
            'company_id': '11111111-1111-4111-8111-111111111111',
            'client_id': newClient.id,
            'email': newClient.email,
            'phone_number': newClient.phone,
            'first_name': nameParts.first,
            'last_name': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Admin',
            'role': 'client',
            'is_active': true,
          });
          debugPrint('[DC_CONSOLE] ✅ Grand DC onboarded client ${newClient.companyName} (${newClient.tier}) in Supabase.');
        } catch (dbErr) {
          debugPrint('[DC_CONSOLE] ℹ️ Supabase client insert notice: $dbErr');
        }
      });

      final updatedClients = [newClient, ...state.clients];
      state = state.copyWith(clients: updatedClients, isLoading: false);
      return newClient;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> loadFinanceSettingsFromDatabase() async {
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
          .from('dc_finance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final settings = DCFinanceSettings.fromJson(response);
        state = state.copyWith(financeSettings: settings);
        await _storageService.cacheFinanceSettings(settings);
        debugPrint('[DC_CONSOLE_PROVIDER] 💳 Loaded DC finance & POS settings from Supabase (Mode: ${settings.posChargeMode}, Commission: ₦${settings.defaultCommissionRate}, Transport: ₦${settings.defaultTransportAllowance}).');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supabase finance settings fetch notice: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> updateFinanceSettings(DCFinanceSettings newSettings) async {
    state = state.copyWith(financeSettings: newSettings);
    await _storageService.cacheFinanceSettings(newSettings);

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

      await dbClient.from('dc_finance_settings').upsert({
        'id': 'global_finance_config',
        'pos_charge_mode': newSettings.posChargeMode,
        'pos_tier_amount': newSettings.posTierAmount,
        'pos_tier_fee': newSettings.posTierFee,
        'pos_flat_rate': newSettings.posFlatRate,
        'pos_max_cap_fee': newSettings.posMaxCapFee,
        'is_pos_fee_reimbursable': newSettings.isPosFeeReimbursable,
        'default_commission_rate': newSettings.defaultCommissionRate,
        'default_transport_allowance': newSettings.defaultTransportAllowance,
        'default_failed_delivery_allowance': newSettings.defaultFailedDeliveryAllowance,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[DC_CONSOLE_PROVIDER] 💾 DC Finance settings persisted to Supabase.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase finance settings update error: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  void setPosChargeMode(String mode) {
    final updated = state.financeSettings.copyWith(posChargeMode: mode);
    updateFinanceSettings(updated);
  }

  void setPosFlatRate(double rate) {
    final updated = state.financeSettings.copyWith(posFlatRate: rate);
    updateFinanceSettings(updated);
  }

  void switchHub(String hubName, String hubCode, String hubId) {
    state = state.copyWith(
      activeHubName: hubName,
      activeHubCode: hubCode,
      activeHubId: hubId,
    );
  }

  void switchActiveHub(DistributionCenter dc) {
    state = state.copyWith(
      activeHubId: dc.id,
      activeHubName: dc.name,
      activeHubCode: dc.code,
    );
  }

  Future<void> loadDistributionCentersFromDatabase() async {
    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final response = await dbClient
          .from('distribution_centers')
          .select()
          .order('name', ascending: true);

      final List<DistributionCenter> dcs = [];
      for (final item in response as List) {
        try {
          dcs.add(DistributionCenter.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Error parsing DC row: $e');
        }
      }

      if (dcs.isNotEmpty) {
        state = state.copyWith(distributionCenters: dcs);
        await _storageService.cacheDistributionCenters(dcs);
        debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Loaded ${dcs.length} distribution centers from live Supabase DB.');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supabase DC fetch notice ($e). Using local cached DCs.');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<DistributionCenter> createDistributionCenter({
    required String name,
    required String code,
    required String stateName,
    required String city,
    required String address,
    String? contactPhone,
    String? contactEmail,
    String? managerName,
    bool isHub = false,
    int storageCapacityUnits = 25000,
    List<String> operatingZones = const [],
    String? supervisorEmail,
    String? supervisorPassword,
    dynamic authDataSource,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final cleanName = name.trim();

    // Check for duplicate code
    final existing = state.distributionCenters.where(
      (d) => d.code.toUpperCase() == cleanCode,
    ).firstOrNull;
    if (existing != null) {
      throw Exception("A distribution center with code '$cleanCode' already exists (${existing.name}). Please choose a unique DC code.");
    }

    final newDc = DistributionCenter(
      id: 'dc-${cleanCode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
      companyId: '11111111-1111-4111-8111-111111111111',
      name: cleanName,
      code: cleanCode,
      state: stateName.trim(),
      city: city.trim(),
      address: address.trim(),
      managerName: managerName?.trim().isNotEmpty == true ? managerName!.trim() : 'Station Supervisor',
      contactPhone: contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000',
      contactEmail: contactEmail?.trim().isNotEmpty == true ? contactEmail!.trim() : (supervisorEmail?.trim() ?? ''),
      isHub: isHub,
      isActive: true,
      storageCapacityUnits: storageCapacityUnits > 0 ? storageCapacityUnits : 25000,
      operatingZones: operatingZones.isNotEmpty ? operatingZones : [city.trim()],
      totalAssignedRiders: 0,
      activeInventoryBatches: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Update in-memory state and local persistent cache
    final updatedList = [
      newDc,
      ...state.distributionCenters.where((d) => d.code != newDc.code && d.id != newDc.id),
    ];
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    // 2. Provision Auth Account for DC Station Supervisor if provided
    final supEmail = (supervisorEmail != null && supervisorEmail.trim().isNotEmpty)
        ? supervisorEmail.trim()
        : (contactEmail?.trim().isNotEmpty == true ? contactEmail!.trim() : 'supervisor.${newDc.code.toLowerCase()}@novaexpress.ng');
    final supPass = (supervisorPassword != null && supervisorPassword.trim().length >= 6)
        ? supervisorPassword.trim()
        : 'Password123!';

    final nameParts = (managerName ?? 'Station Supervisor').trim().split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : 'Station';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Supervisor';

    try {
      if (authDataSource != null) {
        await authDataSource.registerDistributionCenterSupervisor(
          email: supEmail,
          password: supPass,
          firstName: fName,
          lastName: lName,
          phone: contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000',
          distributionCenterId: newDc.id,
          distributionCenterName: newDc.name,
        );
      } else {
        final authDs = AuthRemoteDataSourceImpl(
          SupabaseClient(
            SupabaseConstants.supabaseUrl,
            SupabaseConstants.supabaseServiceRoleKey,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );
        await authDs.registerDistributionCenterSupervisor(
          email: supEmail,
          password: supPass,
          firstName: fName,
          lastName: lName,
          phone: contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000',
          distributionCenterId: newDc.id,
          distributionCenterName: newDc.name,
        );
      }
      debugPrint('[DC_CONSOLE_PROVIDER] 👤 DC Supervisor account provisioned for $supEmail (${newDc.name})');
    } catch (authErr) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Supervisor auth provisioning notice: $authErr');
    }

    // 3. Persist to live Supabase DB
    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await dbClient.from('distribution_centers').upsert({
        'name': newDc.name,
        'code': newDc.code,
        'state': newDc.state,
        'city': newDc.city,
        'address': newDc.address,
        'contact_phone': newDc.contactPhone,
        'contact_email': newDc.contactEmail,
        'manager_name': newDc.managerName,
        'is_hub': newDc.isHub,
        'is_active': newDc.isActive,
        'operating_zones': newDc.operatingZones,
        'storage_capacity_units': newDc.storageCapacityUnits,
        'company_id': newDc.companyId,
      });
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Created Distribution Center "${newDc.name}" (${newDc.code}) in Supabase.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase DC create note: $e');
    } finally {
      dbClient?.dispose();
    }

    return newDc;
  }

  Future<void> updateDistributionCenter(DistributionCenter dc) async {
    final updatedList = state.distributionCenters.map((d) => d.id == dc.id ? dc : d).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dc.id)) {
        await dbClient.from('distribution_centers').update({
          'name': dc.name,
          'code': dc.code,
          'state': dc.state,
          'city': dc.city,
          'address': dc.address,
          'contact_phone': dc.contactPhone,
          'contact_email': dc.contactEmail,
          'manager_name': dc.managerName,
          'is_hub': dc.isHub,
          'is_active': dc.isActive,
          'operating_zones': dc.operatingZones,
          'storage_capacity_units': dc.storageCapacityUnits,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', dc.id);
      } else {
        await dbClient.from('distribution_centers').update({
          'name': dc.name,
          'state': dc.state,
          'city': dc.city,
          'address': dc.address,
          'contact_phone': dc.contactPhone,
          'contact_email': dc.contactEmail,
          'manager_name': dc.managerName,
          'is_hub': dc.isHub,
          'is_active': dc.isActive,
          'operating_zones': dc.operatingZones,
          'storage_capacity_units': dc.storageCapacityUnits,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('code', dc.code);
      }
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Updated Distribution Center "${dc.name}" (${dc.code}) in Supabase.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase DC update note: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive) async {
    final updatedList = state.distributionCenters.map((d) {
      if (d.id == dcId) return d.copyWith(isActive: isActive);
      return d;
    }).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await dbClient.from('distribution_centers').update({'is_active': isActive}).eq('id', dcId);
      }
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Toggled DC "$dcId" active status to $isActive.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase DC toggle note: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> updateOperatingZones(String dcId, List<String> zones) async {
    final updatedList = state.distributionCenters.map((d) {
      if (d.id == dcId) return d.copyWith(operatingZones: zones);
      return d;
    }).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await dbClient.from('distribution_centers').update({'operating_zones': zones}).eq('id', dcId);
      }
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Updated operating zones for DC "$dcId".');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase DC zones note: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  Future<void> deleteDistributionCenter(String dcId) async {
    final updatedList = state.distributionCenters.where((d) => d.id != dcId).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await dbClient.from('distribution_centers').delete().eq('id', dcId);
      debugPrint('[DC_CONSOLE_PROVIDER] 🗑️ Deleted DC "$dcId" from Supabase.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Supabase DC delete note: $e');
    } finally {
      dbClient?.dispose();
    }
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
    _storageService.cacheDriverCompensationTerms(driver.driverCode, driver.toJson());
    if (driver.email.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(driver.email, driver.toJson());
    }
    if (driver.id.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(driver.id, driver.toJson());
    }
  }

  Future<void> updateDriverProfileAndTerms({
    required DCFleetDriver updatedDriver,
    String? newPassword,
  }) async {
    // 1. Update in-memory state & local storage cache
    final updatedList = state.drivers.map((d) {
      final matches = d.id == updatedDriver.id ||
          d.driverCode == updatedDriver.driverCode ||
          (d.email.isNotEmpty && d.email.toLowerCase() == updatedDriver.email.toLowerCase());
      return matches ? updatedDriver : d;
    }).toList();

    state = state.copyWith(drivers: updatedList);
    await _storageService.cacheFleetDrivers(updatedList);
    await _storageService.cacheDriverCompensationTerms(updatedDriver.driverCode, updatedDriver.toJson());
    if (updatedDriver.email.isNotEmpty) {
      await _storageService.cacheDriverCompensationTerms(updatedDriver.email, updatedDriver.toJson());
    }
    if (updatedDriver.id.isNotEmpty) {
      await _storageService.cacheDriverCompensationTerms(updatedDriver.id, updatedDriver.toJson());
    }

    // 2. Register in AuthRemoteDataSource memory so rider logins get custom terms
    final nameParts = updatedDriver.name.trim().split(' ');
    final fName = nameParts.first;
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    AuthRemoteDataSourceImpl.registerUserInMemory(
      UserModel(
        id: updatedDriver.id,
        email: updatedDriver.email,
        firstName: fName,
        lastName: lName,
        phone: updatedDriver.phone,
        role: 'delivery_agent',
        deliveryAgentId: updatedDriver.id,
        deliveryAgentCode: updatedDriver.driverCode,
        personnelType: updatedDriver.personnelType,
        compensationType: updatedDriver.compensationType,
        commissionRate: updatedDriver.commissionRate,
        transportAllowance: updatedDriver.transportAllowance,
        failedDeliveryAllowance: updatedDriver.failedDeliveryAllowance,
        baseSalary: updatedDriver.baseSalary,
        vehicleType: updatedDriver.vehicleType,
        vehiclePlateNumber: updatedDriver.vehiclePlate,
        bankName: updatedDriver.bankName,
        bankAccountNumber: updatedDriver.bankAccountNumber,
        bankAccountName: updatedDriver.bankAccountName,
        agentStatus: updatedDriver.status,
        operatingCity: updatedDriver.assignedZone,
        distributionCenterId: updatedDriver.distributionCenterId,
      ),
      newPassword,
    );

    // 3. Persist to live Supabase DB
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

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

      final baseAgentPayload = {
        'current_status': updatedDriver.status,
        'vehicle_type': updatedDriver.vehicleType,
        'vehicle_plate_number': updatedDriver.vehiclePlate,
        'operating_city': updatedDriver.assignedZone,
        'bank_name': updatedDriver.bankName,
        'bank_account_number': updatedDriver.bankAccountNumber,
        'bank_account_name': updatedDriver.bankAccountName,
        'is_active': updatedDriver.status.toLowerCase() != 'inactive',
      };

      final extendedAgentPayload = {
        ...baseAgentPayload,
        'commission_rate': updatedDriver.commissionRate,
        'transport_allowance': updatedDriver.transportAllowance,
        'failed_delivery_allowance': updatedDriver.failedDeliveryAllowance,
        'base_salary': updatedDriver.baseSalary,
        'personnel_type': updatedDriver.personnelType,
        'compensation_type': updatedDriver.compensationType,
        if (updatedDriver.distributionCenterId != null && updatedDriver.distributionCenterId!.isNotEmpty)
          'distribution_center_id': updatedDriver.distributionCenterId,
      };

      // Update delivery_agents table (attempting full compensation terms first)
      try {
        if (uuidRegex.hasMatch(updatedDriver.id)) {
          await dbClient.from(SupabaseConstants.deliveryAgentsTable).update(extendedAgentPayload).eq('id', updatedDriver.id);
        } else {
          await dbClient.from(SupabaseConstants.deliveryAgentsTable).update(extendedAgentPayload).eq('agent_code', updatedDriver.driverCode);
        }
      } catch (colErr) {
        // Fallback to base columns if extended columns are not yet in Supabase schema
        if (uuidRegex.hasMatch(updatedDriver.id)) {
          await dbClient.from(SupabaseConstants.deliveryAgentsTable).update(baseAgentPayload).eq('id', updatedDriver.id);
        } else {
          await dbClient.from(SupabaseConstants.deliveryAgentsTable).update(baseAgentPayload).eq('agent_code', updatedDriver.driverCode);
        }
      }

      // Update users table (name, phone)
      if (updatedDriver.email.isNotEmpty) {
        await dbClient.from(SupabaseConstants.usersTable).update({
          'first_name': fName,
          'last_name': lName,
          'phone_number': updatedDriver.phone,
        }).eq('email', updatedDriver.email.toLowerCase().trim());
      }

      // If new password provided, update Supabase auth user
      if (newPassword != null && newPassword.length >= 6 && updatedDriver.email.isNotEmpty) {
        try {
          final usersRes = await dbClient.auth.admin.listUsers();
          final targetUser = usersRes.firstWhere(
            (u) => u.email?.toLowerCase() == updatedDriver.email.toLowerCase(),
            orElse: () => throw Exception('User not found in auth'),
          );
          await dbClient.auth.admin.updateUserById(
            targetUser.id,
            attributes: AdminUserAttributes(password: newPassword),
          );
          debugPrint('[DC_CONSOLE_PROVIDER] 🔑 Password updated in Supabase Auth for ${updatedDriver.email}');
        } catch (pwErr) {
          debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Password update notice ($pwErr)');
        }
      }

      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Driver ${updatedDriver.name} (${updatedDriver.driverCode}) terms & profile updated (Commission: ₦${updatedDriver.commissionRate}, Transport: ₦${updatedDriver.transportAllowance}).');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ updateDriverProfile notice: $e');
    } finally {
      dbClient?.dispose();
    }
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
        // 1. Seed with in-memory / cached drivers (which already have custom terms)
        for (final d in state.drivers) {
          final emailKey = d.email.isNotEmpty ? d.email.toLowerCase() : '';
          final codeKey = d.driverCode.isNotEmpty ? d.driverCode.toLowerCase() : '';
          final idKey = d.id.isNotEmpty ? d.id.toLowerCase() : '';
          if (emailKey.isNotEmpty) driverMap[emailKey] = d;
          if (codeKey.isNotEmpty) driverMap[codeKey] = d;
          if (idKey.isNotEmpty) driverMap[idKey] = d;
        }

        final cachedTerms = await _storageService.getCachedDriverCompensationTerms();

        // 2. Intelligently merge DB driver with custom terms
        final Map<String, DCFleetDriver> mergedByKey = {};

        for (final dbD in dbDrivers) {
          final emailKey = dbD.email.isNotEmpty ? dbD.email.toLowerCase() : '';
          final codeKey = dbD.driverCode.isNotEmpty ? dbD.driverCode.toLowerCase() : '';
          final idKey = dbD.id.isNotEmpty ? dbD.id.toLowerCase() : '';

          final existing = (emailKey.isNotEmpty ? driverMap[emailKey] : null) ??
              (codeKey.isNotEmpty ? driverMap[codeKey] : null) ??
              (idKey.isNotEmpty ? driverMap[idKey] : null);

          Map<String, dynamic>? termsMap;
          if (cachedTerms != null) {
            if (emailKey.isNotEmpty && cachedTerms.containsKey(emailKey)) {
              termsMap = cachedTerms[emailKey];
            } else if (codeKey.isNotEmpty && cachedTerms.containsKey(codeKey)) {
              termsMap = cachedTerms[codeKey];
            } else if (idKey.isNotEmpty && cachedTerms.containsKey(idKey)) {
              termsMap = cachedTerms[idKey];
            }
          }

          // Resolve custom compensation terms without defaulting
          final comm = existing?.commissionRate ??
              (termsMap?['commission_rate'] as num?)?.toDouble() ??
              dbD.commissionRate;

          final trans = existing?.transportAllowance ??
              (termsMap?['transport_allowance'] as num?)?.toDouble() ??
              dbD.transportAllowance;

          final failed = existing?.failedDeliveryAllowance ??
              (termsMap?['failed_delivery_allowance'] as num?)?.toDouble() ??
              dbD.failedDeliveryAllowance;

          final salary = existing?.baseSalary ??
              (termsMap?['base_salary'] as num?)?.toDouble() ??
              dbD.baseSalary;

          final pType = existing?.personnelType ??
              termsMap?['personnel_type'] as String? ??
              dbD.personnelType;

          final cType = existing?.compensationType ??
              termsMap?['compensation_type'] as String? ??
              dbD.compensationType;

          final lgas = (existing != null && existing.coveredLgas.isNotEmpty)
              ? existing.coveredLgas
              : (termsMap?['covered_lgas'] as List?)?.map((e) => e.toString()).toList() ?? dbD.coveredLgas;

          final dcId = existing?.distributionCenterId ??
              termsMap?['distribution_center_id'] as String? ??
              dbD.distributionCenterId;

          final mergedDriver = dbD.copyWith(
            commissionRate: comm,
            transportAllowance: trans,
            failedDeliveryAllowance: failed,
            baseSalary: salary,
            personnelType: pType,
            compensationType: cType,
            coveredLgas: lgas,
            distributionCenterId: dcId,
          );

          final primaryKey = emailKey.isNotEmpty ? emailKey : codeKey;
          mergedByKey[primaryKey] = mergedDriver;

          // Also keep AuthRemoteDataSource in-memory registry updated for instant login
          final nameParts = mergedDriver.name.trim().split(' ');
          final fName = nameParts.first;
          final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          AuthRemoteDataSourceImpl.registerUserInMemory(
            UserModel(
              id: mergedDriver.id,
              email: mergedDriver.email,
              firstName: fName,
              lastName: lName,
              phone: mergedDriver.phone,
              role: 'delivery_agent',
              deliveryAgentId: mergedDriver.id,
              deliveryAgentCode: mergedDriver.driverCode,
              personnelType: pType,
              compensationType: cType,
              commissionRate: comm,
              transportAllowance: trans,
              failedDeliveryAllowance: failed,
              baseSalary: salary,
              vehicleType: mergedDriver.vehicleType,
              vehiclePlateNumber: mergedDriver.vehiclePlate,
              bankName: mergedDriver.bankName,
              bankAccountNumber: mergedDriver.bankAccountNumber,
              bankAccountName: mergedDriver.bankAccountName,
              agentStatus: mergedDriver.status,
              operatingCity: mergedDriver.assignedZone,
              distributionCenterId: dcId,
            ),
          );
        }

        // Add any locally added drivers not in DB yet
        for (final d in state.drivers) {
          final emailKey = d.email.isNotEmpty ? d.email.toLowerCase() : '';
          final codeKey = d.driverCode.isNotEmpty ? d.driverCode.toLowerCase() : '';
          final primaryKey = emailKey.isNotEmpty ? emailKey : codeKey;
          if (!mergedByKey.containsKey(primaryKey)) {
            mergedByKey[primaryKey] = d;
          }
        }

        final mergedList = mergedByKey.values.toList();
        state = state.copyWith(drivers: mergedList, isLoading: false);
        await _storageService.cacheFleetDrivers(mergedList);
        debugPrint('[DC_CONSOLE_PROVIDER] 🚚 Loaded ${dbDrivers.length} active fleet drivers from live Supabase DB (Total active fleet: ${mergedList.length}) and merged custom compensation terms.');
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

      // 3. Fetch Cash Remittances (Automated Paystack Virtual Account & POS Handover)
      try {
        final remRes = await dbClient
            .from(SupabaseConstants.cashRemittancesTable)
            .select('*, delivery_agents(agent_code, current_cod_balance, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);

        for (final row in (remRes as List)) {
          try {
            final isVerified = row['is_verified'] == true ||
                row['status'] == 'verified' ||
                row['status'] == 'settled' ||
                row['status'] == 'approved' ||
                row['status'] == 'remitted' ||
                row['status'] == 'success' ||
                row['status'] == 'completed';
            final bool isPartial = row['is_partial'] == true ||
                row['status'] == 'partial' ||
                row['status'] == 'partial_remittance' ||
                (row['discrepancy_amount'] != null && (row['discrepancy_amount'] as num) < -0.01) ||
                (row['expected_amount'] != null && (row['expected_amount'] as num) > (row['amount'] as num? ?? 0));
            final double? expectedAmt = (row['expected_amount'] as num?)?.toDouble();
            final double? discrepancyAmt = (row['discrepancy_amount'] as num?)?.toDouble();
            final String? discrepancyRsn = row['discrepancy_reason']?.toString();
            final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
            final dynamic rawPosFee = row['pos_fee'] ?? row['transaction_fee'];
            final double posFee = (rawPosFee is num) ? rawPosFee.toDouble() : (amt > 0 ? (amt / 5000.0).ceil() * 100.0 : 350.0);

            allTxns.add(DCTransactionRecord(
              id: row['id']?.toString() ?? '',
              transactionCode: row['remittance_number']?.toString() ?? 'REM-${row['id']?.toString().substring(0, 5)}',
              riderId: row['delivery_agent_id']?.toString() ?? '',
              riderName: (row['delivery_agents'] is Map && row['delivery_agents']['users'] is Map)
                  ? '${row['delivery_agents']['users']['first_name'] ?? ''} ${row['delivery_agents']['users']['last_name'] ?? ''}'.trim()
                  : 'Delivery Agent',
              riderCode: (row['delivery_agents'] is Map) ? row['delivery_agents']['agent_code']?.toString() ?? 'PDA-7000' : 'PDA-7000',
              amount: amt,
              transactionFee: posFee,
              feeType: 'pos_agent',
              category: 'remittance',
              paymentMethod: row['payment_method']?.toString() ?? 'bank_transfer',
              gatewayReference: row['reference_number']?.toString(),
              channel: row['payment_method']?.toString() == 'paystack' ? 'Titan Trust / Paystack' : 'POS Agent Handover',
              status: isPartial ? 'partial' : (isVerified ? 'remitted' : (row['status']?.toString() ?? 'pending')),
              isCredit: false,
              isPartial: isPartial,
              expectedAmount: expectedAmt,
              discrepancyAmount: discrepancyAmt,
              discrepancyReason: discrepancyRsn,
              notes: row['notes']?.toString(),
              createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
            ));
          } catch (_) {}
        }
      } catch (_) {}

      // 4. Fetch Delivered / Prepaid Orders (Paystack Direct & Cash POD)
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
          final totalAmt = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
          final pstkFee = isPstk ? (totalAmt * 0.015).clamp(100.0, 2000.0) : 0.0;

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
            amount: totalAmt,
            commission: (ord['agent_commission'] as num?)?.toDouble() ?? 1000.0,
            transportAllowance: (ord['agent_transport_allowance'] as num?)?.toDouble() ?? 1500.0,
            transactionFee: pstkFee,
            feeType: isPstk ? 'paystack' : 'none',
            category: isPstk ? 'paystack_direct' : 'cash_pod',
            paymentMethod: pMethod,
            gatewayReference: 'PSTK-${ord['order_number']}',
            channel: isPstk ? 'Titan Trust / Paystack' : 'Cash in Hand (COD)',
            status: isPstk
                ? (ord['payment_status']?.toString() == 'paid' || ord['status']?.toString() == 'delivered' ? 'settled' : 'pending')
                : (ord['status']?.toString() == 'delivered' ? 'remitted' : 'pending'),
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

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'cli-gen-$now';
  }
}

final dcConsoleProvider = StateNotifierProvider<DCConsoleNotifier, DCConsoleState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return DCConsoleNotifier(storage);
});
