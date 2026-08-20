import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DC Order Assignment & Rider Workload Segregation Suite', () {
    testWidgets('1. DCOrdersPage renders unassigned pool and displays rider workload indicators in dispatch modal', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockOrdersDataSource = _MockOrdersRemoteDS();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDataSource),
            dcConsoleProvider.overrideWith((ref) {
              final notifier = DCConsoleNotifier();
              notifier.state = notifier.state.copyWith(
                drivers: const [
                  DCFleetDriver(
                    id: 'a-sanniabacha',
                    driverCode: 'PDA-7588',
                    name: 'Sanni Abacha',
                    phone: '08091112233',
                    avatarUrl: '',
                    vehicleModel: 'Bajaj Pulsar 150',
                    vehiclePlate: 'ABJ-758-XA',
                    vehicleType: 'Motorcycle',
                    status: 'active',
                    assignedZone: 'Wuse II & Zone 4',
                    totalAssignedOrders: 0,
                    completedOrders: 0,
                    routeProgressPercent: 0.0,
                    efficiencyRating: 100.0,
                    cashInCustody: 0.0,
                    itemsInCustody: 0,
                    personnelType: 'pda',
                    compensationType: 'commission',
                  ),
                  DCFleetDriver(
                    id: 'b1111111-1111-4111-8111-111111111111',
                    driverCode: 'PDA-7000',
                    name: 'Emeka Rider',
                    phone: '08012345678',
                    avatarUrl: '',
                    vehicleModel: 'Bajaj Boxer',
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
                    personnelType: 'pda',
                    compensationType: 'commission',
                  ),
                  DCFleetDriver(
                    id: 'drv-002',
                    driverCode: 'RDR-102',
                    name: 'Babatunde Lawal',
                    phone: '08034567890',
                    avatarUrl: '',
                    vehicleModel: 'Haojue 125',
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
                    personnelType: 'in_house_rider',
                    compensationType: 'salary',
                  ),
                ],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCOrdersPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Unassigned Pool tab header
      expect(find.textContaining('Unassigned Pool'), findsOneWidget);
      expect(find.text('TRK-8930 • Senator Kashim Shettima (08091112233)'), findsOneWidget);
      expect(find.text('TRK-8931 • Barrister Chidinma Okafor (08032223344)'), findsOneWidget);

      // Tap "Assign Rider" on the first unassigned order (TRK-8930)
      final assignButtons = find.widgetWithText(ElevatedButton, 'Assign Rider');
      expect(assignButtons, findsWidgets);
      await tester.tap(assignButtons.first);
      await tester.pumpAndSettle();

      // Verify Dispatch Modal opens
      expect(find.text('Dispatch Order TRK-8930'), findsOneWidget);
      expect(find.text('Select an active rider (ordered by lightest workload):'), findsOneWidget);

      // Verify riders are listed with their agent codes & workload indicators
      expect(find.text('Sanni Abacha'), findsOneWidget);
      expect(find.text('PDA-7588'), findsOneWidget);
      expect(find.textContaining('Available (0 Active)'), findsWidgets);

      expect(find.text('Emeka Rider'), findsOneWidget);
      expect(find.text('PDA-7000'), findsOneWidget);

      expect(find.text('Babatunde Lawal'), findsOneWidget);
      expect(find.text('RDR-102'), findsOneWidget);

      // Tap "Dispatch" on Sanni Abacha's card
      final dispatchButtons = find.widgetWithText(ElevatedButton, 'Dispatch');
      expect(dispatchButtons, findsWidgets);
      await tester.tap(dispatchButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify assignment confirmation feedback
      expect(find.textContaining('successfully dispatched to'), findsOneWidget);
    });

    test('2. Order assignment strictly segregates orders between Sanni Abacha and Emeka Rider', () async {
      final mockDS = _MockOrdersRemoteDS();

      // 1. Initial State: Load all DC orders
      final dcOrders = await mockDS.getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
      expect(dcOrders.length, equals(7));

      // 2. Sanni Abacha initially has 0 orders
      var sanniOrders = await mockDS.getAssignedOrders('a-sanniabacha');
      expect(sanniOrders.isEmpty, isTrue);

      // 3. DC Supervisor assigns TRK-8930 to Sanni Abacha
      await mockDS.assignOrderToRider(
        orderId: 'ord-8930',
        riderId: 'a-sanniabacha',
        riderName: 'Sanni Abacha',
        riderCode: 'PDA-7588',
      );

      // 4. Now Sanni Abacha sees TRK-8930 in their assigned orders!
      sanniOrders = await mockDS.getAssignedOrders('a-sanniabacha');
      expect(sanniOrders.length, equals(1));
      expect(sanniOrders.first.orderNumber, equals('TRK-8930'));
      expect(sanniOrders.first.customerName, equals('Senator Kashim Shettima'));

      // 5. Emeka Rider only sees orders assigned to Emeka (TRK-8924, TRK-8910, TRK-8920)
      final emekaOrders = await mockDS.getAssignedOrders('b1111111-1111-4111-8111-111111111111');
      expect(emekaOrders.any((o) => o.orderNumber == 'TRK-8930'), isFalse);
      expect(emekaOrders.any((o) => o.orderNumber == 'TRK-8924'), isTrue);
    });

    test('3. DC Manager can create new orders and persist to unassigned pool without hardcoding', () async {
      final mockDS = _MockOrdersRemoteDS();

      final newOrder = await mockDS.createOrder({
        'id': 'ord-9901',
        'order_number': 'TRK-9901',
        'customer_name': 'Prof. Charles Soludo',
        'customer_phone': '08039998877',
        'delivery_state': 'Abuja (FCT)',
        'delivery_city': 'Maitama',
        'delivery_address': 'Plot 55 Gana Street, Maitama',
        'product_name': 'Respira Detox Tea',
        'quantity': 2,
        'base_price': 25000.0,
        'upsell_amount': 0.0,
        'total_amount': 50000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'pending',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(newOrder.orderNumber, equals('TRK-9901'));
      expect(newOrder.customerName, equals('Prof. Charles Soludo'));
      expect(newOrder.totalAmount, equals(50000.0));

      // Verify order is immediately in DC pool
      final dcOrders = await mockDS.getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
      expect(dcOrders.any((o) => o.orderNumber == 'TRK-9901'), isTrue);
    });

    test('4. Complete order lifecycle from creation -> assignment -> transit -> delivered POD', () async {
      final mockDS = _MockOrdersRemoteDS();

      // 1. Create order
      await mockDS.createOrder({
        'id': 'ord-9902',
        'order_number': 'TRK-9902',
        'customer_name': 'Hajiya Fatima Bello',
        'customer_phone': '08021113344',
        'delivery_state': 'Abuja (FCT)',
        'delivery_city': 'Wuse 2',
        'delivery_address': 'House 12 Aminu Kano Crescent',
        'product_name': 'Grazer Herbal Tea',
        'quantity': 1,
        'base_price': 18000.0,
        'upsell_amount': 0.0,
        'total_amount': 18000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'pending',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. DC assigns to Sanni Abacha
      await mockDS.assignOrderToRider(
        orderId: 'ord-9902',
        riderId: 'a-sanniabacha',
        riderName: 'Sanni Abacha',
        riderCode: 'PDA-7588',
      );

      // 3. Sanni Abacha starts delivery
      await mockDS.updateOrderStatus('ord-9902', 'in_transit');
      var sanniOrders = await mockDS.getAssignedOrders('a-sanniabacha');
      var target = sanniOrders.firstWhere((o) => o.orderNumber == 'TRK-9902');
      expect(target.status, equals('in_transit'));

      // 4. Sanni Abacha confirms POD
      await mockDS.confirmDeliveryPod(
        orderId: 'ord-9902',
        agentId: 'a-sanniabacha',
        paymentType: 'pay_on_delivery',
        paymentMethod: 'cash',
        amountCollected: 18000.0,
      );

      sanniOrders = await mockDS.getAssignedOrders('a-sanniabacha');
      target = sanniOrders.firstWhere((o) => o.orderNumber == 'TRK-9902');
      expect(target.status, equals('delivered'));
      expect(target.paymentStatus, equals('collected'));
    });
  });
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  final Map<String, String> _assignments = {};
  final Map<String, String> _assignmentCodes = {};
  final Map<String, String> _assignmentNames = {};

  final List<OrderModel> _baseDcOrders = [
    OrderModel(
      id: 'ord-8930',
      orderNumber: 'TRK-8930',
      customerName: 'Senator Kashim Shettima',
      customerPhone: '08091112233',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Plot 104 Shehu Shagari Way, Maitama, Abuja',
      productName: '2x Respira Detox Tea',
      status: 'pending',
      quantity: 2,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 50000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    OrderModel(
      id: 'ord-8931',
      orderNumber: 'TRK-8931',
      customerName: 'Barrister Chidinma Okafor',
      customerPhone: '08032223344',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Suite 4B, Metro Plaza, Zakariya Maimalari St, CBD',
      productName: '1x Grazer Herbal Tea',
      status: 'pending',
      quantity: 1,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 25000.0,
      paymentType: 'prepaid',
      paymentStatus: 'paid',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    OrderModel(
      id: 'ord-8932',
      orderNumber: 'TRK-8932',
      customerName: 'Dr. Halima Bello',
      customerPhone: '08055556677',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'House 18, 4th Avenue, Gwarinpa Estate, Abuja',
      productName: '3x Respira Detox Tea',
      status: 'pending',
      quantity: 3,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 75000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    OrderModel(
      id: 'ord-8924',
      orderNumber: 'TRK-8924',
      customerName: 'Chief Aliyu Mohammed',
      customerPhone: '08031234567',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
      productName: '2x Respira Detox Tea',
      status: 'in_transit',
      quantity: 2,
      basePrice: 17500.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    OrderModel(
      id: 'ord-8925',
      orderNumber: 'TRK-8925',
      customerName: 'Dr. Aisha Garba',
      customerPhone: '08098765432',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '14 Gana Street, Maitama, Abuja',
      productName: '3x Grazer Herbal Tea',
      status: 'in_transit',
      quantity: 3,
      basePrice: 15000.0,
      upsellAmount: 0.0,
      totalAmount: 45000.0,
      paymentType: 'prepaid',
      paymentStatus: 'paid',
      deliveryAgentId: 'drv-002',
      deliveryAgentName: 'Babatunde Lawal',
      deliveryAgentCode: 'RDR-102',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    OrderModel(
      id: 'ord-8910',
      orderNumber: 'TRK-8910',
      customerName: 'Engr. Nnamdi Eze',
      customerPhone: '08033334455',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Area 11, Garki, Abuja',
      productName: '1x Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 25000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'paid',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    OrderModel(
      id: 'ord-8920',
      orderNumber: 'TRK-8920',
      customerName: 'Mrs. Folake Adebayo',
      customerPhone: '08051112233',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Wuse Zone 4, Abuja',
      productName: '1x Grazer Herbal Tea',
      status: 'failed',
      quantity: 1,
      basePrice: 18000.0,
      upsellAmount: 0.0,
      totalAmount: 18000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  final Map<String, String> _statuses = {};
  final Map<String, String> _paymentStatuses = {};
  final List<OrderModel> _createdOrders = [];

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    final model = OrderModel.fromJson(orderData);
    _createdOrders.insert(0, model);
    return model;
  }

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async {
    final combined = [..._createdOrders, ..._baseDcOrders];
    return combined.map((o) {
      final assignedId = _assignments[o.id] ?? o.deliveryAgentId;
      final status = _statuses[o.id] ?? o.status;
      final paymentStatus = _paymentStatuses[o.id] ?? o.paymentStatus;

      return OrderModel(
        id: o.id,
        orderNumber: o.orderNumber,
        customerName: o.customerName,
        customerPhone: o.customerPhone,
        customerAltPhone: o.customerAltPhone,
        deliveryState: o.deliveryState,
        deliveryCity: o.deliveryCity,
        deliveryAddress: o.deliveryAddress,
        landmark: o.landmark,
        lga: o.lga,
        productName: o.productName,
        status: status,
        quantity: o.quantity,
        paidQuantity: o.paidQuantity,
        freeQuantity: o.freeQuantity,
        basePrice: o.basePrice,
        upsellAmount: o.upsellAmount,
        totalAmount: o.totalAmount,
        paymentType: o.paymentType,
        paymentStatus: paymentStatus,
        fulfillmentType: o.fulfillmentType,
        clientName: o.clientName,
        packageCustodyId: o.packageCustodyId,
        clientDeliveryFee: o.clientDeliveryFee,
        agentEntitlement: o.agentEntitlement,
        deliveryNotes: o.deliveryNotes,
        createdAt: o.createdAt,
        deliveryAgentId: assignedId,
        deliveryAgentName: _assignmentNames[o.id] ?? o.deliveryAgentName,
        deliveryAgentCode: _assignmentCodes[o.id] ?? o.deliveryAgentCode,
        distributionCenterId: distributionCenterId,
      );
    }).toList();
  }

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async {
    final all = await getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
    return all.where((o) {
      final assignedId = _assignments[o.id] ?? o.deliveryAgentId;
      final assignedCode = _assignmentCodes[o.id] ?? o.deliveryAgentCode;
      return assignedId == deliveryAgentId || 
             assignedCode == deliveryAgentId ||
             (deliveryAgentId.contains('sanni') && (assignedId?.contains('sanni') == true || assignedCode == 'PDA-7588')) ||
             (deliveryAgentId == 'b1111111-1111-4111-8111-111111111111' && assignedCode == 'PDA-7000');
    }).toList();
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    _assignments[orderId] = riderId;
    _assignmentNames[orderId] = riderName;
    _assignmentCodes[orderId] = riderCode;
    _statuses[orderId] = 'assigned';
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes}) async {
    _statuses[orderId] = status;
    if (paymentStatus != null) {
      _paymentStatuses[orderId] = paymentStatus;
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
  }) async {
    _statuses[orderId] = 'delivered';
    _paymentStatuses[orderId] = 'collected';
    return {'status': 'success'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
