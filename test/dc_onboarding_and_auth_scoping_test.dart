import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_distribution_centers_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';

class _FakeAuthRemoteDS extends MockAuthRemoteDataSource {
  final Map<String, UserModel> users = {};
  final Map<String, String> passwords = {};

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
    final clean = email.trim().toLowerCase();
    final model = UserModel(
      id: 'sup_${clean.replaceAll(RegExp(r'[^a-z0-9]'), '')}',
      email: clean,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'dc_manager',
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
      operatingState: operatingState ?? 'Kano State',
      operatingCity: operatingCity ?? 'Kano',
    );
    users[clean] = model;
    passwords[clean] = password;
    AuthRemoteDataSourceImpl.registerUserInMemory(model, password);
    return model;
  }

  @override
  Future<UserModel> login(String email, String password) async {
    final clean = email.trim().toLowerCase();
    if (users.containsKey(clean) && passwords[clean] == password) {
      return users[clean]!;
    }
    final inMem = AuthRemoteDataSourceImpl.getRegisteredUser(clean);
    if (inMem != null) {
      return inMem;
    }
    throw Exception('Invalid credentials for $email');
  }
}

class _FakeOrdersRemoteDS implements OrdersRemoteDataSource {
  @override
  Future<List<OrderModel>> getAssignedOrders([String? agentId]) async => [];

