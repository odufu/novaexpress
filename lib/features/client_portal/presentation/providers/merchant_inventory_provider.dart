import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/helpers/uuid_helper.dart';
import '../../../admin_console/data/datasources/admin_remote_datasource.dart';
import '../../../admin_console/domain/entities/admin_models.dart';
import '../../../admin_console/domain/entities/crm_agents_roster.dart';
import '../../domain/entities/merchant_inventory_models.dart';

class MerchantInventoryState {
  final bool isLoading;
  final String merchantName;
  final String merchantId;
  final String selectedDcFilter;
  final String searchQuery;
  final int activeTab; // 0: DC Shelves & Velocity, 1: Inbound Consignments, 2: Agent Balancing
  final List<MerchantProductStockView> products;
  final List<MerchantPartnerAgent> agents;
  final List<MerchantInboundShipment> inboundShipments;
  final List<MerchantAgentSalesRecord> salesRecords;
  final MerchantPartnerAgent? selectedAgent;
  final String? errorMessage;
  final String? successMessage;

  const MerchantInventoryState({
    this.isLoading = false,
    this.merchantName = 'Novacare Limited',
    this.merchantId = '00000000-0000-4000-8000-791731264594',
    this.selectedDcFilter = 'All Warehouses',
    this.searchQuery = '',
    this.activeTab = 0,
    this.products = const [],
    this.agents = const [],
    this.inboundShipments = const [],
    this.salesRecords = const [],
    this.selectedAgent,
    this.errorMessage,
    this.successMessage,
  });

  // KPI Calculations
  int get totalInDcShelves => products.fold(0, (sum, p) => sum + p.totalInDcShelves);
  int get totalInAgentCustody => products.fold(0, (sum, p) => sum + p.totalInAgentCustody);
  int get totalDefectiveQuarantine => products.fold(0, (sum, p) => sum + p.totalDefectiveUnits);
  int get totalSystemStock => totalInDcShelves + totalInAgentCustody;
  double get totalStockValuation => products.fold(0.0, (sum, p) => sum + p.totalValuation);

  int get totalSalesDeliveredToday {
    final today = DateTime.now();
    return salesRecords.where((r) {
      return r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day;
    }).fold(0, (sum, r) => sum + r.unitsSold);
  }

  int get totalPendingInboundUnits {
    return inboundShipments
        .where((s) => s.isInTransit)
        .fold(0, (sum, s) => sum + s.expectedQuantity);
  }

  int get flaggedDiscrepancyCount {
    return salesRecords.where((r) => r.discrepancyFlagged).length;
  }

