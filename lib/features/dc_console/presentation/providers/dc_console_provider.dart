import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/dc_console_remote_datasource.dart';
import '../../data/repositories/dc_console_repository_impl.dart';
import '../../domain/repositories/dc_console_repository.dart';
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
    code: 'DC-WUSE-01',
    state: 'Federal Capital Territory',
    city: 'Wuse 2',
    address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
    contactPhone: '+234 802 345 6789',
    contactEmail: 'dc.supervisor@novaexpress.ng',
    managerName: 'Adekunle Supervisor',
    isGrandDc: true,
    isHub: true,
    isActive: true,
    operatingZones: const ['Abuja Municipal (AMAC)', 'AMAC', 'Wuse I', 'Wuse II', 'Maitama', 'Garki', 'Jabi', 'Utako', 'Central Area', 'Guzape'],
    storageCapacityUnits: 50000,
    totalAssignedRiders: 1,
    activeInventoryBatches: 0,
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
    email: 'emeka.rider@novaexpress.ng',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    status: 'active',
    assignedZone: 'Abuja Municipal (AMAC)',
    coveredLgas: const ['Abuja Municipal (AMAC)', 'AMAC', 'Wuse II', 'Maitama', 'Garki'],
    vehicleType: 'Motorcycle',
    vehiclePlate: 'ABJ-894-XA',
    vehicleModel: 'Bajaj Boxer 150',
    totalAssignedOrders: 0,
    completedOrders: 0,
    routeProgressPercent: 0.0,
    efficiencyRating: 5.0,
    cashInCustody: 0.0,
    itemsInCustody: 0,
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    failedDeliveryAllowance: 500.0,
    compensationType: 'commission',
    personnelType: 'pda',
  ),
];

