import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/pages/order_detail_page.dart';
import 'package:novexps/features/orders/presentation/pages/orders_list_page.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/orders/presentation/widgets/order_card.dart';
import 'package:novexps/features/orders/presentation/widgets/pda_navigation_card.dart';

void main() {
  group('Rider PDA Navigation & WhatsApp Location Feature Tests', () {
    final sampleGeocodedOrder = OrderEntity(
      id: 'ord-1001',
      orderNumber: 'NX-998822',
      customerName: 'Amina Yusuf',
      customerPhone: '+2348031234567',
      customerAltPhone: '08099887766',
      deliveryState: 'Lagos',
      deliveryCity: 'Lekki Phase 1',
      deliveryAddress: 'Plot 14 Admiralty Way, Lekki Phase 1, Lagos',
      landmark: 'Near Prince Ebeano Supermarket',
      lga: 'Eti-Osa',
      productName: 'Respira Detox Tea',
      status: 'accepted',
      quantity: 2,
      paidQuantity: 2,
      freeQuantity: 0,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 50000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      fulfillmentType: 'distributed_inventory',
      clientName: 'NovaCare Limited',
      latitude: 6.44740,
      longitude: 3.48390,
      geocodingStatus: 'rooftop',
      locationConfidence: 'high',
      isLocationVerified: false,
      createdAt: DateTime(2026, 8, 22, 10, 0),
    );

    final sampleUnresolvedOrder = OrderEntity(
      id: 'ord-1002',
      orderNumber: 'NX-998823',
      customerName: 'Emeka Eze',
      customerPhone: '08123456789',
      deliveryState: 'Abuja',
      deliveryCity: 'Garki',
      deliveryAddress: 'Area 11, Garki, Abuja',
      status: 'pending',
      quantity: 1,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 25000.0,
      paymentType: 'prepaid',
      paymentStatus: 'paid',
      fulfillmentType: 'distributed_inventory',
      clientName: 'NovaCare Limited',
      locationConfidence: 'low',
      isLocationVerified: false,
      createdAt: DateTime(2026, 8, 22, 11, 0),
    );

    test('1. OrderEntity correctly calculates coordinates, phone numbers and navigation URIs', () {
      expect(sampleGeocodedOrder.hasCoordinates, isTrue);
      expect(sampleGeocodedOrder.coordinatesFormatted, '6.44740, 3.48390');
      expect(sampleGeocodedOrder.confidenceDisplay, 'High Accuracy PIN');
      expect(sampleGeocodedOrder.formattedWhatsAppPhone, '2348031234567');

      final navUri = sampleGeocodedOrder.googleMapsNavUri;
      expect(navUri.scheme, 'google.navigation');
      expect(navUri.toString(), 'google.navigation:q=6.4474,3.4839&mode=d');

      final waUri = sampleGeocodedOrder.getWhatsAppLocationRequestUri(riderName: 'Samuel Okon');
      expect(waUri.host, 'wa.me');
      expect(waUri.path, '/2348031234567');
      expect(waUri.queryParameters['text'], contains('Amina Yusuf'));
      expect(waUri.queryParameters['text'], contains('Samuel Okon'));
      expect(waUri.queryParameters['text'], contains('NX-998822'));
      expect(waUri.queryParameters['text'], contains('Live Pin'));
    });

    test('2. OrderEntity handles fallback for non-geocoded orders with local phone prefix', () {
      expect(sampleUnresolvedOrder.hasCoordinates, isFalse);
      expect(sampleUnresolvedOrder.coordinatesFormatted, 'Not Geocoded');
      expect(sampleUnresolvedOrder.confidenceDisplay, 'Area Centroid (Needs PIN)');
      expect(sampleUnresolvedOrder.formattedWhatsAppPhone, '2348123456789');

      final navUri = sampleUnresolvedOrder.googleMapsNavUri;
      expect(navUri.host, 'www.google.com');
      expect(navUri.queryParameters['query'], contains('Area 11, Garki, Abuja'));
    });

    test('3. OrderModel serialization and deserialization preserves all geocoding fields', () {
      final jsonMap = {
        'id': 'ord-test-55',
        'order_number': 'NX-554433',
        'customer_name': 'Bolanle Balogun',
        'customer_phone': '07031112233',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'delivery_address': '12 Isaac John Street, GRA Ikeja',
        'landmark': 'Beside Radisson Blu',
        'lga': 'Ikeja',
        'status': 'in_transit',
        'quantity': 1,
        'base_price': 25000.0,
        'upsell_amount': 0.0,
        'total_amount': 25000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'latitude': 6.59220,
        'longitude': 3.35560,
        'geocoding_status': 'exact_verified',
        'geocoded_address': '12 Isaac John St, Ikeja GRA, Lagos',
        'location_confidence': 'high',
        'is_location_verified': true,
        'created_at': '2026-08-22T08:00:00.000Z',
      };

      final model = OrderModel.fromJson(jsonMap);
      expect(model.id, 'ord-test-55');
      expect(model.latitude, 6.59220);
      expect(model.longitude, 3.35560);
      expect(model.isLocationVerified, isTrue);
      expect(model.confidenceDisplay, 'Verified Gate PIN');
      expect(model.formattedWhatsAppPhone, '2347031112233');

      final serialized = model.toJson();
      expect(serialized['latitude'], 6.59220);
      expect(serialized['longitude'], 3.35560);
      expect(serialized['is_location_verified'], isTrue);
      expect(serialized['location_confidence'], 'high');
    });

    testWidgets('4. PdaNavigationCard renders confidence pills, GPS navigation and WhatsApp actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PdaNavigationCard(order: sampleGeocodedOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dispatch & GPS Navigation'), findsOneWidget);
      expect(find.text('HIGH ACCURACY PIN (95%)'), findsOneWidget);
      expect(find.text('Plot 14 Admiralty Way, Lekki Phase 1, Lagos'), findsOneWidget);
      expect(find.text('Landmark: Near Prince Ebeano Supermarket'), findsOneWidget);
      expect(find.textContaining('GPS: 6.4474°, 3.4839°'), findsOneWidget);
      expect(find.text('TURN-BY-TURN GOOGLE MAPS GPS'), findsOneWidget);
      expect(find.text('WhatsApp Live Pin'), findsOneWidget);
      expect(find.text('Gate Pin'), findsOneWidget);
    });

    testWidgets('5. OrderDetailPage includes WhatsApp request button and PdaNavigationCard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockOrdersNotifier([sampleGeocodedOrder])),
          ],
          child: const MaterialApp(
            home: OrderDetailPage(orderId: 'ord-1001'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ORDER DETAILS'), findsOneWidget);
      expect(find.text('Customer Information'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
      expect(find.text('Dispatch & GPS Navigation'), findsOneWidget);
      expect(find.text('TURN-BY-TURN GOOGLE MAPS GPS'), findsOneWidget);
    });

    testWidgets('6. OrderCard renders location confidence pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderCard(order: sampleGeocodedOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NX-998822'), findsOneWidget);
      expect(find.text('Amina Yusuf'), findsOneWidget);
      expect(find.text('GPS PIN'), findsOneWidget);
    });

    testWidgets('7. OrdersListPage renders operational cards with location pills and WhatsApp actions', (tester) async {
      final mockNotifier = MockOrdersNotifier([sampleGeocodedOrder, sampleUnresolvedOrder]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => mockNotifier),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                loginUseCase: LoginUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
                logoutUseCase: LogoutUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
                getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
              );
              notifier.state = const AuthState(
                user: UserEntity(
                  id: 'b1111111-1111-4111-8111-111111111111',
                  email: 'emeka.rider@novaexpress.ng',
                  firstName: 'Emeka',
                  lastName: 'Rider',
                  phone: '08031234567',
                  role: 'delivery_agent',
                  deliveryAgentCode: 'PDA-7000',
                ),
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: OrdersListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DELIVERIES'), findsOneWidget);
      expect(find.text('Amina Yusuf'), findsOneWidget);
      expect(find.text('Emeka Eze'), findsOneWidget);
      expect(find.text('GPS PIN 📍'), findsOneWidget);
      expect(find.text('NEED PIN ❓'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
    });
  });
}

