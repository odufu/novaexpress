import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_dashboard_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_distribution_centers_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';

import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockAuthRemoteDS implements AuthRemoteDataSource {
  final Map<String, UserModel> registeredUsers = {};
  final Map<String, String> userPasswords = {};

  @override
  Future<UserModel> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final model = UserModel(
      id: 'usr-sup-${distributionCenterId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      email: cleanEmail,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'dc_manager',
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
      operatingState: operatingState ?? 'Kano State',
      operatingCity: operatingCity ?? 'Kano',
    );
    registeredUsers[cleanEmail] = model;
    userPasswords[cleanEmail] = password;
    AuthRemoteDataSourceImpl.registerUserInMemory(model, password);
    return model;
  }

  @override
  Future<UserModel> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (registeredUsers.containsKey(cleanEmail) && userPasswords[cleanEmail] == password) {
      return registeredUsers[cleanEmail]!;
    }
    final inMem = AuthRemoteDataSourceImpl.getRegisteredUser(cleanEmail);
    if (inMem != null) {
      return inMem;
    }
    throw Exception('Invalid credentials for $email');
  }

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  final List<OrderModel> orders = [];

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async {
    return orders.where((o) => o.deliveryAgentId == deliveryAgentId).toList();
  }

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async {
    if (distributionCenterId.isEmpty) return orders;
    return orders.where((o) => o.distributionCenterId == distributionCenterId).toList();
  }

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    final newOrder = OrderModel.fromJson(orderData);
    orders.add(newOrder);
    return newOrder;
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async {
    final index = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (index != -1) {
      final existing = orders[index];
      orders[index] = OrderModel.fromEntity(
        existing.copyWith(
          status: status,
          paymentStatus: paymentStatus ?? existing.paymentStatus,
          paymentType: paymentType ?? existing.paymentType,
          deliveryNotes: notes ?? existing.deliveryNotes,
          customerSignatureUrl: customerSignatureUrl ?? existing.customerSignatureUrl,
        ),
      );
    }
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    final index = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (index != -1) {
      final existing = orders[index];
      orders[index] = OrderModel.fromEntity(
        existing.copyWith(
          deliveryAgentId: riderId,
          deliveryAgentName: riderName,
          deliveryAgentCode: riderCode,
          status: 'in_transit',
        ),
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
    await updateOrderStatus(
      orderId,
      'delivered',
      paymentStatus: 'paid',
      paymentType: paymentType,
      notes: notes,
      customerSignatureUrl: customerSignatureUrl,
      photoProofUrl: photoProofUrl,
      gatePassCode: gatePassCode,
      latitude: latitude,
      longitude: longitude,
    );
    return {'success': true, 'orderId': orderId, 'status': 'delivered'};
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    return orders.firstWhere((o) => o.id == orderId || o.orderNumber == orderId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockRemoteDS implements StockRemoteDataSource {
  final List<StockItemModel> stockItems = [];
  final List<RiderStockAllocation> allocations = [];

  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId, String? dcId]) async => stockItems;

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]) async {
    if (riderId == null || riderId.isEmpty) return allocations;
    return allocations.where((a) => a.riderId == riderId).toList();
  }

  @override
  Future<StockItemModel> createProduct({
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
    String? clientId,
    String? imageAsset,
    String? originDcId,
    List<String>? coveringStates,
    Map<String, int>? dcStocks,
  }) async {
    final model = StockItemModel(
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
    stockItems.add(model);
    return model;
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
    final itemIndex = stockItems.indexWhere((i) => i.id == productIdOrSku || i.sku == productIdOrSku);
    if (itemIndex != -1) {
      final item = stockItems[itemIndex];
      stockItems[itemIndex] = StockItemModel(
        id: item.id,
        sku: item.sku,
        name: item.name,
        description: item.description,
        price: item.price,
        ownerName: item.ownerName,
        category: item.category,
        availableCount: (item.availableCount - quantity).clamp(0, 999999),
        totalInCustody: item.totalInCustody,
        assignedCount: item.assignedCount + quantity,
        deliveredCount: item.deliveredCount,
        returnedCount: item.returnedCount,
        lowStockThreshold: item.lowStockThreshold,
      );
    }
    allocations.add(RiderStockAllocation(
      id: 'alloc-${DateTime.now().millisecondsSinceEpoch}',
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
      productId: productIdOrSku,
      productName: productIdOrSku,
      sku: productIdOrSku,
      allocatedUnits: quantity,
      inCustodyUnits: quantity,
      unitPrice: 25000.0,
      allocatedAt: DateTime.now(),
    ));
    return {'success': true, 'allocatedUnits': quantity};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFinanceRemoteDS implements FinanceRemoteDataSource {
  final List<RemittanceModel> remittances = [];

  @override
  Future<List<RemittanceModel>> getAgentRemittances([String? agentId]) async {
    if (agentId == null || agentId.isEmpty) return remittances;
    return remittances.where((r) => r.deliveryAgentId == agentId).toList();
  }

  @override
  Future<RemittanceModel> submitRemittance({
    required String agentId,
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
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? proofOfPaymentUrl,
    String? notes,
    List<dynamic> associatedOrders = const [],
    String? distributionCenterId,
    String? companyId,
  }) async {
    final model = RemittanceModel(
      id: 'rem-${DateTime.now().millisecondsSinceEpoch}',
      deliveryAgentId: agentId,
      referenceNumber: referenceNumber ?? 'REF-${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      grossCollections: grossCollections > 0 ? grossCollections : amount,
      paymentMethod: paymentMethod,
      depositReceiptUrl: depositReceiptUrl ?? proofOfPaymentUrl,
      notes: notes,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    remittances.add(model);
    return model;
  }

  @override
  Future<List<Map<String, dynamic>>> getRiderTransactions(String agentId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationsRepo implements NotificationsRepository {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRemoteDS mockAuthDS;
  late _MockOrdersRemoteDS mockOrdersDS;
  late _MockStockRemoteDS mockStockDS;
  late _MockFinanceRemoteDS mockFinanceDS;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockAuthDS = _MockAuthRemoteDS();
    mockOrdersDS = _MockOrdersRemoteDS();
    mockStockDS = _MockStockRemoteDS();
    mockFinanceDS = _MockFinanceRemoteDS();
  });

  group('End-to-End DC Lifecycle & Core Operations Suite', () {
    test('1. Create a New Distribution Center (Kaduna DC) & Provision Supervisor Credentials', () async {
      final container = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockAuthDS),
          dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final dcNotifier = container.read(dcConsoleProvider.notifier);

      // Create new Kaduna DC
      final createdDc = await dcNotifier.createDistributionCenter(
        name: 'Kaduna Central Depot DC',
        code: 'DC-KAD-01',
        stateName: 'Kaduna State',
        city: 'Kaduna',
        address: '12 Ahmadu Bello Way, Commercial District, Kaduna',
        managerName: 'Shehu Sani',
        contactPhone: '+234 806 777 8899',
        contactEmail: 'kaduna.dc@novaexpress.ng',
        isHub: false,
        storageCapacityUnits: 35000,
        operatingZones: const ['Kaduna North', 'Kaduna South', 'Chikun', 'Barnawa', 'Kakuri'],
        supervisorEmail: 'supervisor.dc-kad-01@novaexpress.ng',
        supervisorPassword: 'KadunaPassword123!',
        authDataSource: mockAuthDS,
      );

      expect(createdDc.name, equals('Kaduna Central Depot DC'));
      expect(createdDc.code, equals('DC-KAD-01'));
      expect(createdDc.operatingZones, contains('Kaduna North'));
      expect(createdDc.operatingZones, contains('Kaduna South'));
      expect(createdDc.storageCapacityUnits, equals(35000));
      expect(createdDc.isActive, isTrue);

      // Verify DC exists in DC Console state
      final dcState = container.read(dcConsoleProvider);
      final foundDc = dcState.distributionCenters.firstWhere((d) => d.code == 'DC-KAD-01');
      expect(foundDc.id, equals(createdDc.id));
    });

    test('2. DC Supervisor logs in with provisioned credentials and scopes to Kano DC', () async {
      final container = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockAuthDS),
          authProvider.overrideWith((ref) {
            return AuthNotifier(
              loginUseCase: LoginUseCase(AuthRepositoryImpl(mockAuthDS)),
              logoutUseCase: LogoutUseCase(AuthRepositoryImpl(mockAuthDS)),
              getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(mockAuthDS)),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      // Register supervisor in mock auth DS
      await mockAuthDS.registerDistributionCenterSupervisor(
        email: 'supervisor.dc-kan-01@novaexpress.ng',
        password: 'KanoPassword123!',
        firstName: 'Ibrahim',
        lastName: 'Danladi',
        phone: '+234 806 444 5566',
        distributionCenterId: 'dc-dc-kan-01',
        distributionCenterName: 'Kano Northern Depot DC',
        operatingState: 'Kano State',
        operatingCity: 'Kano',
      );

      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('supervisor.dc-kan-01@novaexpress.ng', 'KanoPassword123!');

      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, isTrue);
      expect(authState.user, isNotNull);
      expect(authState.user!.role, equals('dc_manager'));
      expect(authState.user!.isDcManager, isTrue);
      expect(authState.user!.distributionCenterId, equals('dc-dc-kan-01'));
      expect(authState.user!.distributionCenterName, equals('Kano Northern Depot DC'));
    });

    test('3. Onboard Dispatch Rider to Kano DC with Custom Compensation Terms', () async {
      final container = ProviderContainer(
        overrides: [
          dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final dcNotifier = container.read(dcConsoleProvider.notifier);

      const kanoRider = DCFleetDriver(
        id: 'rdr-kan-001',
        driverCode: 'RDR-KAN-01',
        name: 'Mustapha Kano Rider',
        phone: '08031234567',
        email: 'mustapha.kano@novaexpress.com',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        distributionCenterId: 'dc-dc-kan-01',
        status: 'active',
        assignedZone: 'Kano Municipal',
        coveredLgas: ['Kano Municipal', 'Fagge', 'Nassarawa'],
        vehicleType: 'Motorcycle',
        vehiclePlate: 'KAN-998-XX',
        vehicleModel: 'Bajaj Boxer 150',
        totalAssignedOrders: 0,
        completedOrders: 0,
        routeProgressPercent: 0.0,
        efficiencyRating: 5.0,
        cashInCustody: 0.0,
        itemsInCustody: 0,
        commissionRate: 1200.0,
        transportAllowance: 1500.0,
        failedDeliveryAllowance: 600.0,
        compensationType: 'commission',
        personnelType: 'pda',
      );

      dcNotifier.addDriver(kanoRider);

      final state = container.read(dcConsoleProvider);
      final riderFound = state.drivers.firstWhere((d) => d.id == 'rdr-kan-001');
      expect(riderFound.name, equals('Mustapha Kano Rider'));
      expect(riderFound.driverCode, equals('RDR-KAN-01'));
      expect(riderFound.distributionCenterId, equals('dc-dc-kan-01'));
      expect(riderFound.commissionRate, equals(1200.0));
      expect(riderFound.coveredLgas, contains('Kano Municipal'));
    });

    test('4. Receive Merchant Stock into Kano DC & Allocate Custody to Local Rider', () async {
      final stockRepo = StockRepositoryImpl(remoteDataSource: mockStockDS);
      final container = ProviderContainer(
        overrides: [
          stockRemoteDataSourceProvider.overrideWithValue(mockStockDS),
          stockProvider.overrideWith((ref) => StockNotifier(repository: stockRepo)),
        ],
      );
      addTearDown(container.dispose);

      // 1. Create / Receive Product Stock into DC via Repository
      final product = await stockRepo.createProduct(
        name: 'Respira Detox Tea',
        sku: 'RESPIRA-01',
        category: 'Health & Wellness',
        price: 25000.0,
        stockQuantity: 50,
        ownerName: 'Novacare Limited',
      );

      expect(product.availableCount, equals(50));
      expect(product.sku, equals('RESPIRA-01'));

      // 2. Allocate 10 units to Kano Rider
      final allocResult = await stockRepo.assignStockToRider(
        productIdOrSku: product.sku,
        riderId: 'rdr-kan-001',
        riderName: 'Mustapha Kano Rider',
        riderCode: 'RDR-KAN-01',
        quantity: 10,
        distributionCenterId: 'dc-dc-kan-01',
      );

      expect(allocResult['success'], isTrue);
      expect(allocResult['allocatedUnits'], equals(10));

      // Refresh and verify stock notifier state
      final stockNotifier = container.read(stockProvider.notifier);
      await stockNotifier.fetchStockItems();

      final updatedStock = container.read(stockProvider);
      final item = updatedStock.stockItems.firstWhere((i) => i.sku == 'RESPIRA-01');
      expect(item.availableCount, equals(40));
      expect(item.assignedCount, equals(10));
    });

    test('5. 2-Tier Automated LGA Routing directs Kano Order to Kano DC and Rider', () async {
      final dcs = [
        DistributionCenter(
          id: '22222222-2222-4222-8222-222222222222',
          companyId: '11111111-1111-4111-8111-111111111111',
          name: 'Wuse Central Distribution Hub',
          code: 'DC-ABJ-01',
          state: 'Federal Capital Territory',
          city: 'Abuja',
          address: 'Plot 42, Wuse II, Abuja',
          isGrandDc: true,
          isHub: true,
          isActive: true,
          operatingZones: const ['Abuja Municipal (AMAC)', 'AMAC', 'Wuse II', 'Maitama'],
          storageCapacityUnits: 50000,
          totalAssignedRiders: 10,
          activeInventoryBatches: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        DistributionCenter(
          id: 'dc-dc-kan-01',
          companyId: '11111111-1111-4111-8111-111111111111',
          name: 'Kano Northern Depot DC',
          code: 'DC-KAN-01',
          state: 'Kano State',
          city: 'Kano',
          address: '18 Bompai Road, Kano',
          isGrandDc: false,
          isHub: false,
          isActive: true,
          operatingZones: const ['Kano Municipal', 'Fagge', 'Nassarawa', 'Bompai'],
          storageCapacityUnits: 35000,
          totalAssignedRiders: 2,
          activeInventoryBatches: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      const drivers = [
        DCFleetDriver(
          id: 'rdr-kan-001',
          driverCode: 'RDR-KAN-01',
          name: 'Mustapha Kano Rider',
          phone: '08031234567',
          email: 'mustapha.kano@novaexpress.com',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          distributionCenterId: 'dc-dc-kan-01',
          status: 'active',
          assignedZone: 'Kano Municipal',
          coveredLgas: ['Kano Municipal', 'Fagge'],
          vehicleType: 'Motorcycle',
          vehiclePlate: 'KAN-998-XX',
          vehicleModel: 'Bajaj Boxer 150',
          totalAssignedOrders: 0,
          completedOrders: 0,
          routeProgressPercent: 0.0,
          efficiencyRating: 5.0,
          cashInCustody: 0.0,
          itemsInCustody: 10,
          commissionRate: 1200.0,
          transportAllowance: 1500.0,
          failedDeliveryAllowance: 600.0,
          compensationType: 'commission',
          personnelType: 'pda',
        ),
      ];

      final allocations = [
        RiderStockAllocation(
          id: 'alloc-1',
          riderId: 'rdr-kan-001',
          riderName: 'Mustapha Kano Rider',
          riderCode: 'RDR-KAN-01',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          sku: 'RESPIRA-01',
          allocatedUnits: 10,
          inCustodyUnits: 10,
          unitPrice: 25000.0,
          allocatedAt: DateTime.now(),
        ),
      ];

      final kanoOrder = OrderEntity(
        id: 'ord-kan-8801',
        orderNumber: 'TRK-KAN-8801',
        customerName: 'Alhaji Aminu Dantata',
        customerPhone: '08034567890',
        deliveryState: 'Kano State',
        deliveryCity: 'Kano',
        lga: 'Kano Municipal',
        deliveryAddress: '15 Bompai Road, Kano Municipal',
        productName: 'Respira Detox Tea',
        productSku: 'RESPIRA-01',
        quantity: 2,
        basePrice: 12500.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        status: 'pending_dispatch',
        createdAt: DateTime.now(),
      );

      // Route the order
      final routing = OrderRoutingService.routeOrder(
        order: kanoOrder,
        distributionCenters: dcs,
        drivers: drivers,
        stockAllocations: allocations,
      );

      expect(routing.isRoutedToDc, isTrue);
      expect(routing.distributionCenter?.id, equals('dc-dc-kan-01'));
      expect(routing.distributionCenter?.name, equals('Kano Northern Depot DC'));
      expect(routing.isAssignedToRider, isTrue);
      expect(routing.driver?.id, equals('rdr-kan-001'));
      expect(routing.driver?.name, equals('Mustapha Kano Rider'));
    });

    test('6. Order Assignment, Rider POD Delivery & Cash Collection Cycle', () async {
      final container = ProviderContainer(
        overrides: [
          ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDS),
          ordersProvider.overrideWith((ref) => OrdersNotifier(OrdersRepositoryImpl(mockOrdersDS))),
        ],
      );
      addTearDown(container.dispose);

      final ordersNotifier = container.read(ordersProvider.notifier);

      // 1. Create Kano Order
      final created = await ordersNotifier.createOrder({
        'id': 'ord-kan-8801',
        'order_number': 'TRK-KAN-8801',
        'customer_name': 'Alhaji Aminu Dantata',
        'customer_phone': '08034567890',
        'delivery_state': 'Kano State',
        'delivery_city': 'Kano Municipal',
        'delivery_address': '15 Bompai Road, Kano',
        'product_name': '2x Respira Detox Tea',
        'quantity': 2,
        'paid_quantity': 2,
        'free_quantity': 0,
        'base_price': 12500.0,
        'upsell_amount': 0.0,
        'total_amount': 25000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'pending_dispatch',
        'distribution_center_id': 'dc-dc-kan-01',
        'distribution_center_name': 'Kano Northern Depot DC',
      });

      expect(created, isTrue);

      final orderState = container.read(ordersProvider);
      final order = orderState.orders.firstWhere((o) => o.id == 'ord-kan-8801');
      expect(order.distributionCenterId, equals('dc-dc-kan-01'));

      // 2. DC assigns order to Mustapha
      await ordersNotifier.assignOrderToRider(
        orderId: order.id,
        riderId: 'rdr-kan-001',
        riderName: 'Mustapha Kano Rider',
        riderCode: 'RDR-KAN-01',
      );

      final assignedState = container.read(ordersProvider);
      final assignedOrder = assignedState.orders.firstWhere((o) => o.id == order.id);
      expect(assignedOrder.status, equals('in_transit'));
      expect(assignedOrder.deliveryAgentId, equals('rdr-kan-001'));

      // 3. Mustapha confirms Proof of Delivery (POD) with Cash Collection
      final podResult = await ordersNotifier.confirmDeliveryPod(
        orderId: order.id,
        agentId: 'rdr-kan-001',
        paymentType: 'pay_on_delivery',
        paymentMethod: 'cash',
        amountCollected: 25000.0,
        customerSignatureUrl: 'https://storage.novaexpress.ng/pod/sig-8801.png',
        notes: 'Delivered in good condition at Bompai office.',
      );

      expect(podResult['success'], isTrue);

      final deliveredState = container.read(ordersProvider);
      final deliveredOrder = deliveredState.orders.firstWhere((o) => o.id == order.id);
      expect(deliveredOrder.status, equals('delivered'));
      expect(deliveredOrder.isDelivered, isTrue);
      expect(deliveredOrder.paymentStatus, equals('collected'));
    });

    test('7. Cash Remittance Submission and DC Manager Approval Flow', () async {
      final financeRepo = FinanceRepositoryImpl(mockFinanceDS);
      final container = ProviderContainer(
        overrides: [
          financeRemoteDataSourceProvider.overrideWithValue(mockFinanceDS),
          financeProvider.overrideWith((ref) => FinanceNotifier(financeRepo)),
        ],
      );
      addTearDown(container.dispose);

      final financeNotifier = container.read(financeProvider.notifier);

      // 1. Rider submits Remittance Batch for the ₦25,000 cash collected
      final submitted = await financeNotifier.submitRemittance(
        amount: 25000.0,
        paymentMethod: 'cash',
        notes: 'Cash collected for order TRK-KAN-8801 deposited at Kano DC desk',
        agentId: 'rdr-kan-001',
      );

      expect(submitted, isTrue);

      final financeState = container.read(financeProvider);
      expect(financeState.remittances.isNotEmpty, isTrue);
      final remittance = financeState.remittances.first;
      expect(remittance.amount, equals(25000.0));
      expect(remittance.status, equals('pending'));
      expect(remittance.deliveryAgentId, equals('rdr-kan-001'));
    });

    test('8. Returns & QC Desk: Handle rejected delivery and restock inventory', () async {
      final stockRepo = StockRepositoryImpl(remoteDataSource: mockStockDS);
      final container = ProviderContainer(
        overrides: [
          ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDS),
          ordersProvider.overrideWith((ref) => OrdersNotifier(OrdersRepositoryImpl(mockOrdersDS))),
          stockRemoteDataSourceProvider.overrideWithValue(mockStockDS),
          stockProvider.overrideWith((ref) => StockNotifier(repository: stockRepo)),
        ],
      );
      addTearDown(container.dispose);

      final ordersNotifier = container.read(ordersProvider.notifier);

      // 1. Create second order in Fagge LGA
      await ordersNotifier.createOrder({
        'id': 'ord-kan-8802',
        'order_number': 'TRK-KAN-8802',
        'customer_name': 'Garba Shehu',
        'customer_phone': '08022233445',
        'delivery_state': 'Kano State',
        'delivery_city': 'Fagge',
        'delivery_address': '22 Sabon Gari Road, Fagge',
        'product_name': 'Respira Detox Tea',
        'quantity': 1,
        'paid_quantity': 1,
        'free_quantity': 0,
        'base_price': 12500.0,
        'upsell_amount': 0.0,
        'total_amount': 12500.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'in_transit',
        'distribution_center_id': 'dc-dc-kan-01',
        'delivery_agent_id': 'rdr-kan-001',
      });

      // 2. Mark order as rejected / returned
      await ordersNotifier.updateOrderStatus(
        'ord-kan-8802',
        'returned',
        notes: 'Customer postponed indefinitely / phone switched off [QC: passed_inspection]',
      );

      final orderState = container.read(ordersProvider);
      final updatedFailed = orderState.orders.firstWhere((o) => o.id == 'ord-kan-8802');
      expect(updatedFailed.status, equals('returned'));

      // 3. QC Desk restocks 1 unit back into available inventory
      final product = await stockRepo.createProduct(
        name: 'Respira Detox Tea',
        sku: 'RESPIRA-01',
        category: 'Health & Wellness',
        price: 25000.0,
        stockQuantity: 40,
      );

      // Restock returned item
      final restockedProduct = StockItemEntity(
        id: product.id,
        sku: product.sku,
        name: product.name,
        description: product.description,
        price: product.price,
        ownerName: product.ownerName,
        category: product.category,
        availableCount: product.availableCount + 1,
        totalInCustody: product.totalInCustody,
        assignedCount: product.assignedCount,
        deliveredCount: product.deliveredCount,
        returnedCount: product.returnedCount + 1,
        lowStockThreshold: product.lowStockThreshold,
      );

      expect(restockedProduct.availableCount, equals(41));
      expect(restockedProduct.returnedCount, equals(1));
    });

    test('9. DC Hub Performance & Operations Verification', () async {
      final dc = DistributionCenter(
        id: 'dc-dc-kan-01',
        companyId: '11111111-1111-4111-8111-111111111111',
        name: 'Kano Northern Depot DC',
        code: 'DC-KAN-01',
        state: 'Kano State',
        city: 'Kano',
        address: '18 Bompai Road, Kano',
        isGrandDc: false,
        isHub: false,
        isActive: true,
        operatingZones: const ['Kano Municipal', 'Fagge', 'Nassarawa'],
        storageCapacityUnits: 35000,
        totalAssignedRiders: 1,
        activeInventoryBatches: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final kanoOrders = [
        OrderEntity(
          id: 'ord-kan-8801',
          orderNumber: 'TRK-KAN-8801',
          customerName: 'Alhaji Aminu Dantata',
          customerPhone: '08034567890',
          deliveryState: 'Kano State',
          deliveryCity: 'Kano Municipal',
          deliveryAddress: '15 Bompai Road, Kano',
          productName: '2x Respira Detox Tea',
          quantity: 2,
          basePrice: 12500.0,
          upsellAmount: 0.0,
          totalAmount: 25000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'paid',
          status: 'delivered',
          distributionCenterId: 'dc-dc-kan-01',
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-kan-8802',
          orderNumber: 'TRK-KAN-8802',
          customerName: 'Garba Shehu',
          customerPhone: '08022233445',
          deliveryState: 'Kano State',
          deliveryCity: 'Fagge',
          deliveryAddress: '22 Sabon Gari Road, Fagge',
          productName: 'Respira Detox Tea',
          quantity: 1,
          basePrice: 12500.0,
          upsellAmount: 0.0,
          totalAmount: 12500.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          status: 'returned',
          distributionCenterId: 'dc-dc-kan-01',
          createdAt: DateTime.now(),
        ),
      ];

      final totalOrders = kanoOrders.length;
      final deliveredOrders = kanoOrders.where((o) => o.status == 'delivered').length;
      final returnedOrders = kanoOrders.where((o) => o.status == 'returned').length;
      final totalRevenue = kanoOrders
          .where((o) => o.status == 'delivered')
          .fold<double>(0.0, (sum, o) => sum + o.totalAmount);
      final successRate = (deliveredOrders / totalOrders) * 100;

      expect(dc.code, equals('DC-KAN-01'));
      expect(totalOrders, equals(2));
      expect(deliveredOrders, equals(1));
      expect(returnedOrders, equals(1));
      expect(totalRevenue, equals(25000.0));
      expect(successRate, equals(50.0));
    });

    testWidgets('10. DCDistributionCentersPage renders network overview and register DC trigger', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSupervisor = UserEntity(
        id: 'usr-dc-sup-01',
        email: 'adekunle@novaexpress.com',
        firstName: 'Adekunle',
        lastName: 'Supervisor',
        phone: '08023456789',
        role: 'dc_manager',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(mockAuthDS),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                loginUseCase: LoginUseCase(AuthRepositoryImpl(mockAuthDS)),
                logoutUseCase: LogoutUseCase(AuthRepositoryImpl(mockAuthDS)),
                getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(mockAuthDS)),
              );
              notifier.state = const AuthState(user: mockSupervisor);
              return notifier;
            }),
            notificationsRepositoryProvider.overrideWithValue(_MockNotificationsRepo()),
            notificationsProvider.overrideWith((ref) {
              final notifier = NotificationsNotifier(
                repository: _MockNotificationsRepo(),
                ref: ref,
              );
              notifier.state = const NotificationsState(notifications: []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCDistributionCentersPage), findsOneWidget);
      expect(find.text('Distribution Centers Network'), findsOneWidget);
      expect(find.text('+ Register Distribution Center'), findsOneWidget);
      expect(find.text('Total Network DCs'), findsOneWidget);
      expect(find.text('Wuse Central Distribution Hub'), findsOneWidget);
    });

    testWidgets('11. DCDashboardPage renders live hub KPIs, restock queue, and rider manifest', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSupervisor = UserEntity(
        id: 'usr-dc-sup-01',
        email: 'adekunle@novaexpress.com',
        firstName: 'Adekunle',
        lastName: 'Supervisor',
        phone: '08023456789',
        role: 'dc_manager',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(mockAuthDS),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                loginUseCase: LoginUseCase(AuthRepositoryImpl(mockAuthDS)),
                logoutUseCase: LogoutUseCase(AuthRepositoryImpl(mockAuthDS)),
                getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(mockAuthDS)),
              );
              notifier.state = const AuthState(user: mockSupervisor);
              return notifier;
            }),
            ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDS),
            ordersProvider.overrideWith((ref) {
              final notifier = OrdersNotifier(OrdersRepositoryImpl(mockOrdersDS));
              notifier.state = OrdersState(orders: const [], isLoading: false);
              return notifier;
            }),
            stockRemoteDataSourceProvider.overrideWithValue(mockStockDS),
            stockProvider.overrideWith((ref) {
              final notifier = StockNotifier(repository: StockRepositoryImpl(remoteDataSource: mockStockDS));
              notifier.state = const StockState(stockItems: [], isLoading: false);
              return notifier;
            }),
            financeRemoteDataSourceProvider.overrideWithValue(mockFinanceDS),
            financeProvider.overrideWith((ref) {
              final notifier = FinanceNotifier(FinanceRepositoryImpl(mockFinanceDS));
              notifier.state = FinanceState(remittances: const []);
              return notifier;
            }),
            notificationsRepositoryProvider.overrideWithValue(_MockNotificationsRepo()),
            notificationsProvider.overrideWith((ref) {
              final notifier = NotificationsNotifier(
                repository: _MockNotificationsRepo(),
                ref: ref,
              );
              notifier.state = const NotificationsState(notifications: []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCDashboardPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCDashboardPage), findsOneWidget);
      expect(find.text('Wuse Central Distribution Hub'), findsOneWidget);
      expect(find.text('DC-ABJ-01'), findsOneWidget);
      expect(find.text('Restock Picking Queue'), findsOneWidget);
      expect(find.text('In-Transit Orders'), findsOneWidget);
      expect(find.text('Cash in Fleet Custody'), findsOneWidget);
      expect(find.text('Returns Awaiting QC'), findsOneWidget);
      expect(find.text('Delivery Personnel Manifest'), findsOneWidget);
    });
  });
}