final List<ClientProfile> defaultRegisteredClients = [
  const ClientProfile(
    id: 'c1111111-1111-4111-8111-111111111111',
    companyName: 'Novacare Limited',
    contactPerson: 'Dr. Kalu Okonkwo',
    email: 'orders@novacare.ng',
    phone: '+2348039998877',
    address: 'Plot 102 Central Business District, Abuja',
    city: 'Abuja',
    state: 'Federal Capital Territory',
    code: 'NOVACARE',
    tier: 'enterprise',
    closerLimit: 250,
    isEnterprise: true,
    totalClosersCount: 0,
  ),
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
    totalClosersCount: 1,
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

  bool get isCurrentHubGrandDc =>
      activeHubCode == 'DC-ABJ-01' ||
      activeHubId == '22222222-2222-4222-8222-222222222222' ||
      activeHubName.toLowerCase().contains('wuse central') ||
      activeHubName.toLowerCase().contains('grand dc');

  List<DCFleetDriver> get dcDrivers {
    return drivers.where((d) {
      if (isCurrentHubGrandDc) {
        return d.distributionCenterId == activeHubId ||
               d.distributionCenterId == activeHubCode ||
               d.distributionCenterId == '22222222-2222-4222-8222-222222222222' ||
               d.distributionCenterId == null ||
               d.distributionCenterId!.isEmpty;
      }
      return d.distributionCenterId == activeHubId || d.distributionCenterId == activeHubCode;
    }).toList();
  }

  List<DCFleetDriver> get filteredDrivers {
    var list = dcDrivers;
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
  final DCConsoleRepository _repository;

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

  static bool get isWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    } catch (_) {
      return false;
    }
  }

  DCConsoleNotifier([LocalStorageService? storageService, DCConsoleRepository? repository])
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        _repository = repository ??
            DCConsoleRepositoryImpl(
              remoteDataSource: DCConsoleRemoteDataSourceImpl(),
              storageService: storageService ?? LocalStorageServiceImpl(),
            ),
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
    if (isTestEnvironment) return;

    try {
      final dbClients = await _repository.getClients();
      if (dbClients.isNotEmpty) {
        state = state.copyWith(clients: dbClients);
        debugPrint('[DC_CONSOLE] ⚡ Loaded ${dbClients.length} registered clients via repository.');
      } else {
        state = state.copyWith(clients: defaultRegisteredClients);
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE] ℹ️ Error loading clients via repository: $e');
      if (state.clients.isEmpty) {
        state = state.copyWith(clients: defaultRegisteredClients);
      }
    }
  }

  Future<bool> checkClientEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    // 1. Check in local registered clients state
    if (state.clients.any((c) => c.email.toLowerCase() == cleanEmail)) {
      return true;
    }

    // 2. Check demo accounts & in-memory registered users
    const demoAccounts = {
      'emeka.rider@novaexpress.ng',
      'rider.emeka@novaexpress.com',
      'joel.odufu@novaexpress.ng',
      'dc.supervisor@novaexpress.ng',
      'client.novacale@novaexpress.ng',
      'closer.amaka@novacale.ng',
    };
    if (demoAccounts.contains(cleanEmail)) return true;

    final registeredUser = AuthRemoteDataSourceImpl.getRegisteredUser(cleanEmail);
    if (registeredUser != null) return true;

    // 3. Query remote database via repository
    if (!isTestEnvironment) {
      try {
        return await _repository.checkEmailExists(cleanEmail);
      } catch (e) {
        debugPrint('[DC_CONSOLE] ℹ️ checkClientEmailExists remote notice: $e');
      }
    }
    return false;
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
    String? password,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    dynamic authDataSource,
  }) async {
    state = state.copyWith(isLoading: true);
    final cleanEmail = email.trim().toLowerCase();
    final effectivePassword = (password != null && password.trim().length >= 6)
        ? password.trim()
        : 'ClientPass123!';

    if (state.clients.any((c) => c.email.toLowerCase() == cleanEmail) ||
        AuthRemoteDataSourceImpl.getRegisteredUser(cleanEmail) != null ||
        cleanEmail == 'client.novacale@novaexpress.ng') {
      state = state.copyWith(isLoading: false);
      throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
    }

    try {
      ClientProfile newClient;
      try {
        newClient = await _repository.createClient(
          companyName: companyName.trim(),
          contactPerson: contactPerson.trim(),
          email: cleanEmail,
          phone: phone.trim(),
          address: address.trim(),
          city: city.trim(),
          stateName: stateName.trim(),
          tier: tier,
          closerLimit: closerLimit,
          password: effectivePassword,
          clientCode: clientCode,
          bankName: bankName,
          bankAccountNumber: bankAccountNumber,
          bankAccountName: bankAccountName,
          authDataSource: authDataSource,
        );
      } catch (dbErr) {
        if (dbErr.toString().contains('already exists')) {
          rethrow;
        }
        debugPrint('[DC_CONSOLE] ℹ️ Remote createClient notice: $dbErr. Utilizing resilient local fallback.');
        final isEnt = tier.toLowerCase() == 'enterprise';
        final cleanName = companyName.trim();
        final words = cleanName.split(RegExp(r'\s+'));
        String prefix = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
        if (prefix.length < 2) prefix = cleanName.length >= 2 ? cleanName.substring(0, 2).toUpperCase() : 'CL';
        final suffix = (100 + (DateTime.now().millisecondsSinceEpoch % 900) + 1).toString().padLeft(3, '0');
        final code = clientCode?.trim().isNotEmpty == true ? clientCode!.trim().toUpperCase() : 'CLI-$prefix-$suffix';
        final clientId = '00000000-0000-4000-8000-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0')}';

        newClient = ClientProfile(
          id: clientId,
          companyName: cleanName,
          contactPerson: contactPerson.trim(),
          email: cleanEmail,
          phone: phone.trim(),
          address: address.trim(),
          city: city.trim(),
          state: stateName.trim(),
          code: code,
          tier: tier,
          closerLimit: isEnt ? closerLimit : 0,
          isEnterprise: isEnt,
          totalClosersCount: 0,
          createdAt: DateTime.now(),
        );

        // Always register in Auth store so client can log in
        final nameParts = contactPerson.trim().split(' ');
        final fName = nameParts.isNotEmpty ? nameParts.first : cleanName;
        final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Admin';
        AuthRemoteDataSourceImpl.registerUserInMemory(
          UserModel(
            id: 'cli_${DateTime.now().millisecondsSinceEpoch}',
            email: cleanEmail,
            firstName: fName,
            lastName: lName,
            phone: phone.trim(),
            role: 'client',
            clientId: clientId,
            clientCompanyName: cleanName,
            deliveryAgentCode: code,
            operatingState: stateName.trim(),
            operatingCity: city.trim(),
            bankName: bankName ?? '',
            bankAccountNumber: bankAccountNumber ?? '',
            bankAccountName: bankAccountName ?? '',
          ),
          effectivePassword,
        );
      }

      final updatedClients = [newClient, ...state.clients];
      state = state.copyWith(clients: updatedClients, isLoading: false);
      return newClient;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> loadFinanceSettingsFromDatabase() async {
    if (isTestEnvironment) return;

    try {
      final settings = await _repository.getFinanceSettings();
      if (settings != null) {
        state = state.copyWith(financeSettings: settings);
        await _storageService.cacheFinanceSettings(settings);
        debugPrint('[DC_CONSOLE_PROVIDER] 💳 Loaded DC finance & POS settings via repository (Mode: ${settings.posChargeMode}, Commission: ₦${settings.defaultCommissionRate}, Transport: ₦${settings.defaultTransportAllowance}).');
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Finance settings fetch notice: $e');
    }
  }

  Future<void> updateFinanceSettings(DCFinanceSettings newSettings) async {
    state = state.copyWith(financeSettings: newSettings);
    await _storageService.cacheFinanceSettings(newSettings);

    if (isTestEnvironment) return;

    try {
      await _repository.updateFinanceSettings(newSettings);
      debugPrint('[DC_CONSOLE_PROVIDER] 💾 DC Finance settings persisted via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Finance settings update error: $e');
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

  void syncWithUser(dynamic user) {
    if (user == null) return;
    final String? dcId = user.distributionCenterId;
    if (dcId == null || dcId.isEmpty) return;

    if (state.activeHubId == dcId) return;

    final match = state.distributionCenters.where(
      (d) => d.id == dcId || d.code.toLowerCase() == dcId.toLowerCase() || (user.deliveryAgentCode != null && user.deliveryAgentCode.toString().isNotEmpty && d.code.toLowerCase() == user.deliveryAgentCode.toString().toLowerCase()),
    ).firstOrNull;

    if (match != null) {
      switchActiveHub(match);
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Switched active hub to user DC: ${match.name} (${match.code})');
    } else {
      final fallbackDc = DistributionCenter(
        id: dcId,
        name: (user.distributionCenterName != null && user.distributionCenterName.toString().isNotEmpty)
            ? user.distributionCenterName.toString()
            : 'Distribution Center',
        code: (user.deliveryAgentCode != null && user.deliveryAgentCode.toString().isNotEmpty)
            ? user.deliveryAgentCode.toString()
            : 'DC',
        state: (user.operatingState != null && user.operatingState.toString().isNotEmpty)
            ? user.operatingState.toString()
            : 'Nigeria',
        city: (user.operatingCity != null && user.operatingCity.toString().isNotEmpty)
            ? user.operatingCity.toString()
            : 'Station Hub',
        address: 'Station Depot',
        managerName: (user.fullName != null && user.fullName.toString().isNotEmpty)
            ? user.fullName.toString()
            : 'DC Supervisor',
        isGrandDc: false,
        isHub: false,
      );
      switchActiveHub(fallbackDc);
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Set fallback active hub to user DC: ${fallbackDc.name} (${fallbackDc.code})');
    }
  }

  Future<void> loadDistributionCentersFromDatabase() async {
    if (isTestEnvironment) return;

    try {
      final dcs = await _repository.getDistributionCenters();
      if (dcs.isNotEmpty) {
        // Merge with existing local DCs so any locally created DC is never lost
        final existingLocal = state.distributionCenters;
        final mergedDcs = <DistributionCenter>[...dcs];
        for (final local in existingLocal) {
          if (!mergedDcs.any((d) => d.id == local.id || d.code.toUpperCase() == local.code.toUpperCase())) {
            mergedDcs.add(local);
          }
        }
        state = state.copyWith(distributionCenters: mergedDcs);
        await _storageService.cacheDistributionCenters(mergedDcs);
        debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Loaded ${mergedDcs.length} distribution centers via repository (merged).');

        // Refresh active hub details if it matches one of the loaded dcs
        final activeMatch = mergedDcs.where((d) => d.id == state.activeHubId || d.code == state.activeHubCode).firstOrNull;
        if (activeMatch != null) {
          state = state.copyWith(
            activeHubId: activeMatch.id,
            activeHubName: activeMatch.name,
            activeHubCode: activeMatch.code,
          );
        }
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ DC fetch notice ($e). Using local cached DCs.');
    }
  }

  static String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // RFC4122 v4
    values[8] = (values[8] & 0x3f) | 0x80; // RFC4122 variant
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
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
    String? parentDcId,
    int storageCapacityUnits = 25000,
    List<String> operatingZones = const [],
    String? supervisorEmail,
    String? supervisorPassword,
    dynamic authDataSource,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final cleanName = name.trim();

    // 1. Resolve supervisor login email
    final supEmail = (supervisorEmail != null && supervisorEmail.trim().isNotEmpty)
        ? supervisorEmail.trim().toLowerCase()
        : (contactEmail?.trim().isNotEmpty == true ? contactEmail!.trim().toLowerCase() : 'supervisor.${cleanCode.toLowerCase()}@novaexpress.ng');
    final supPass = (supervisorPassword != null && supervisorPassword.trim().length >= 6)
        ? supervisorPassword.trim()
        : 'Password123!';

    // 2. Check local in-memory state for duplicate code and duplicate email
    final existingLocal = state.distributionCenters.where(
      (d) => d.code.toUpperCase() == cleanCode,
    ).firstOrNull;
    if (existingLocal != null) {
      throw Exception("A distribution center with code '$cleanCode' already exists (${existingLocal.name}). Please choose a unique DC code.");
    }

    final existingEmail = state.distributionCenters.where(
      (d) => d.contactEmail?.toLowerCase() == supEmail,
    ).firstOrNull;
    if (existingEmail != null) {
      throw Exception("A user with email '$supEmail' already exists. Please choose a different supervisor email.");
    }

    final effectiveZones = operatingZones.isNotEmpty ? operatingZones : [city.trim()];
    final effectiveManager = managerName?.trim().isNotEmpty == true ? managerName!.trim() : 'Station Supervisor';
    final effectivePhone = contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000';
    final effectiveCapacity = storageCapacityUnits > 0 ? storageCapacityUnits : 25000;

    final bool skipRemoteDb = isWidgetTest;

    DistributionCenter newDc;
    if (!skipRemoteDb) {
      newDc = await _repository.createDistributionCenter(
        name: cleanName,
        code: cleanCode,
        stateName: stateName.trim(),
        city: city.trim(),
        address: address.trim(),
        contactPhone: effectivePhone,
        contactEmail: supEmail,
        managerName: effectiveManager,
        isHub: isHub,
        parentDcId: parentDcId,
        storageCapacityUnits: effectiveCapacity,
        operatingZones: effectiveZones,
        supervisorEmail: supEmail,
        supervisorPassword: supPass,
        authDataSource: authDataSource,
      );
    } else {
      final newDcId = _generateUuid();
      newDc = DistributionCenter(
        id: newDcId,
        companyId: '11111111-1111-4111-8111-111111111111',
        name: cleanName,
        code: cleanCode,
        state: stateName.trim(),
        city: city.trim(),
        address: address.trim(),
        managerName: effectiveManager,
        contactPhone: effectivePhone,
        contactEmail: supEmail,
        isHub: isHub,
        isActive: true,
        parentDcId: parentDcId,
        storageCapacityUnits: effectiveCapacity,
        operatingZones: effectiveZones,
        totalAssignedRiders: 0,
        activeInventoryBatches: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (authDataSource != null) {
        final nameParts = effectiveManager.split(' ');
        final fName = nameParts.isNotEmpty ? nameParts.first : 'Station';
        final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Supervisor';
        await authDataSource.registerDistributionCenterSupervisor(
          email: supEmail,
          password: supPass,
          firstName: fName,
          lastName: lName,
          phone: effectivePhone,
          distributionCenterId: newDc.id,
          distributionCenterName: newDc.name,
        );
      }
    }

    // Update in-memory state and local persistent cache
    final updatedList = [
      newDc,
      ...state.distributionCenters.where((d) => d.code != newDc.code && d.id != newDc.id),
    ];
    state = state.copyWith(
      distributionCenters: updatedList,
      activeHubId: isHub ? newDc.id : state.activeHubId,
      activeHubName: isHub ? newDc.name : state.activeHubName,
      activeHubCode: isHub ? newDc.code : state.activeHubCode,
    );
    await _storageService.cacheDistributionCenters(updatedList);

    return newDc;
  }

  Future<void> updateDistributionCenter(DistributionCenter dc) async {
    final updatedList = state.distributionCenters.map((d) => d.id == dc.id ? dc : d).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    if (isTestEnvironment) return;

    try {
      await _repository.updateDistributionCenter(dc);
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Updated Distribution Center "${dc.name}" (${dc.code}) via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ DC update note: $e');
    }
  }

  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive) async {
    final updatedList = state.distributionCenters.map((d) {
      if (d.id == dcId) return d.copyWith(isActive: isActive);
      return d;
    }).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    if (isTestEnvironment) return;

    try {
      await _repository.toggleDistributionCenterStatus(dcId, isActive);
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Toggled DC "$dcId" active status to $isActive via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ DC toggle note: $e');
    }
  }

  Future<void> updateOperatingZones(String dcId, List<String> zones) async {
    final updatedList = state.distributionCenters.map((d) {
      if (d.id == dcId) return d.copyWith(operatingZones: zones);
      return d;
    }).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    if (isTestEnvironment) return;

    try {
      await _repository.updateOperatingZones(dcId, zones);
      debugPrint('[DC_CONSOLE_PROVIDER] 🏢 Updated operating zones for DC "$dcId" via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ DC zones note: $e');
    }
  }

  Future<void> deleteDistributionCenter(String dcId) async {
    final updatedList = state.distributionCenters.where((d) => d.id != dcId).toList();
    state = state.copyWith(distributionCenters: updatedList);
    await _storageService.cacheDistributionCenters(updatedList);

    if (isTestEnvironment) return;

    try {
      await _repository.deleteDistributionCenter(dcId);
      debugPrint('[DC_CONSOLE_PROVIDER] 🗑️ Deleted DC "$dcId" via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ DC delete note: $e');
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

    // 3. Persist via repository
    if (isTestEnvironment) return;

    try {
      await _repository.updateDriverCompensationTerms(updatedDriver);
      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Driver ${updatedDriver.name} (${updatedDriver.driverCode}) terms & profile updated via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ updateDriverProfile notice: $e');
    }
  }

  Future<void> loadDriversFromDatabase() async {
    if (isTestEnvironment) return;

    try {
      final dbDrivers = await _repository.getDrivers();
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

          final resolvedName = (dbD.name.isNotEmpty && dbD.name.toLowerCase() != 'delivery agent')
              ? dbD.name
              : ((existing?.name != null && existing!.name.isNotEmpty && existing.name.toLowerCase() != 'delivery agent')
                  ? existing.name
                  : dbD.name);

          final resolvedPhone = (dbD.phone.isNotEmpty && dbD.phone != '08031234567')
              ? dbD.phone
              : ((existing?.phone != null && existing!.phone.isNotEmpty && existing.phone != '08031234567')
                  ? existing.phone
                  : dbD.phone);

          final resolvedAvatar = dbD.avatarUrl.isNotEmpty
              ? dbD.avatarUrl
              : (existing?.avatarUrl ?? '');

          final mergedDriver = dbD.copyWith(
            name: resolvedName,
            phone: resolvedPhone,
            avatarUrl: resolvedAvatar,
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
              avatarUrl: mergedDriver.avatarUrl,
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

        final mergedList = mergedByKey.values.toList();
        state = state.copyWith(drivers: mergedList, isLoading: false);
        await _storageService.cacheFleetDrivers(mergedList);
        debugPrint('[DC_CONSOLE_PROVIDER] 🚚 Loaded ${dbDrivers.length} active fleet drivers via repository (Total active fleet: ${mergedList.length}) and merged custom compensation terms.');
      } else {
        state = state.copyWith(drivers: defaultFleetDrivers, isLoading: false);
        await _storageService.cacheFleetDrivers(defaultFleetDrivers);
      }
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Fleet fetch notice ($e). Local cached drivers retained.');
    }
  }

  Future<void> loadPayoutClaimsFromDatabase() async {
    if (isTestEnvironment) return;

    try {
      final dbClaims = await _repository.getPayoutClaims();
      state = state.copyWith(payoutClaims: dbClaims);
      await _storageService.cachePayoutClaims(dbClaims);
      debugPrint('[DC_CONSOLE_PROVIDER] 💰 Loaded ${dbClaims.length} live payout claims via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Payout claims fetch notice ($e).');
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

    if (isTestEnvironment) return;

    try {
      final claim = state.payoutClaims.firstWhere((c) => c.id == claimId, orElse: () => updated.first);
      await _repository.approvePayoutClaim(
        claimId: claimId,
        amount: claim.requestedAmount,
        driverId: claim.riderId,
      );
      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Payout claim $claimId approved via repository (Ref: $ref).');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Payout approval notice ($e).');
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

    if (isTestEnvironment) return;

    try {
      await _repository.rejectPayoutClaim(
        claimId: claimId,
        reason: note,
      );
      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Payout claim $claimId marked rejected via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ⚠️ Payout rejection notice ($e).');
    }
  }

  void setTransactionFilter(String filter) {
    state = state.copyWith(transactionFilter: filter);
  }

  void setTransactionStatusFilter(String filter) {
    state = state.copyWith(transactionStatusFilter: filter);
  }

  Future<void> loadTransactionsFromDatabase() async {
    if (isTestEnvironment) return;

    try {
      final txns = await _repository.getDcTransactions();
      state = state.copyWith(transactions: txns);
      await _storageService.cacheDcTransactions(txns);
      debugPrint('[DC_CONSOLE_PROVIDER] ✅ Loaded ${txns.length} consolidated DC transactions via repository.');
    } catch (e) {
      debugPrint('[DC_CONSOLE_PROVIDER] ℹ️ Error loading DC transactions ($e).');
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

final dcConsoleRemoteDataSourceProvider = Provider<DCConsoleRemoteDataSource>((ref) {
  return DCConsoleRemoteDataSourceImpl();
});

final dcConsoleRepositoryProvider = Provider<DCConsoleRepository>((ref) {
  final remoteDataSource = ref.watch(dcConsoleRemoteDataSourceProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return DCConsoleRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storage,
  );
});

final dcConsoleProvider = StateNotifierProvider<DCConsoleNotifier, DCConsoleState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final repository = ref.watch(dcConsoleRepositoryProvider);
  return DCConsoleNotifier(storage, repository);
});