class MockOrdersNotifier extends OrdersNotifier {
  final List<OrderEntity> _initial;
  MockOrdersNotifier(this._initial) : super(MockOrdersRepository(_initial)) {
    state = OrdersState(isLoading: false, orders: _initial);
  }

  @override
  Future<void> loadOrders([String? agentId]) async {
    state = state.copyWith(isLoading: false, orders: _initial);
  }
}

class MockOrdersRepository implements OrdersRepository {
  final List<OrderEntity> initialList;
  MockOrdersRepository([this.initialList = const []]);

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => initialList;

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => initialList;

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
  Future<OrderEntity> getOrderById(String orderId) async {
    return initialList.firstWhere((o) => o.id == orderId, orElse: () => throw UnimplementedError());
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes}) async {}

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

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel> login(String email, String password) async => const UserModel(
        id: 'b1111111-1111-4111-8111-111111111111',
        email: 'emeka.rider@novaexpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08031234567',
        role: 'delivery_agent',
        deliveryAgentCode: 'PDA-7000',
      );

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getCurrentUser() async => const UserModel(
        id: 'b1111111-1111-4111-8111-111111111111',
        email: 'emeka.rider@novaexpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08031234567',
        role: 'delivery_agent',
        deliveryAgentCode: 'PDA-7000',
      );

  @override
  Future<UserModel> registerDeliveryAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String personnelType,
    required String compensationType,
    required double commissionRate,
    required double transportAllowance,
    required double fuelAllowance,
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    String? assignedAgentCode,
    String? assignedZone,
  }) async =>
      throw UnimplementedError();
}
