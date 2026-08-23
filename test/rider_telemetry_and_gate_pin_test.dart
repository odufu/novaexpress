import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/rider_location_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/services/geocoding_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Rider Telemetry, Gate Pin & GIS Proximity Verification Suite', () {
    test('1. RiderLocationNotifier updates coordinates and handles presets', () {
      final notifier = RiderLocationNotifier();
      expect(notifier.state.latitude, 9.0765);
      expect(notifier.state.longitude, 7.4832);

      notifier.setPresetLocation('Maitama');
      expect(notifier.state.latitude, 9.0882);
      expect(notifier.state.longitude, 7.4933);
      expect(notifier.state.locationLabel, contains('Maitama'));

      notifier.setPresetLocation('Lekki');
      expect(notifier.state.latitude, 6.4474);
      expect(notifier.state.longitude, 3.4839);

      notifier.dispose();
    });

    test('2. OrdersNotifier.recordVerifiedGatePin upgrades order to exact_verified', () async {
      final sampleOrder = OrderEntity(
        id: 'ord-pin-001',
        orderNumber: 'TRK-PIN-100',
        customerName: 'Alhaji Danladi',
        customerPhone: '08091112233',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
        status: 'in_transit',
        quantity: 2,
        basePrice: 44000.0,
        upsellAmount: 0.0,
        totalAmount: 44000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'NovaHealth',
        createdAt: DateTime(2026, 8, 22, 10, 0),
        latitude: 9.0765,
        longitude: 7.4832,
        isLocationVerified: false,
        locationConfidence: 'medium',
        geocodingStatus: 'landmark_match',
      );

      final mockRepo = _MockOrdersRepo([sampleOrder]);
      final geocodingService = GeocodingService();
      final notifier = OrdersNotifier(mockRepo, geocodingService);
      notifier.state = OrdersState(orders: [sampleOrder]);

      final result = await notifier.recordVerifiedGatePin(
        orderId: 'ord-pin-001',
        latitude: 9.076550,
        longitude: 7.483210,
        pinLabel: 'Front security gate with black sign',
      );

      expect(result['success'], isTrue);
      final updated = notifier.state.orders.firstWhere((o) => o.id == 'ord-pin-001');
      expect(updated.isLocationVerified, isTrue);
      expect(updated.geocodingStatus, equals('exact_verified'));
      expect(updated.locationConfidence, equals('high'));
      expect(updated.latitude, equals(9.076550));
    });

    testWidgets('3. DCOrdersPage dispatch modal shows GIS Nearest Rider Match for geocoded orders', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final unassignedOrder = OrderModel(
        id: 'ord-gis-001',
        orderNumber: 'TRK-GIS-99',
        customerName: 'Dr. Ngozi Okonjo',
        customerPhone: '08023456789',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Adetokunbo Ademola Crescent, Wuse 2, Abuja',
        status: 'pending',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'NovaCare',
        createdAt: DateTime(2026, 8, 22, 10, 0),
        latitude: 9.0765,
        longitude: 7.4832,
      );

      final mockOrdersDataSource = _MockOrdersRemoteDS([unassignedOrder]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDataSource),
            ordersProvider.overrideWith((ref) {
              final notifier = OrdersNotifier(_MockOrdersRepo([unassignedOrder]));
              notifier.state = OrdersState(isLoading: false, orders: [unassignedOrder]);
              return notifier;
            }),
            dcConsoleProvider.overrideWith((ref) {
              final notifier = DCConsoleNotifier();
              notifier.state = notifier.state.copyWith(
                drivers: const [
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
                    totalAssignedOrders: 0,
                    completedOrders: 0,
                    routeProgressPercent: 0.0,
                    efficiencyRating: 100.0,
                    cashInCustody: 0.0,
                    itemsInCustody: 0,
                    personnelType: 'pda',
                    compensationType: 'commission',
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

      // Open dispatch modal
      final assignButton = find.widgetWithText(ElevatedButton, 'Assign Rider');
      expect(assignButton, findsOneWidget);
      await tester.tap(assignButton);
      await tester.pumpAndSettle();

      // Verify GIS Nearest Rider Match card
      expect(find.text('🎯 GIS Nearest Rider Match'), findsOneWidget);
      expect(find.textContaining('Emeka Rider'), findsWidgets);
      expect(find.text('Auto-Dispatch'), findsOneWidget);
    });
  });
}

class _MockOrdersRepo implements OrdersRepository {
  final List<OrderEntity> list;
  _MockOrdersRepo(this.list);

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => list;

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => list;

  @override
  Future<OrderEntity> createOrder(Map<String, dynamic> orderData) async => OrderModel.fromJson(orderData);

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {}

  @override
  Future<OrderEntity> getOrderById(String orderId) async => list.firstWhere((o) => o.id == orderId);

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? paymentType, String? notes}) async {}

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
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  }) async => {'status': 'success'};

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {}
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  final List<OrderModel> orders;
  _MockOrdersRemoteDS([this.orders = const []]);

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async => orders;

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async => orders;

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async => OrderModel.fromJson(orderData);

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {}

  @override
  Future<OrderModel> getOrderById(String orderId) async => orders.firstWhere((o) => o.id == orderId);

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? paymentType, String? notes}) async {}

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
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  }) async => {'status': 'success'};

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {}
}