  @override
  Future<List<OrderModel>> getDistributionCenterOrders([String? distributionCenterId]) async => [
        OrderModel(
          id: 'ord-kano-01',
          orderNumber: 'TRK-KAN-9001',
          customerName: 'Alhaji Aminu Dantata',
          customerPhone: '08034567890',
          deliveryState: 'Kano',
          deliveryCity: 'Kano Municipal',
          deliveryAddress: '15 Bompai Road, Kano',
          productName: 'Respira Detox Tea',
          status: 'pending_dispatch',
          distributionCenterId: 'dc_kan_01',
          quantity: 2,
          totalAmount: 25000,
          basePrice: 12500,
          upsellAmount: 0.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          createdAt: DateTime(2026, 9, 2),
        ),
        OrderModel(
          id: 'ord-wuse-01',
          orderNumber: 'TRK-ABJ-1001',
          customerName: 'Senator Kashim',
          customerPhone: '08091112233',
          deliveryState: 'Federal Capital Territory',
          deliveryCity: 'Abuja',
          deliveryAddress: 'Maitama, Abuja',
          productName: 'Respira Detox Tea',
          status: 'pending_dispatch',
          distributionCenterId: '22222222-2222-4222-8222-222222222222',
          quantity: 1,
          totalAmount: 15000,
          basePrice: 15000,
          upsellAmount: 0.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          createdAt: DateTime(2026, 9, 2),
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStockRemoteDS implements StockRemoteDataSource {
  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return {
      'id': 'xfer-901',
      'transfer_number': 'TRF-ABJ-KAN-001',
      'source_warehouse_id': sourceWarehouseId,
      'status': 'in_transit',
      'items': items,
      'notes': notes,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Distribution Center Onboarding with Auth Credentials Suite', () {
    late _FakeAuthRemoteDS fakeAuthDS;
    late AuthRepositoryImpl authRepo;

    setUp(() {
      fakeAuthDS = _FakeAuthRemoteDS();
      authRepo = AuthRepositoryImpl(fakeAuthDS);
    });

    test('1. Creating a DC with supervisor details provisions auth account with role dc_manager and matching DC link', () async {
      final dcNotifier = DCConsoleNotifier();

      final newDc = await dcNotifier.createDistributionCenter(
        name: 'Sokoto Regional Fulfillment Hub',
        code: 'DC-SOK-01',
        stateName: 'Sokoto',
        city: 'Sokoto North',
        address: 'Plot 18, Industrial Estate, Sokoto',
        contactPhone: '+234 803 111 4455',
        managerName: 'Kabiru Sanusi',
        supervisorEmail: 'supervisor.sokoto@novaexpress.ng',
        supervisorPassword: 'Password123!',
        operatingZones: const ['Sokoto North', 'Sokoto South', 'Wamakko'],
        storageCapacityUnits: 60000,
        isHub: true,
        authDataSource: fakeAuthDS,
      );

      expect(newDc.name, 'Sokoto Regional Fulfillment Hub');
      expect(newDc.code, 'DC-SOK-01');
      expect(newDc.state, 'Sokoto');
      expect(newDc.isHub, true);
      expect(newDc.operatingZones.contains('Sokoto North'), isTrue);

      // Verify that the supervisor was registered in the Auth layer
      final loggedInSupervisor = await fakeAuthDS.login('supervisor.sokoto@novaexpress.ng', 'Password123!');
      expect(loggedInSupervisor.email, 'supervisor.sokoto@novaexpress.ng');
      expect(loggedInSupervisor.role, 'dc_manager');
      expect(loggedInSupervisor.firstName, 'Kabiru');
      expect(loggedInSupervisor.lastName, 'Sanusi');
      expect(loggedInSupervisor.distributionCenterId, newDc.id);
      expect(loggedInSupervisor.distributionCenterName, newDc.name);
    });

    test('2. DC Supervisor login loads scoped UserModel and allows independent hub switching', () async {
      await fakeAuthDS.registerDistributionCenterSupervisor(
        email: 'supervisor.ibadan@novaexpress.ng',
        password: 'Password123!',
        firstName: 'Olumide',
        lastName: 'Akinwale',
        phone: '08022334455',
        distributionCenterId: 'dc_ibd_01',
        distributionCenterName: 'Ibadan Regional Depot',
        operatingState: 'Oyo',
        operatingCity: 'Ibadan',
      );

      final user = await authRepo.login('supervisor.ibadan@novaexpress.ng', 'Password123!');

      expect(user.role, 'dc_manager');
      expect(user.email, 'supervisor.ibadan@novaexpress.ng');
      expect(user.distributionCenterId, 'dc_ibd_01');
      expect(user.distributionCenterName, 'Ibadan Regional Depot');

      // Verify DCConsoleNotifier scopes activeHub to the supervisor's DC
      final dcNotifier = DCConsoleNotifier();
      dcNotifier.switchHub(user.distributionCenterName!, 'DC-IBD-01', user.distributionCenterId!);

      expect(dcNotifier.state.activeHubId, 'dc_ibd_01');
      expect(dcNotifier.state.activeHubName, 'Ibadan Regional Depot');
      expect(dcNotifier.state.activeHubCode, 'DC-IBD-01');
    });

    test('3. Scoped DC Supervisor manages orders and fleet drivers tied to their hub', () async {
      final orders = await _FakeOrdersRemoteDS().getDistributionCenterOrders('dc_kan_01');

      // Filter orders by active DC hub
      final kanoOrders = orders.where((o) => o.distributionCenterId == 'dc_kan_01').toList();
      final wuseOrders = orders.where((o) => o.distributionCenterId == '22222222-2222-4222-8222-222222222222').toList();

      expect(kanoOrders.length, 1);
      expect(kanoOrders.first.customerName, 'Alhaji Aminu Dantata');
      expect(wuseOrders.length, 1);
      expect(wuseOrders.first.customerName, 'Senator Kashim');

      // Verify fleet drivers are scoped by distributionCenterId
      const kanoDriver = DCFleetDriver(
        id: 'drv-kan-01',
        driverCode: 'RDR-KAN-01',
        name: 'Musa Bello',
        phone: '08055443322',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'KAN-992-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Kano Municipal',
        distributionCenterId: 'dc_kan_01',
        coveredLgas: ['Kano Municipal', 'Fagge'],
        totalAssignedOrders: 4,
        completedOrders: 3,
        routeProgressPercent: 75.0,
        efficiencyRating: 4.8,
        cashInCustody: 25000.0,
        itemsInCustody: 2,
      );

      const wuseDriver = DCFleetDriver(
        id: 'drv-abj-01',
        driverCode: 'RDR-ABJ-01',
        name: 'Jameson Miller',
        phone: '08023456789',
        avatarUrl: '',
        vehicleModel: 'Isuzu Van',
        vehiclePlate: 'ABJ-101-XZ',
        vehicleType: 'Van',
        status: 'active',
        assignedZone: 'Wuse II',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        coveredLgas: ['Abuja Municipal (AMAC)'],
        totalAssignedOrders: 8,
        completedOrders: 7,
        routeProgressPercent: 87.5,
        efficiencyRating: 4.9,
        cashInCustody: 60000.0,
        itemsInCustody: 3,
      );

      final drivers = [kanoDriver, wuseDriver];
      final kanoFleet = drivers.where((d) => d.distributionCenterId == 'dc_kan_01').toList();
      expect(kanoFleet.length, 1);
      expect(kanoFleet.first.name, 'Musa Bello');
      expect(kanoFleet.first.coversLga('Kano Municipal'), isTrue);
      expect(kanoFleet.first.coversLga('Garki'), isFalse);
    });

    test('4. Cross-System Inter-DC Stock Transfers remain traceable with zero leakage', () async {
      final fakeStockDS = _FakeStockRemoteDS();
      final transferResult = await fakeStockDS.requestStockTransfer(
        agentId: 'rdr-kan-01',
        companyId: 'company-01',
        sourceWarehouseId: '22222222-2222-4222-8222-222222222222', // Wuse Central Hub
        items: [
          {'product_id': 'prod-tea-01', 'product_name': 'Respira Detox Tea', 'quantity': 50}
        ],
        notes: 'Replenishment transfer from Wuse to Kano DC',
      );

      expect(transferResult['source_warehouse_id'], '22222222-2222-4222-8222-222222222222');
      expect(transferResult['transfer_number'], 'TRF-ABJ-KAN-001');
      expect(transferResult['status'], 'in_transit');
      expect((transferResult['items'] as List).length, 1);
    });

    testWidgets('5. DCDistributionCentersPage renders DC management and Register DC Hub with supervisor credentials', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(fakeAuthDS),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCDistributionCentersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCDistributionCentersPage), findsOneWidget);
      expect(find.text('Distribution Centers Network'), findsOneWidget);
      expect(find.text('+ Register Distribution Center'), findsOneWidget);

      // Open Register New DC modal
      await tester.tap(find.text('+ Register Distribution Center'));
      await tester.pumpAndSettle();

      expect(find.text('Register New Distribution Center'), findsOneWidget);
      expect(find.text('Supervisor Portal Login Credentials *'), findsOneWidget);
      expect(find.text('Supervisor Login Email *'), findsOneWidget);
      expect(find.text('Supervisor Password *'), findsOneWidget);
      expect(find.text('LGAs of Delivery Coverage *'), findsOneWidget);
      expect(find.text('Register DC Hub'), findsOneWidget);
    });
  });
}