  List<MerchantProductStockView> get filteredProducts {
    var list = products;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<MerchantInboundShipment> get filteredInboundShipments {
    var list = inboundShipments;
    if (selectedDcFilter != 'All Warehouses') {
      list = list.where((s) => s.targetDcName.toLowerCase().contains(selectedDcFilter.toLowerCase())).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((s) =>
          s.waybillNumber.toLowerCase().contains(q) ||
          s.productName.toLowerCase().contains(q) ||
          s.sku.toLowerCase().contains(q) ||
          s.carrierDriverName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  MerchantInventoryState copyWith({
    bool? isLoading,
    String? merchantName,
    String? merchantId,
    String? selectedDcFilter,
    String? searchQuery,
    int? activeTab,
    List<MerchantProductStockView>? products,
    List<MerchantPartnerAgent>? agents,
    List<MerchantInboundShipment>? inboundShipments,
    List<MerchantAgentSalesRecord>? salesRecords,
    MerchantPartnerAgent? selectedAgent,
    String? errorMessage,
    String? successMessage,
  }) {
    return MerchantInventoryState(
      isLoading: isLoading ?? this.isLoading,
      merchantName: merchantName ?? this.merchantName,
      merchantId: merchantId ?? this.merchantId,
      selectedDcFilter: selectedDcFilter ?? this.selectedDcFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
      products: products ?? this.products,
      agents: agents ?? this.agents,
      inboundShipments: inboundShipments ?? this.inboundShipments,
      salesRecords: salesRecords ?? this.salesRecords,
      selectedAgent: selectedAgent ?? this.selectedAgent,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class MerchantInventoryNotifier extends StateNotifier<MerchantInventoryState> {
  final AdminRemoteDataSource _dataSource = AdminRemoteDataSource();

  MerchantInventoryNotifier() : super(const MerchantInventoryState()) {
    _initializeDefaultData();
  }

  void _initializeDefaultData() {
    // 1. Initial Product Catalog with Multi-DC breakdown and Agent breakdown (All 9 Real Novacare Products)
    final initialProducts = [
      const MerchantProductStockView(
        id: 'prod-grazer-01',
        name: 'Grazer Herbal Tea (Weight lose and Leaver Detox tea)',
        sku: 'NOVA-GRAZER-01',
        unitPrice: 14500.0,
        category: 'Herbal Tea & Detox',
        dcShelves: {
          'Abuja Central DC': 1428,
          'Lagos Central DC': 7467,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 15,
          'Lagos Central DC': 8,
        },
        agentCustody: {
          'NovaXpress Logistics (Internal Fleet)': 180,
          'ADICHA LOGISTICS': 150,
          'Victor Ogbenyi Logistics': 95,
        },
      ),
      const MerchantProductStockView(
        id: 'prod-respira-02',
        name: 'Respira Lungs Detox Tea',
        sku: 'NOVA-RESPIRA-02',
        unitPrice: 12500.0,
        category: 'Respiratory Care',
        dcShelves: {
          'Abuja Central DC': 460,
          'Lagos Central DC': 4900,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 6,
          'Lagos Central DC': 4,
        },
        agentCustody: {
          'NovaXpress Logistics (Internal Fleet)': 110,
          'ADICHA LOGISTICS': 80,
          'Victor Ogbenyi Logistics': 60,
        },
      ),
      const MerchantProductStockView(
        id: 'prod-uraclr-03',
        name: 'Ura Clear (Ulcer and Kidney detox)',
        sku: 'NOVA-URACLR-03',
        unitPrice: 16000.0,
        category: 'Ulcer & Kidney Care',
        dcShelves: {
          'Abuja Central DC': 1351,
          'Lagos Central DC': 5400,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 4,
          'Lagos Central DC': 2,
        },
        agentCustody: {
          'NovaXpress Logistics (Internal Fleet)': 75,
          'ADICHA LOGISTICS': 45,
          'Victor Ogbenyi Logistics': 30,
        },
      ),
      const MerchantProductStockView(
        id: 'prod-alpha-man-04',
        name: 'Alpha Man Herbal Tea',
        sku: 'SKU-ALPHA-MAN',
        unitPrice: 24500.0,
        category: "Men's Vitality & Wellness",
        dcShelves: {
          'Abuja Central DC': 378,
          'Lagos Central DC': 152,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 2,
          'Lagos Central DC': 1,
        },
        agentCustody: {},
      ),
      const MerchantProductStockView(
        id: 'prod-clear-vision-05',
        name: 'Clear Vision Tea',
        sku: 'SKU-CLEAR-VISION',
        unitPrice: 18500.0,
        category: 'Eye Health & Vision Care',
        dcShelves: {
          'Abuja Central DC': 196,
          'Lagos Central DC': 50,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 1,
          'Lagos Central DC': 0,
        },
        agentCustody: {},
      ),
      const MerchantProductStockView(
        id: 'prod-defender-cap-06',
        name: 'Defender Capsule',
        sku: 'SKU-DEFENDER-CAP',
        unitPrice: 22000.0,
        category: 'Immune Support & Vitality',
        dcShelves: {
          'Abuja Central DC': 197,
          'Lagos Central DC': 203,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 3,
          'Lagos Central DC': 1,
        },
        agentCustody: {},
      ),
      const MerchantProductStockView(
        id: 'prod-grazer-balm-07',
        name: 'Grazer Herbal Balm',
        sku: 'SKU-GRAZER-BALM',
        unitPrice: 9500.0,
        category: 'Pain Relief & Joint Care',
        dcShelves: {
          'Abuja Central DC': 120,
          'Lagos Central DC': 40,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 0,
          'Lagos Central DC': 0,
        },
        agentCustody: {},
      ),
      const MerchantProductStockView(
        id: 'prod-nail-repair-08',
        name: 'Nail Repair',
        sku: 'SKU-08806',
        unitPrice: 12000.0,
        category: 'Specialty & Topical Care',
        dcShelves: {
          'Abuja Central DC': 12,
          'Lagos Central DC': 25,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 0,
          'Lagos Central DC': 0,
        },
        agentCustody: {},
      ),
      const MerchantProductStockView(
        id: 'prod-triple-h-09',
        name: 'Triple H Tea',
        sku: 'SKU-TRIPPLE-H',
        unitPrice: 16000.0,
        category: 'Hypertension & Heart Health',
        dcShelves: {
          'Abuja Central DC': 176,
          'Lagos Central DC': 319,
        },
        dcDefectQuarantine: {
          'Abuja Central DC': 1,
          'Lagos Central DC': 2,
        },
        agentCustody: {},
      ),
    ];

    // 2. Initial Partner Agents: Synchronize ALL 94 Verified Logistics Partners from CRM Agents Roster
    final initialAgents = CrmAgentsRoster.defaultAgents.map((a) {
      final custody = <String, int>{};
      for (final entry in a.heldStock.entries) {
        custody[entry.key] = entry.value;
        // Map alias SKUs
        if (entry.key == 'SKU-PRD-8309') custody['NOVA-GRAZER-01'] = entry.value;
        if (entry.key == 'SKU-RESPIRA-LUNG') custody['NOVA-RESPIRA-02'] = entry.value;
        if (entry.key == 'SKU-PRD-6731') custody['NOVA-URACLR-03'] = entry.value;
      }
      return MerchantPartnerAgent(
        id: a.id,
        name: a.name,
        code: a.agentCode,
        agentType: a.type == 'internal_logistics'
            ? 'NovaXpress Internal Fleet'
            : '3PL Partner (${a.coverageStates.isNotEmpty ? a.coverageStates.first : "National"})',
        phone: a.phone,
        state: a.coverageStates.isNotEmpty ? a.coverageStates.first : 'Nigeria',
        productCustody: custody,
      );
    }).toList();

    // 3. Initial Inbound Shipments
    final initialShipments = [
      MerchantInboundShipment(
        id: 'inbound-001',
        waybillNumber: 'WB-NOVA-2026-001',
        merchantId: '00000000-0000-4000-8000-791731264594',
        merchantName: 'Novacare Limited',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea (Weight lose and Leaver Detox tea)',
        sku: 'NOVA-GRAZER-01',
        targetDcId: 'dc-abuja-central',
        targetDcName: 'Abuja Central DC',
        expectedQuantity: 500,
        acceptedQuantity: 485,
        spoiltQuantity: 15,
        defectBreakdown: const {
          DefectCategory.brokenSeal: 8,
          DefectCategory.puncturedPackaging: 5,
          DefectCategory.colorDilation: 2,
        },
        status: 'received_with_defects',
        carrierDriverName: 'Musa Danladi',
        carrierPhone: '08031234567',
        carrierPlate: 'ABJ-452-XY',
        stagingBay: 'Bay A-12 (Ground Floor)',
        notes: 'Carton #4 crushed in transit from factory.',
        dispatchedAt: DateTime.now().subtract(const Duration(days: 3)),
        receivedAt: DateTime.now().subtract(const Duration(days: 2)),
        dcInspectorName: 'Ahmed Bello (DC Stock Admin)',
      ),
      MerchantInboundShipment(
        id: 'inbound-002',
        waybillNumber: 'WB-NOVA-2026-002',
        merchantId: '00000000-0000-4000-8000-791731264594',
        merchantName: 'Novacare Limited',
        productId: 'prod-respira-02',
        productName: 'Respira Lungs Detox Tea',
        sku: 'NOVA-RESPIRA-02',
        targetDcId: 'dc-lagos-central',
        targetDcName: 'Lagos Central DC',
        expectedQuantity: 1000,
        acceptedQuantity: 1000,
        spoiltQuantity: 0,
        defectBreakdown: const {},
        status: 'received_clean',
        carrierDriverName: 'Emeka Obi',
        carrierPhone: '08023451122',
        carrierPlate: 'LOS-891-KJA',
        stagingBay: 'Rack C-02',
        notes: 'Pristine factory batch, tamper seals intact.',
        dispatchedAt: DateTime.now().subtract(const Duration(days: 5)),
        receivedAt: DateTime.now().subtract(const Duration(days: 4)),
        dcInspectorName: 'Babatunde Alao (QC Lead)',
      ),
      MerchantInboundShipment(
        id: 'inbound-003',
        waybillNumber: 'WB-NOVA-2026-003',
        merchantId: '00000000-0000-4000-8000-791731264594',
        merchantName: 'Novacare Limited',
        productId: 'prod-uraclr-03',
        productName: 'Ura Clear (Ulcer and Kidney detox)',
        sku: 'NOVA-URACLR-03',
        targetDcId: 'dc-abuja-central',
        targetDcName: 'Abuja Central DC',
        expectedQuantity: 400,
        status: 'in_transit',
        carrierDriverName: 'Ibrahim Garba (Haulage)',
        carrierPhone: '08098765432',
        carrierPlate: 'KNO-332-TR',
        notes: 'En route from Kaduna production facility. ETA 4:00 PM.',
        dispatchedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    // 4. Initial Agent Sales Balancing Records
    final initialSalesRecords = [
      MerchantAgentSalesRecord(
        id: 'sale-001',
        date: DateTime.now(),
        merchantId: '00000000-0000-4000-8000-791731264594',
        agentId: 'agent-novaxpress-logistics',
        agentName: 'NovaXpress Logistics (Internal Fleet)',
        agentCode: 'NX-ABJ-01',
        agentType: 'NovaXpress Internal Fleet',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea (Weight lose and Leaver Detox tea)',
        sku: 'NOVA-GRAZER-01',
        openingCustody: 215,
        replenishedUnits: 0,
        unitsSold: 32,
        unitsReturned: 3,
        closingCustody: 180,
        loggedBy: 'Amaka Obi (Stock Keeper)',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      MerchantAgentSalesRecord(
        id: 'sale-002',
        date: DateTime.now(),
        merchantId: '00000000-0000-4000-8000-791731264594',
        agentId: 'agent-adicha-logistics',
        agentName: 'ADICHA LOGISTICS',
        agentCode: 'AG-001',
        agentType: '3PL Partner (Lagos)',
        productId: 'prod-respira-02',
        productName: 'Respira Lungs Detox Tea',
        sku: 'NOVA-RESPIRA-02',
        openingCustody: 245,
        replenishedUnits: 0,
        unitsSold: 50,
        unitsReturned: 5,
        closingCustody: 190,
        physicalAuditCount: 188,
        variancePercentage: -1.05,
        isAuditAmbush: true,
        discrepancyFlagged: false,
        discrepancyNotes: 'Random ambush audit count verified within 5% tolerance (-2 units variance).',
        notes: 'Lekki / Ikeja dispatch deliveries confirmed via POD.',
        loggedBy: 'Amaka Obi (Stock Keeper)',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      MerchantAgentSalesRecord(
        id: 'sale-003',
        date: DateTime.now().subtract(const Duration(days: 1)),
        merchantId: '00000000-0000-4000-8000-791731264594',
        agentId: 'agent-victor-ogbenyi-logistics',
        agentName: 'Victor Ogbenyi Logistics',
        agentCode: 'AG-002',
        agentType: '3PL Partner (Lagos)',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea (Weight lose and Leaver Detox tea)',
        sku: 'NOVA-GRAZER-01',
        openingCustody: 175,
        replenishedUnits: 0,
        unitsSold: 22,
        unitsReturned: 3,
        closingCustody: 150,
        loggedBy: 'Amaka Obi (Stock Keeper)',
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
    ];

    state = state.copyWith(
      products: initialProducts,
      agents: initialAgents,
      inboundShipments: initialShipments,
      salesRecords: initialSalesRecords,
      selectedAgent: initialAgents.first,
    );
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index);
  }

  void setDcFilter(String filter) {
    state = state.copyWith(selectedDcFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectAgent(MerchantPartnerAgent agent) {
    state = state.copyWith(selectedAgent: agent);
  }

  /// Switch or set current merchant and filter assigned agents
  void setMerchant({
    required String merchantId,
    required String merchantName,
    List<AdminLogisticsAgent>? allAgents,
  }) {
    state = state.copyWith(merchantId: merchantId, merchantName: merchantName);
    if (allAgents != null) {
      syncAgentsFromAdminRoster(allAgents);
    }
  }

  /// Synchronize the merchant's visible agent list based on which agents are attached to this merchant
  void syncAgentsFromAdminRoster(List<AdminLogisticsAgent> allAgents) {
    final assigned = allAgents.where((a) {
      return a.assignedMerchantIds.contains(state.merchantId) ||
          a.assignedMerchantNames.any((n) => n.toLowerCase().contains(state.merchantName.toLowerCase())) ||
          (state.merchantName.toLowerCase().contains('novacare') && a.assignedMerchantIds.contains('merchant-novacare'));
    }).toList();

    final partnerAgents = assigned.map((a) {
      return MerchantPartnerAgent(
        id: a.id,
        name: a.name,
        code: a.agentCode,
        agentType: a.typeLabel,
        phone: a.phone,
        state: a.coverageStates.isNotEmpty ? a.coverageStates.join(', ') : (a.assignedWarehouseName ?? 'Nationwide'),
        assignedMerchantIds: a.assignedMerchantIds,
        productCustody: a.heldStock,
      );
    }).toList();

    state = state.copyWith(
      agents: partnerAgents,
      selectedAgent: partnerAgents.isNotEmpty ? partnerAgents.first : null,
    );
  }

  /// Update product metadata, description, category, unit price, and image
  void updateProduct(MerchantProductStockView updatedProduct) {
    final idx = state.products.indexWhere((p) => p.id == updatedProduct.id || p.sku == updatedProduct.sku);
    final updatedList = List<MerchantProductStockView>.from(state.products);
    if (idx != -1) {
      updatedList[idx] = updatedProduct;
    } else {
      updatedList.insert(0, updatedProduct);
    }
    state = state.copyWith(
      products: updatedList,
      successMessage: 'Product "${updatedProduct.name}" updated successfully.',
    );
  }

  /// Create Inbound Stock Request from Merchant to NovaXpress DC
  Future<MerchantInboundShipment> createInboundShipment({
    required String productId,
    required String targetDcId,
    required String targetDcName,
    required int expectedQuantity,
    required String waybillNumber,
    required String carrierDriverName,
    required String carrierPhone,
    required String carrierPlate,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);

    final product = state.products.firstWhere(
      (p) => p.id == productId || p.sku == productId,
      orElse: () => state.products.first,
    );

    final shipment = MerchantInboundShipment(
      id: 'inbound-${DateTime.now().millisecondsSinceEpoch}',
      waybillNumber: waybillNumber.isNotEmpty
          ? waybillNumber
          : 'WB-NOVA-${DateTime.now().year}-${state.inboundShipments.length + 101}',
      merchantId: state.merchantId,
      merchantName: state.merchantName,
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      targetDcId: targetDcId,
      targetDcName: targetDcName,
      expectedQuantity: expectedQuantity,
      status: 'in_transit',
      carrierDriverName: carrierDriverName,
      carrierPhone: carrierPhone,
      carrierPlate: carrierPlate,
      notes: notes,
      dispatchedAt: DateTime.now(),
    );

    final updatedShipments = [shipment, ...state.inboundShipments];

    state = state.copyWith(
      isLoading: false,
      inboundShipments: updatedShipments,
      successMessage: 'Inbound consignment ${shipment.waybillNumber} dispatched to $targetDcName successfully!',
    );

    return shipment;
  }

  /// NovaXpress DC Stock Officer receives consignment with physical inspection and defect breakdown
  void processDcConsignmentReception({
    required String shipmentId,
    required int acceptedQuantity,
    required int spoiltQuantity,
    required Map<String, int> defectBreakdown,
    required String dcInspectorName,
    required String stagingBay,
    String? notes,
  }) {
    final shipmentIndex = state.inboundShipments.indexWhere((s) => s.id == shipmentId);
    if (shipmentIndex == -1) return;

    final existing = state.inboundShipments[shipmentIndex];
    final isClean = spoiltQuantity == 0;
    final updatedShipment = existing.copyWith(
      acceptedQuantity: acceptedQuantity,
      spoiltQuantity: spoiltQuantity,
      defectBreakdown: defectBreakdown,
      status: isClean ? 'received_clean' : 'received_with_defects',
      stagingBay: stagingBay,
      notes: notes ?? existing.notes,
      receivedAt: DateTime.now(),
      dcInspectorName: dcInspectorName,
    );

    final updatedShipments = List<MerchantInboundShipment>.from(state.inboundShipments);
    updatedShipments[shipmentIndex] = updatedShipment;

    // Credit ONLY the accepted quantity to target DC shelves, and quarantine spoilt units
    final productIndex = state.products.indexWhere((p) => p.sku == existing.sku || p.id == existing.productId);
    var updatedProducts = state.products;

    if (productIndex != -1) {
      final p = state.products[productIndex];
      final currentDcShelves = Map<String, int>.from(p.dcShelves);
      final currentDcQuarantine = Map<String, int>.from(p.dcDefectQuarantine);

      final dcName = existing.targetDcName;
      currentDcShelves[dcName] = (currentDcShelves[dcName] ?? 0) + acceptedQuantity;
      if (spoiltQuantity > 0) {
        currentDcQuarantine[dcName] = (currentDcQuarantine[dcName] ?? 0) + spoiltQuantity;
      }

      final updatedProduct = MerchantProductStockView(
        id: p.id,
        name: p.name,
        sku: p.sku,
        unitPrice: p.unitPrice,
        category: p.category,
        dcShelves: currentDcShelves,
        dcDefectQuarantine: currentDcQuarantine,
        agentCustody: p.agentCustody,
      );

      final newProdList = List<MerchantProductStockView>.from(state.products);
      newProdList[productIndex] = updatedProduct;
      updatedProducts = newProdList;
    }

    state = state.copyWith(
      inboundShipments: updatedShipments,
      products: updatedProducts,
      successMessage: 'Consignment ${existing.waybillNumber} verified by DC Officer $dcInspectorName. $acceptedQuantity units credited to $stagingBay.',
    );
  }

  /// Log daily sales by partner agent and automatically balance custody
  MerchantAgentSalesRecord recordDailySalesAndBalance({
    required String agentId,
    required String sku,
    required int unitsSold,
    int unitsReturned = 0,
    int replenishedUnits = 0,
    int? physicalAuditCount,
    String? notes,
    required String loggedBy,
  }) {
    final agentIndex = state.agents.indexWhere((a) => a.id == agentId);
    if (agentIndex == -1) {
      throw Exception('Selected agent not found');
    }

    final agent = state.agents[agentIndex];
    final openingCustody = agent.productCustody[sku] ?? 0;

    final product = state.products.firstWhere(
      (p) => p.sku == sku,
      orElse: () => state.products.first,
    );

    final record = MerchantAgentSalesRecord.compute(
      id: 'sale-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      merchantId: state.merchantId,
      agentId: agent.id,
      agentName: agent.name,
      agentCode: agent.code,
      agentType: agent.agentType,
      productId: product.id,
      productName: product.name,
      sku: sku,
      openingCustody: openingCustody,
      replenishedUnits: replenishedUnits,
      unitsSold: unitsSold,
      unitsReturned: unitsReturned,
      physicalAuditCount: physicalAuditCount,
      notes: notes,
      loggedBy: loggedBy,
    );

    // 1. Update Agent's custody map
    final updatedCustody = Map<String, int>.from(agent.productCustody);
    updatedCustody[sku] = record.closingCustody;
    final updatedAgent = agent.copyWith(productCustody: updatedCustody);

    final updatedAgents = List<MerchantPartnerAgent>.from(state.agents);
    updatedAgents[agentIndex] = updatedAgent;

    // 2. Update Product's agent custody map
    final productIndex = state.products.indexWhere((p) => p.sku == sku);
    var updatedProducts = state.products;

    if (productIndex != -1) {
      final p = state.products[productIndex];
      final currentAgentCustody = Map<String, int>.from(p.agentCustody);
      currentAgentCustody[agent.name] = record.closingCustody;

      final updatedProduct = MerchantProductStockView(
        id: p.id,
        name: p.name,
        sku: p.sku,
        unitPrice: p.unitPrice,
        category: p.category,
        dcShelves: p.dcShelves,
        dcDefectQuarantine: p.dcDefectQuarantine,
        agentCustody: currentAgentCustody,
      );

      final newProdList = List<MerchantProductStockView>.from(state.products);
      newProdList[productIndex] = updatedProduct;
      updatedProducts = newProdList;
    }

    state = state.copyWith(
      salesRecords: [record, ...state.salesRecords],
      agents: updatedAgents,
      products: updatedProducts,
      selectedAgent: state.selectedAgent?.id == agentId ? updatedAgent : state.selectedAgent,
      successMessage: 'Daily sales logged for ${agent.name}. Closing custody balanced to ${record.closingCustody} units.',
    );

    // Asynchronously persist ledger movements to Supabase
    if (unitsSold > 0) {
      _dataSource.persistStockLedgerEntry(
        clientId: state.merchantId,
        warehouse: 'Abuja Central DC',
        itemCode: sku,
        itemName: product.name,
        itemGroup: product.category,
        voucherType: 'sales_order_delivery',
        voucherNo: record.id,
        qtyChange: -(unitsSold.toDouble()),
        incomingQty: 0.0,
        outgoingQty: unitsSold.toDouble(),
        valuationRate: product.unitPrice,
        totalValue: unitsSold * product.unitPrice,
        notes:
            'Delivered daily sale by ${agent.name} (${agent.code}) • Balanced custody: ${record.closingCustody} • Logged by: $loggedBy${notes != null ? " • $notes" : ""}',
      );
    }

    if (replenishedUnits > 0) {
      _dataSource.persistStockLedgerEntry(
        clientId: state.merchantId,
        warehouse: 'Abuja Central DC',
        itemCode: sku,
        itemName: product.name,
        itemGroup: product.category,
        voucherType: 'purchase_receipt',
        voucherNo: 'REPL-${record.id}',
        qtyChange: replenishedUnits.toDouble(),
        incomingQty: replenishedUnits.toDouble(),
        outgoingQty: 0.0,
        valuationRate: product.unitPrice,
        totalValue: replenishedUnits * product.unitPrice,
        notes:
            'Inbound DC restock to ${agent.name} (${agent.code}) • Logged by $loggedBy',
      );

      _dataSource.updateClientStockBalance(
        itemCode: sku,
        warehouse: 'Abuja Central DC',
        qtyDelta: -(replenishedUnits.toDouble()),
        valuationRate: product.unitPrice,
      );
    }

    // Persist agent custody to delivery_agents & local preferences
    _dataSource.updateLogisticsAgent(AdminLogisticsAgent(
      id: agent.id,
      name: agent.name,
      agentCode: agent.code,
      type: agent.agentType.contains('Internal') ? 'internal_logistics' : '3pl_partner',
      contactPerson: agent.name,
      phone: agent.phone,
      email: 'operations@novaxpress.ng',
      coverageStates: [agent.state],
      activeRidersCount: 8,
      status: 'active',
      assignedWarehouseName: 'Abuja Central DC',
      assignedMerchantIds: [state.merchantId],
      assignedMerchantNames: [state.merchantName],
      heldStock: updatedCustody,
      createdAt: DateTime(2026, 1, 1),
    ));

    // Persist audit log
    _dataSource.recordAuditLog(AdminAuditLog(
      id: UuidHelper.generate(),
      actorName: loggedBy,
      actorEmail: 'operations@novaxpress.ng',
      actorRole: 'stock_keeper',
      action: 'RECORD_AGENT_DAILY_SALE',
      resource: 'Merchant Custody & Daily Sales',
      details:
          'Logged daily sales for ${agent.name} (${agent.code}) on ${product.name} [$sku]: $unitsSold sold, +$replenishedUnits restocked, closing custody ${record.closingCustody} units.',
      distributionCenterName: 'Abuja Central DC',
      timestamp: DateTime.now(),
      ipAddress: '127.0.0.1',
    ));

    return record;
  }
}

final merchantInventoryProvider =
    StateNotifierProvider<MerchantInventoryNotifier, MerchantInventoryState>((ref) {
  return MerchantInventoryNotifier();
});
