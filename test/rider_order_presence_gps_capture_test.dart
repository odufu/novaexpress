import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/rider_location_service.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/services/geocoding_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/pages/confirm_delivery_pod_page.dart';
import 'package:novexps/features/orders/presentation/pages/log_delivery_failure_page.dart';
import 'package:novexps/features/orders/presentation/pages/order_detail_page.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOrdersRepo implements OrdersRepository {
  final List<OrderEntity> orders;
  Map<String, dynamic>? lastPodSubmission;
  Map<String, dynamic>? lastFailureSubmission;

  _FakeOrdersRepo(this.orders);

  Future<List<OrderEntity>> getOrders() async => orders;

  @override
  Future<OrderEntity> getOrderById(String id) async {
    return orders.firstWhere((o) => o.id == id || o.orderNumber == id);
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
    String? gatePassCode,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    lastPodSubmission = {
      'orderId': orderId,
      'agentId': agentId,
      'paymentType': paymentType,
      'paymentMethod': paymentMethod,
      'amountCollected': amountCollected,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'gatePassCode': gatePassCode,
    };
    return {'status': 'success', 'order_id': orderId};
  }

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async {
    lastFailureSubmission = {
      'orderId': orderId,
      'agentId': agentId,
      'reasonCode': reasonCode,
      'notes': notes,
      'scheduledCallbackAt': scheduledCallbackAt,
      'gatePassCode': gatePassCode,
      'latitude': latitude,
      'longitude': longitude,
    };
    return {'status': 'success', 'order_id': orderId};
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? notes, String? paymentStatus, String? paymentType, String? customerSignatureUrl, String? photoProofUrl, String? gatePassCode, double? latitude, double? longitude, bool? isLocationVerified}) async {}

  @override
  Future<void> assignOrderToRider({required String orderId, required String riderId, required String riderName, required String riderCode}) async {}

  @override
  Future<void> updateOrderCoordinates({required String orderId, required double latitude, required double longitude, bool isLocationVerified = true, String? geocodedAddress}) async {}

  Future<Map<String, dynamic>> triggerPaystackWebhookTest({required String orderNumber, required double amount, required String reference}) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier() : super(const StockState(stockItems: [], isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  _MockDCConsoleNotifier() : super(const DCConsoleState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rider Order Presence & Automatic GPS Location Capture Suite', () {
    testWidgets('1. ConfirmDeliveryPodPage displays GPS presence banner and captures coordinates upon payment submission', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testOrder = OrderModel(
        id: 'ord-pod-gps-01',
        orderNumber: 'NX-GPS-8821',
        customerName: 'Fatima Bello',
        customerPhone: '08023456789',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Maitama',
        deliveryAddress: '14 Gana Street, Maitama, Abuja',
        status: 'in_transit',
        quantity: 2,
        basePrice: 40000.0,
        upsellAmount: 0.0,
        totalAmount: 40000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        createdAt: DateTime(2026, 8, 28, 12, 0),
        latitude: 9.0882,
        longitude: 7.4933,
      );

      final fakeRepo = _FakeOrdersRepo([testOrder]);
      final ordersNotifier = OrdersNotifier(fakeRepo, GeocodingService());
      ordersNotifier.state = OrdersState(orders: [testOrder]);

      final locationNotifier = RiderLocationNotifier();
      locationNotifier.setPresetLocation('Maitama');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => ordersNotifier),
            riderLocationProvider.overrideWith((ref) => locationNotifier),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
          ],
          child: const MaterialApp(
            home: ConfirmDeliveryPodPage(orderId: 'ord-pod-gps-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify GPS presence banner is displayed
      expect(find.text('GPS PRESENCE PROOF CAPTURED'), findsOneWidget);
      expect(find.textContaining('9.08820°, 7.49330°'), findsOneWidget);

      // Submit cash delivery confirmation
      final submitBtn = find.widgetWithText(ElevatedButton, 'Confirm Cash Collection & POD');
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify repo received GPS coordinates and proof note
      expect(fakeRepo.lastPodSubmission, isNotNull);
      expect(fakeRepo.lastPodSubmission!['latitude'], equals(9.0882));
      expect(fakeRepo.lastPodSubmission!['longitude'], equals(7.4933));
      expect(fakeRepo.lastPodSubmission!['notes'], contains('GPS Proof: 9.08820°, 7.49330°'));
    });

    testWidgets('2. LogDeliveryFailurePage displays GPS presence banner and captures coordinates upon failure report', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testOrder = OrderModel(
        id: 'ord-fail-gps-02',
        orderNumber: 'NX-GPS-9912',
        customerName: 'Chinedu Eze',
        customerPhone: '08033334444',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki',
        deliveryAddress: 'Plot 12 Admiralty Way, Lekki, Lagos',
        status: 'in_transit',
        quantity: 1,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        createdAt: DateTime(2026, 8, 28, 14, 0),
      );

      final fakeRepo = _FakeOrdersRepo([testOrder]);
      final ordersNotifier = OrdersNotifier(fakeRepo, GeocodingService());
      ordersNotifier.state = OrdersState(orders: [testOrder]);

      final locationNotifier = RiderLocationNotifier();
      locationNotifier.setPresetLocation('Lekki');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => ordersNotifier),
            riderLocationProvider.overrideWith((ref) => locationNotifier),
          ],
          child: const MaterialApp(
            home: LogDeliveryFailurePage(orderId: 'ord-fail-gps-02'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify GPS presence banner is displayed
      expect(find.text('GPS ATTEMPT PROOF CAPTURED'), findsOneWidget);
      expect(find.textContaining('6.44740°, 3.48390°'), findsOneWidget);

      // Submit failure report
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Failure Report');
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify repo received GPS coordinates and proof note
      expect(fakeRepo.lastFailureSubmission, isNotNull);
      expect(fakeRepo.lastFailureSubmission!['latitude'], equals(6.4474));
      expect(fakeRepo.lastFailureSubmission!['longitude'], equals(3.4839));
      expect(fakeRepo.lastFailureSubmission!['notes'], contains('GPS Proof: 6.44740°, 3.48390°'));
    });

    testWidgets('3. OrderDetailPage renders Physical GPS Presence Proof card with coordinates and gate PIN', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deliveredOrder = OrderEntity(
        id: 'ord-presence-03',
        orderNumber: 'NX-GPS-7733',
        customerName: 'Amina Garba',
        customerPhone: '08055556666',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Garki',
        deliveryAddress: 'Area 11, Garki, Abuja',
        status: 'delivered',
        quantity: 1,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        fulfillmentType: 'distributed_inventory',
        createdAt: DateTime(2026, 8, 28, 15, 0),
        latitude: 9.0345,
        longitude: 7.4891,
        isLocationVerified: true,
        gatePassCode: 'GT-7733',
        deliveryNotes: '[POD Collected via Cash • Gate PIN: GT-7733 • GPS Proof: 9.03450°, 7.48910° (±3.0m)] Cash in custody.',
      );

      final fakeRepo = _FakeOrdersRepo([deliveredOrder]);
      final ordersNotifier = OrdersNotifier(fakeRepo, GeocodingService());
      ordersNotifier.state = OrdersState(orders: [deliveredOrder]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => ordersNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderDetailPage(orderId: 'ord-presence-03'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify GPS presence card is rendered
      expect(find.text('Physical GPS Presence Proof'), findsOneWidget);
      expect(find.text('DELIVERED PROOF ✓'), findsOneWidget);
      expect(find.text('9.03450°, 7.48910°'), findsOneWidget);
      expect(find.text('GT-7733'), findsWidgets);
      expect(find.text('Open GPS Presence Pin on Map'), findsOneWidget);
    });

    testWidgets('4. DCOrderDetailModal renders PHYSICAL PRESENCE GPS PROOF panel with verification status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dcDeliveredOrder = OrderEntity(
        id: 'ord-dc-gps-04',
        orderNumber: 'NX-DC-4421',
        customerName: 'Babatunde Raji',
        customerPhone: '08077778888',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Isaac John Street, GRA Ikeja, Lagos',
        status: 'delivered',
        quantity: 2,
        basePrice: 50000.0,
        upsellAmount: 0.0,
        totalAmount: 50000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        fulfillmentType: 'distributed_inventory',
        createdAt: DateTime(2026, 8, 28, 16, 0),
        latitude: 6.5922,
        longitude: 3.3556,
        isLocationVerified: true,
        gatePassCode: 'GT-4421',
        deliveryNotes: '[POD Collected via Cash • Gate PIN: GT-4421 • GPS Proof: 6.59220°, 3.35560° (±3.0m)] Cash in custody.',
      );

      final fakeRepo = _FakeOrdersRepo([dcDeliveredOrder]);
      final ordersNotifier = OrdersNotifier(fakeRepo, GeocodingService());
      ordersNotifier.state = OrdersState(orders: [dcDeliveredOrder]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => ordersNotifier),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: dcDeliveredOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify DC modal displays physical presence proof
      expect(find.text('PHYSICAL PRESENCE GPS PROOF'), findsOneWidget);
      expect(find.text('6.59220°, 3.35560°'), findsWidgets);
      expect(find.text('GT-4421'), findsWidgets);
      expect(find.text('✓ Real-time GPS Presence Verified & Committed to Database'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
    });
  });
}
