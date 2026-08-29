import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/domain/repositories/finance_repository.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockLifecycleStockRepository implements StockRepository {
  final List<StockItemEntity> dbProducts = [];

  @override
  Future<StockItemEntity> createProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    String? description,
    String? ownerName,
    int stockQuantity = 0,
    int lowStockThreshold = 3,
    String? binLocation,
    String? companyId,
    String? imageAsset,
  }) async {
    final item = StockItemEntity(
      id: 'prod-${sku.toLowerCase()}',
      sku: sku,
      name: name,
      description: description ?? name,
      price: price,
      ownerName: ownerName ?? 'Novacare Limited',
      category: category,
      availableCount: stockQuantity,
      totalInCustody: stockQuantity,
      assignedCount: 0,
      deliveredCount: 0,
      returnedCount: 0,
      imageAsset: imageAsset,
      lowStockThreshold: lowStockThreshold,
    );
    dbProducts.add(item);
    return item;
  }

  @override
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  }) async {
    return {'success': true, 'allocatedUnits': quantity};
  }

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async => dbProducts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLifecycleOrdersRepository implements OrdersRepository {
  final List<OrderEntity> dbOrders = [];

  @override
  Future<OrderEntity> createOrder(Map<String, dynamic> orderData) async {
    final entity = OrderEntity(
      id: orderData['id'] ?? 'ord-${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: orderData['order_number'] ?? 'TRK-0000',
      productName: orderData['product_name'] ?? 'Product',
      customerName: orderData['customer_name'] ?? 'Customer',
      customerPhone: orderData['customer_phone'] ?? '08000000000',
      deliveryState: orderData['delivery_state'] ?? 'FCT - Abuja',
      deliveryCity: orderData['delivery_city'] ?? 'Abuja',
      deliveryAddress: orderData['delivery_address'] ?? 'Delivery Address',
      quantity: orderData['quantity'] ?? 1,
      paidQuantity: orderData['paid_quantity'] ?? 1,
      freeQuantity: orderData['free_quantity'] ?? 0,
      basePrice: (orderData['base_price'] as num?)?.toDouble() ?? 0.0,
      upsellAmount: (orderData['upsell_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (orderData['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: orderData['payment_type'] ?? 'pay_on_delivery',
      paymentStatus: orderData['payment_status'] ?? 'pending',
      status: orderData['status'] ?? 'unassigned',
      createdAt: DateTime.now(),
    );
    dbOrders.add(entity);
    return entity;
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    final idx = dbOrders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (idx != -1) {
      dbOrders[idx] = dbOrders[idx].copyWith(
        deliveryAgentId: riderId,
        deliveryAgentName: riderName,
        deliveryAgentCode: riderCode,
        status: 'in_transit',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async {
    final idx = dbOrders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (idx != -1) {
      dbOrders[idx] = dbOrders[idx].copyWith(
        status: 'delivered',
        paymentStatus: 'collected',
        customerSignatureUrl: customerSignatureUrl,
      );
    }
    return {'success': true};
  }

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async =>
      dbOrders.where((o) => o.deliveryAgentId == deliveryAgentId).toList();

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => dbOrders;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLifecycleFinanceRepository implements FinanceRepository {
  final List<RemittanceEntity> dbRemittances = [];

  @override
  Future<RemittanceEntity> submitRemittance({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
  }) async {
    final entity = RemittanceEntity(
      id: 'rem-${DateTime.now().millisecondsSinceEpoch}',
      deliveryAgentId: agentId,
      companyId: companyId,
      amount: amount,
      paymentMethod: paymentMethod,
      grossCollections: grossCollections > 0 ? grossCollections : amount,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      depositReceiptUrl: depositReceiptUrl,
      referenceNumber: referenceNumber ?? 'REF-LIVE-900',
      status: 'pending',
      createdAt: DateTime.now(),
      associatedOrders: associatedOrders,
    );
    dbRemittances.add(entity);
    return entity;
  }

  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String agentId) async =>
      dbRemittances.where((r) => r.deliveryAgentId == agentId).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Complete 7-Step Business Lifecycle Execution Suite', () {
    late ProviderContainer container;
    late MockLifecycleStockRepository mockStockRepo;
    late MockLifecycleOrdersRepository mockOrdersRepo;
    late MockLifecycleFinanceRepository mockFinanceRepo;

    setUp(() {
      mockStockRepo = MockLifecycleStockRepository();
      mockOrdersRepo = MockLifecycleOrdersRepository();
      mockFinanceRepo = MockLifecycleFinanceRepository();

      container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(mockStockRepo),
          ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
          financeRepositoryProvider.overrideWithValue(mockFinanceRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Full End-to-End Operational Lifecycle: Step 1 through Step 7', () async {
      // -------------------------------------------------------------
      // STEP 1: Creating a product
      // -------------------------------------------------------------
      final stockNotifier = container.read(stockProvider.notifier);
      final createdProduct = await stockNotifier.addNewProduct(
        name: 'Prostate Health Herbal Tea',
        sku: 'SKU-PROS-01',
        category: 'Men Health',
        price: 32000.0,
        ownerName: 'Novacare Pharmaceuticals',
        initialQuantity: 100,
        lowStockThreshold: 5,
        description: 'Premium organic prostate health formulation',
      );

      expect(createdProduct.name, equals('Prostate Health Herbal Tea'));
      expect(createdProduct.availableCount, equals(100));

      final catalogNotifier = container.read(productCatalogProvider.notifier);
      catalogNotifier.syncFromStockItems([createdProduct]);

      final catalogState = container.read(productCatalogProvider);
      final catalogProduct = catalogState.findProductByName('Prostate Health Herbal Tea');
      expect(catalogProduct, isNotNull);
      expect(catalogProduct!.sku, equals('SKU-PROS-01'));

      // -------------------------------------------------------------
      // STEP 2: Assigning the product to an agent
      // -------------------------------------------------------------
      final assignRes = await stockNotifier.assignStockToRider(
        productIdOrSku: createdProduct.id,
        riderId: 'a1111111-1111-4111-8111-111111111111',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7001',
        quantity: 15,
      );

      expect(assignRes['success'], isTrue);
      expect(assignRes['allocatedUnits'], equals(15));

      final updatedStockState = container.read(stockProvider);
      final riderAllocations = updatedStockState.getAllocationsForRider('a1111111-1111-4111-8111-111111111111', 'PDA-7001');
      expect(riderAllocations.length, equals(1));
      expect(riderAllocations.first.inCustodyUnits, equals(15));
      expect(riderAllocations.first.productName, equals('Prostate Health Herbal Tea'));

      // -------------------------------------------------------------
      // STEP 3: Creating commercial packages for that product
      // -------------------------------------------------------------
      final promoPackage = catalogNotifier.addPackageToProduct(
        productName: 'Prostate Health Herbal Tea',
        packageName: '3 Packs Family Treatment Course',
        quantity: 3,
        paidQuantity: 3,
        freeQuantity: 0,
        packagePrice: 85000.0,
        clientName: 'Novacare Pharmaceuticals',
        productSku: 'SKU-PROS-01',
        description: 'Complete 90-day supply with free herbal detox guide',
      );

      expect(promoPackage.packageName, equals('3 Packs Family Treatment Course'));
      expect(promoPackage.quantity, equals(3));
      expect(promoPackage.packagePrice, equals(85000.0));

      // -------------------------------------------------------------
      // STEP 4: Creating orders from those packages
      // -------------------------------------------------------------
      final ordersNotifier = container.read(ordersProvider.notifier);
      final orderPayload = {
        'id': 'ord-live-test-001',
        'order_number': 'TRK-98214',
        'product_id': createdProduct.id,
        'product_name': '${createdProduct.name} (${promoPackage.packageName})',
        'customer_name': 'Chief Senator Okonkwo',
        'customer_phone': '08022223333',
        'delivery_state': 'FCT - Abuja',
        'delivery_city': 'Maitama',
        'delivery_address': 'Plot 412 Amazon Street, Ministers Hill',
        'quantity': promoPackage.quantity,
        'paid_quantity': promoPackage.paidQuantity,
        'free_quantity': promoPackage.freeQuantity,
        'base_price': promoPackage.packagePrice,
        'upsell_amount': 0.0,
        'total_amount': promoPackage.packagePrice,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'unassigned',
        'package_deal_id': promoPackage.id,
        'package_deal_name': promoPackage.packageName,
      };

      final orderCreated = await ordersNotifier.createOrder(orderPayload);
      expect(orderCreated, isTrue);

      final ordersState = container.read(ordersProvider);
      final createdOrder = ordersState.orders.firstWhere((o) => o.orderNumber == 'TRK-98214');
      expect(createdOrder.customerName, equals('Chief Senator Okonkwo'));
      expect(createdOrder.quantity, equals(3));
      expect(createdOrder.totalAmount, equals(85000.0));

      // -------------------------------------------------------------
      // STEP 5: Assigning orders to agents (Custody check enforced)
      // -------------------------------------------------------------
      final orderAssigned = await ordersNotifier.assignOrderToRider(
        orderId: createdOrder.id,
        riderId: 'a1111111-1111-4111-8111-111111111111',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7001',
      );
      expect(orderAssigned, isTrue);

      final assignedOrder = container.read(ordersProvider).orders.firstWhere((o) => o.id == createdOrder.id);
      expect(assignedOrder.status, equals('in_transit'));
      expect(assignedOrder.deliveryAgentId, equals('a1111111-1111-4111-8111-111111111111'));

      // -------------------------------------------------------------
      // STEP 6: Agent fulfilling the orders (POD & stock deduction)
      // -------------------------------------------------------------
      final podResult = await ordersNotifier.confirmDeliveryPod(
        orderId: assignedOrder.id,
        agentId: 'a1111111-1111-4111-8111-111111111111',
        paymentType: 'pay_on_delivery',
        paymentMethod: 'cash',
        amountCollected: 85000.0,
        customerSignatureUrl: 'https://storage.supabase.co/signatures/sig_okonkwo.png',
        notes: 'Delivered to Chief directly at residence with gate pass verified.',
      );

      expect(podResult['success'], isTrue);

      final deliveredOrder = container.read(ordersProvider).orders.firstWhere((o) => o.id == assignedOrder.id);
      expect(deliveredOrder.status, equals('delivered'));
      expect(deliveredOrder.paymentStatus, equals('collected'));
      expect(deliveredOrder.customerSignatureUrl, isNotEmpty);

      // Verify stock was automatically deducted from vehicle custody: 15 - 3 = 12
      final postDeliveryStock = container.read(stockProvider);
      final riderCustody = postDeliveryStock.getAllocationsForRider('a1111111-1111-4111-8111-111111111111', 'PDA-7001');
      expect(riderCustody.first.inCustodyUnits, equals(12));
      expect(riderCustody.first.deliveredUnits, equals(3));

      // -------------------------------------------------------------
      // STEP 7: Agent remitting the cash after fulfillment
      // -------------------------------------------------------------
      final financeNotifier = container.read(financeProvider.notifier);
      final remittanceSuccess = await financeNotifier.submitRemittance(
        agentId: 'a1111111-1111-4111-8111-111111111111',
        amount: 82500.0, // 85000 gross - 1000 commission - 1500 transport
        paymentMethod: 'paystack_virtual_account',
        grossCollections: 85000.0,
        commissionDeducted: 1000.0,
        transportAllowanceDeducted: 1500.0,
        referenceNumber: 'REM-PAYSTACK-98214',
        associatedOrders: [
          RemittanceOrderItem(
            orderId: deliveredOrder.id,
            orderNumber: deliveredOrder.orderNumber,
            customerName: deliveredOrder.customerName,
            status: 'delivered',
            cashCollected: 85000.0,
            riderCommission: 1000.0,
            transportAllowance: 1500.0,
            date: DateTime.now(),
          ),
        ],
      );

      expect(remittanceSuccess, isTrue);

      // Verify remittance logged in state
      final financeState = container.read(financeProvider);
      expect(financeState.remittances.length, equals(1));
      expect(financeState.remittances.first.grossCollections, equals(85000.0));
      expect(financeState.remittances.first.amount, equals(82500.0));
      expect(financeState.remittances.first.associatedOrders.length, equals(1));
      expect(financeState.remittances.first.associatedOrders.first.orderNumber, equals('TRK-98214'));

      // Verify order remittance status updated
      final reconciledOrder = container.read(ordersProvider).orders.firstWhere((o) => o.id == deliveredOrder.id);
      expect(reconciledOrder.remittanceStatus, equals('remittance_pending'));
    });
  });
}
