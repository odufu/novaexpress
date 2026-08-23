import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/helpers/address_synthesizer.dart';
import 'package:novexps/core/helpers/geo_proximity_calculator.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/services/geocoding_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  group('Backend Geocoding & Proximity Dispatch Suite', () {
    test('1. AddressSynthesizer removes noise, phone numbers and formats clean query', () {
      const rawMessyAddress = 'Plot 14 Admiralty Way, opposite Prince Ebeano, 08031234567 call when near';
      final cleaned = AddressSynthesizer.cleanAddressText(rawMessyAddress);
      expect(cleaned, isNot(contains('08031234567')));
      expect(cleaned, isNot(contains('call when near')));

      final query = AddressSynthesizer.synthesizeQuery(
        address: rawMessyAddress,
        city: 'Lekki Phase 1',
        state: 'Lagos',
      );
      expect(query, contains('Plot 14 Admiralty Way'));
      expect(query, contains('Lekki Phase 1'));
      expect(query, contains('Lagos'));
      expect(query, contains('Nigeria'));
    });

    test('2. GeoProximityCalculator accurately calculates Haversine distance and formats string', () {
      // Lekki Phase 1: 6.4474, 3.4839
      // Ikeja GRA: 6.5922, 3.3556
      final distLagosKm = GeoProximityCalculator.calculateDistanceKm(
        lat1: 6.4474,
        lon1: 3.4839,
        lat2: 6.5922,
        lon2: 3.3556,
      );
      expect(distLagosKm, greaterThan(15.0));
      expect(distLagosKm, lessThan(25.0));
      expect(GeoProximityCalculator.formatDistance(distLagosKm), contains('km'));

      // Close points (< 1km)
      final distCloseKm = GeoProximityCalculator.calculateDistanceKm(
        lat1: 9.0765,
        lon1: 7.4832,
        lat2: 9.0780,
        lon2: 7.4840,
      );
      expect(distCloseKm, lessThan(1.0));
      final formattedMeters = GeoProximityCalculator.formatDistance(distCloseKm);
      expect(formattedMeters, contains('m'));
    });

    test('3. GeocodingService local Nigerian dictionary resolves exact coordinates and confidence', () async {
      final service = GeocodingService();

      final lekkiResult = await service.resolveAddress(
        address: 'Admiralty Way, Lekki Phase 1',
        city: 'Lekki',
        state: 'Lagos',
      );
      expect(lekkiResult.latitude, closeTo(6.4474, 0.01));
      expect(lekkiResult.longitude, closeTo(3.4839, 0.01));
      expect(lekkiResult.locationConfidence, greaterThanOrEqualTo(0.90));
      expect(lekkiResult.geocodingStatus, 'exact_verified');

      final wuseResult = await service.resolveAddress(
        address: 'Aminu Kano Crescent, Wuse 2',
        city: 'Abuja',
        state: 'Abuja (FCT)',
      );
      expect(wuseResult.latitude, closeTo(9.0765, 0.01));
      expect(wuseResult.longitude, closeTo(7.4832, 0.01));
      expect(wuseResult.locationConfidence, greaterThanOrEqualTo(0.90));

      final genericAbujaResult = await service.resolveAddress(
        address: 'Unknown Street in Abuja',
        city: 'Abuja',
        state: 'Abuja',
      );
      expect(genericAbujaResult.geocodingStatus, 'locality_fallback');
      expect(genericAbujaResult.latitude, closeTo(9.0765, 0.1));
    });

    test('4. OrdersNotifier geocodeOrder updates coordinates in state', () async {
      final initialOrder = OrderEntity(
        id: 'ord-geo-1',
        orderNumber: 'NX-GEO-101',
        customerName: 'Tunde Bakare',
        customerPhone: '08099887766',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Isaac John Street, Ikeja GRA, Lagos',
        status: 'pending',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'NovaCare',
        createdAt: DateTime(2026, 8, 22, 10, 0),
      );

      final repo = MockOrdersRepository([initialOrder]);
      final service = GeocodingService();
      final notifier = OrdersNotifier(repo, service);
      notifier.state = OrdersState(isLoading: false, orders: [initialOrder]);

      await notifier.geocodeOrder('ord-geo-1');

      final updated = notifier.state.orders.firstWhere((o) => o.id == 'ord-geo-1');
      expect(updated.hasCoordinates, isTrue);
      expect(updated.latitude, closeTo(6.5922, 0.01));
      expect(updated.longitude, closeTo(3.3556, 0.01));
      expect(updated.isLocationVerified, isTrue);
    });
  });
}

class MockOrdersRepository implements OrdersRepository {
  final List<OrderEntity> list;
  MockOrdersRepository(this.list);

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
