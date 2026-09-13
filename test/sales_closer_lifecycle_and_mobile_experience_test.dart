import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Holistic Sales Closer Lifecycle & Mobile Experience Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Client Merchant can onboard closer with custom password & credentials', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Client onboards a new closer with password and initial avatar
      final closer = await clientNotifier.createCloser(
        fullName: 'Zainab Danjuma',
        email: 'zainab.closer@apexcommerce.ng',
        phone: '08123456789',
        dailyCallTarget: 45,
        commissionRate: 750.0,
        avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
        password: 'CloserSecure!2026',
      );

      expect(closer.fullName, equals('Zainab Danjuma'));
      expect(closer.email, equals('zainab.closer@apexcommerce.ng'));
      expect(closer.closerCode, contains('CLS-'));
      expect(closer.dailyCallTarget, equals(45));
      expect(closer.commissionRate, equals(750.0));
      expect(closer.avatarUrl, contains('images.unsplash.com'));
      expect(closer.isActive, isTrue);

      // Verify the credentials were registered in the in-memory fallback auth repository
      final authenticatedUser = await container.read(authRemoteDataSourceProvider).login(
            'zainab.closer@apexcommerce.ng',
            'CloserSecure!2026',
          );
      expect(authenticatedUser, isNotNull);
      expect(authenticatedUser.email, equals('zainab.closer@apexcommerce.ng'));
      expect(authenticatedUser.role, equals('closer'));
      expect(authenticatedUser.closerId, equals(closer.id));
      expect(authenticatedUser.closerCode, equals(closer.closerCode));

      // Client can also reset employee password
      await clientNotifier.resetCloserPassword(
        closerId: closer.id,
        newPassword: 'NewCloserPassword#2026',
      );

      // Verify closer can now log in with the new password
      final reAuthUser = await container.read(authRemoteDataSourceProvider).login(
            'zainab.closer@apexcommerce.ng',
            'NewCloserPassword#2026',
          );
      expect(reAuthUser, isNotNull);
      expect(reAuthUser.id, equals(authenticatedUser.id));
    });

    test('2. Closer Authentication, Dynamic Multi-tenant Scoping, and Profile Management', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Seed a closer account directly into auth remote datasource
      const initialCloserUser = UserModel(
        id: 'usr-closer-khalid',
        email: 'khalid.sales@apexcommerce.ng',
        firstName: 'Khalid',
        lastName: 'Bello',
        phone: '08099887766',
        role: 'closer',
        clientId: 'client-apex-99',
        clientCompanyName: 'Apex Commerce Ltd',
        closerId: 'closer-khalid-01',
        closerCode: 'CLS-APEX-007',
        avatarUrl: 'https://example.com/khalid-dp.png',
      );
      AuthRemoteDataSourceImpl.registerUserInMemory(initialCloserUser, 'KhalidPass123!');

      // Login closer
      final loginSuccess = await authNotifier.login('khalid.sales@apexcommerce.ng', 'KhalidPass123!');
      expect(loginSuccess, isTrue);

      final loggedInUser = container.read(authProvider).user;
      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.isCloser, isTrue);
      expect(loggedInUser.closerId, equals('closer-khalid-01'));
      expect(loggedInUser.closerCode, equals('CLS-APEX-007'));
      expect(loggedInUser.clientCompanyName, equals('Apex Commerce Ltd'));
      expect(loggedInUser.avatarUrl, equals('https://example.com/khalid-dp.png'));

      // Closer updates profile (Display picture DP and phone number)
      await authNotifier.updateProfile(
        firstName: 'Khalid',
        lastName: 'Bello Al-Mansur',
        phone: '08099887700',
        avatarUrl: 'https://example.com/khalid-new-avatar.jpg',
      );

      final updatedUser = container.read(authProvider).user;
      expect(updatedUser!.lastName, equals('Bello Al-Mansur'));
      expect(updatedUser.phone, equals('08099887700'));
      expect(updatedUser.avatarUrl, equals('https://example.com/khalid-new-avatar.jpg'));
      // Multi-tenant closer scoping must remain intact
      expect(updatedUser.closerId, equals('closer-khalid-01'));
      expect(updatedUser.closerCode, equals('CLS-APEX-007'));
      expect(updatedUser.clientId, equals('client-apex-99'));

      // Closer changes password
      final passChangeResult = await authNotifier.changePassword(
        oldPassword: 'KhalidPass123!',
        newPassword: 'BrandNewCloserPass2026!',
      );
      expect(passChangeResult['success'], isTrue);

      // Verify sign in with updated password
      final reLogin = await container.read(authRemoteDataSourceProvider).login(
            'khalid.sales@apexcommerce.ng',
            'BrandNewCloserPass2026!',
          );
      expect(reLogin, isNotNull);
      expect(reLogin.lastName, equals('Bello Al-Mansur'));
    });

    test('3. Closer creates commercial Packages and Promo Deals for products', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Closer creates a promotional package deal for a product
      final createdDeal = await clientNotifier.createPackage(
        productId: 'prod-herbal-tea-01',
        productName: 'Herbal Wellness Tea',
        packageName: 'Buy 2 Get 1 Free Promo Deal',
        quantity: 3,
        paidQuantity: 2,
        freeQuantity: 1,
        packagePrice: 42000.0,
        description: 'Special weekend telesales promo deal bundled for customers',
      );

      expect(createdDeal.packageName, equals('Buy 2 Get 1 Free Promo Deal'));
      expect(createdDeal.quantity, equals(3));
      expect(createdDeal.paidQuantity, equals(2));
      expect(createdDeal.freeQuantity, equals(1));
      expect(createdDeal.packagePrice, equals(42000.0));

      final statePackages = container.read(clientPortalProvider).packages;
      expect(statePackages.any((p) => p.packageName == 'Buy 2 Get 1 Free Promo Deal'), isTrue);
    });

    test('4. Closer creates orders with closer attribution and monitors live orders', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Simulate a closer creating a direct order
      final order = await clientNotifier.createOrder(
        customerName: 'Alhaji Sani Bello',
        customerPhone: '08022334455',
        deliveryAddress: 'House 8, Maitama Avenue, Abuja',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        productId: 'prod-herbal-tea-01',
        productName: 'Herbal Wellness Tea',
        quantity: 3,
        totalAmount: 42000.0,
        paymentType: 'Pay on Delivery (Cash/POS)',
        packageName: 'Buy 2 Get 1 Free Promo Deal',
        closerId: 'closer-khalid-01',
        closerName: 'Khalid Bello Al-Mansur',
        closerCode: 'CLS-APEX-007',
        notes: 'Customer requested afternoon delivery. Telesales closer: CLS-APEX-007',
      );

      expect(order.orderNumber, startsWith('NOV-'));
      expect(order.closerId, equals('closer-khalid-01'));
      expect(order.closerName, equals('Khalid Bello Al-Mansur'));
      expect(order.closerCode, equals('CLS-APEX-007'));
      expect(order.packageDealName, equals('Buy 2 Get 1 Free Promo Deal'));
      expect(order.totalAmount, equals(42000.0));

      // Check Closer Order Scoping
      final closerOrders = container.read(clientPortalProvider).getOrdersForCloser('closer-khalid-01');
      expect(closerOrders.length, greaterThanOrEqualTo(1));
      expect(closerOrders.any((o) => o.id == order.id), isTrue);

      // Verify dynamic performance metrics calculation
      final metrics = container.read(clientPortalProvider).getCloserPerformanceMetrics('closer-khalid-01');
      expect(metrics['bookedCount'], greaterThanOrEqualTo(1));
      expect(metrics['orders'], isA<List<OrderEntity>>());
    });

    test('5. One-Tap direct calling URI resolution for Customer and Rider', () {
      // Create test order with customer and rider contact info
      final order = OrderEntity(
        id: 'ord-test-calling-01',
        orderNumber: 'NOV-TEST-CALL-01',
        clientId: 'client-apex-99',
        customerName: 'Dr. Chinedu Eze',
        customerPhone: '+234 (0) 803-123-4567',
        deliveryAddress: '34 Garki Hospital Road, Area 10, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'Federal Capital Territory',
        lga: 'Abuja Municipal (AMAC)',
        basePrice: 35000.0,
        upsellAmount: 0.0,
        totalAmount: 35000.0,
        quantity: 2,
        status: 'in_transit',
        paymentType: 'Pay on Delivery (Cash/POS)',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
        deliveryAgentName: 'Musa Rider Express',
        deliveryAgentPhone: '0812-999-8877',
        closerId: 'closer-khalid-01',
        closerName: 'Khalid Bello',
        closerCode: 'CLS-APEX-007',
      );

      // Verify customer clean phone and calling URI
      final cleanCustomerPhone = order.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
      final customerCallUri = Uri.parse('tel:$cleanCustomerPhone');
      expect(customerCallUri.scheme, equals('tel'));
      expect(customerCallUri.path, equals('+23408031234567'));

      // Verify rider clean phone and calling URI
      final cleanRiderPhone = order.deliveryAgentPhone?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
      final riderCallUri = Uri.parse('tel:$cleanRiderPhone');
      expect(riderCallUri.scheme, equals('tel'));
      expect(riderCallUri.path, equals('08129998877'));
    });

    test('6. Merchant Closer Performance Leaderboard & Real-time Metrics Calculation', () {
      // Build a set of orders for closer Mary Okon
      final orders = [
        OrderEntity(
          id: 'ord-m1',
          orderNumber: 'NOV-M1',
          clientId: 'client-apex-99',
          customerName: 'Customer A',
          customerPhone: '08011111111',
          deliveryAddress: 'Address 1',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos State',
          basePrice: 25000.0,
          upsellAmount: 0.0,
          totalAmount: 25000.0,
          quantity: 1,
          status: 'delivered',
          paymentType: 'Pay on Delivery (Cash/POS)',
          paymentStatus: 'paid',
          createdAt: DateTime.now(),
          closerId: 'cls-mary-01',
          closerName: 'Mary Okon',
          closerCode: 'CLS-MARY-01',
        ),
        OrderEntity(
          id: 'ord-m2',
          orderNumber: 'NOV-M2',
          clientId: 'client-apex-99',
          customerName: 'Customer B',
          customerPhone: '08022222222',
          deliveryAddress: 'Address 2',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos State',
          basePrice: 30000.0,
          upsellAmount: 0.0,
          totalAmount: 30000.0,
          quantity: 1,
          status: 'delivered',
          paymentType: 'Pay on Delivery (Cash/POS)',
          paymentStatus: 'paid',
          createdAt: DateTime.now(),
          closerId: 'cls-mary-01',
          closerName: 'Mary Okon',
          closerCode: 'CLS-MARY-01',
        ),
        OrderEntity(
          id: 'ord-m3',
          orderNumber: 'NOV-M3',
          clientId: 'client-apex-99',
          customerName: 'Customer C',
          customerPhone: '08033333333',
          deliveryAddress: 'Address 3',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos State',
          basePrice: 20000.0,
          upsellAmount: 0.0,
          totalAmount: 20000.0,
          quantity: 1,
          status: 'in_transit',
          paymentType: 'Pay on Delivery (Cash/POS)',
          paymentStatus: 'pending',
          createdAt: DateTime.now(),
          closerId: 'cls-mary-01',
          closerName: 'Mary Okon',
          closerCode: 'CLS-MARY-01',
        ),
      ];

      const maryCloser = ClientCloser(
        id: 'cls-mary-01',
        clientId: 'client-apex-99',
        closerCode: 'CLS-MARY-01',
        fullName: 'Mary Okon',
        email: 'mary.okon@apexcommerce.ng',
        phone: '08044444444',
        commissionRate: 600.0,
        avatarUrl: 'https://example.com/mary.jpg',
      );

      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: 'client-apex-99',
          companyName: 'Apex Commerce Ltd',
          contactPerson: 'Director',
          email: 'director@apexcommerce.ng',
          phone: '08000000000',
          address: 'Abuja',
        ),
        closers: [maryCloser],
        orders: orders,
      );

      final metrics = state.getCloserPerformanceMetrics('cls-mary-01');

      // 3 orders booked in total
      expect(metrics['bookedCount'], equals(3));
      // 2 orders delivered
      expect(metrics['deliveredCount'], equals(2));
      // 1 order in transit
      expect(metrics['inTransitCount'], equals(1));
      // Gross sales from delivered orders: 25000 + 30000 = 55000
      expect(metrics['grossSales'], equals(55000.0));
      // Earned commission: 2 delivered * 600 = 1200
      expect(metrics['earnedCommission'], equals(1200.0));
      // Success rate: 2 / 3 * 100 = 66.67%
      expect((metrics['successRate'] as double), closeTo(66.67, 0.1));
    });

    test('7. CatalogProduct and ProductPackage value equality and dropdown resilience', () {
      final p1 = CatalogProduct(
        id: 'prod-uuid-1',
        name: 'Respira Detox Tea',
        sku: 'RDT-001',
        clientName: 'Novacare Limited',
        defaultUnitPrice: 21500.0,
      );

      final p2 = CatalogProduct(
        id: 'prod-uuid-1',
        name: 'Respira Detox Tea (Refreshed)',
        sku: 'RDT-001',
        clientName: 'Novacare Limited',
        defaultUnitPrice: 21500.0,
      );

      // Verify operator ==
      expect(p1 == p2, isTrue);
      expect(p1.hashCode, equals(p2.hashCode));

      final pkg1 = ProductPackage(
        id: 'pkg-1',
        productId: 'prod-uuid-1',
        productName: 'Respira Detox Tea',
        packageName: 'Single Pack',
        quantity: 1,
        packagePrice: 21500.0,
        clientName: 'Novacare Limited',
        createdAt: DateTime.now(),
      );

      final pkg2 = ProductPackage(
        id: 'pkg-1',
        productId: 'prod-uuid-1',
        productName: 'Respira Detox Tea',
        packageName: 'Single Pack (Updated)',
        quantity: 1,
        packagePrice: 21500.0,
        clientName: 'Novacare Limited',
        createdAt: DateTime.now(),
      );

      // Verify ProductPackage equality
      expect(pkg1 == pkg2, isTrue);
      expect(pkg1.hashCode, equals(pkg2.hashCode));

      // Test dropdown resolution logic:
      final rawProducts = [p1, p2]; // contains duplicates
      final seenIds = <String>{};
      final seenSkus = <String>{};
      final distinctProducts = <CatalogProduct>[];
      for (final p in rawProducts) {
        final idKey = p.id.trim();
        final skuKey = p.sku.trim().toUpperCase();
        if (idKey.isNotEmpty && seenIds.contains(idKey)) continue;
        if (skuKey.isNotEmpty && seenSkus.contains(skuKey)) continue;
        if (idKey.isNotEmpty) seenIds.add(idKey);
        if (skuKey.isNotEmpty) seenSkus.add(skuKey);
        distinctProducts.add(p);
      }

      // Must be deduplicated down to 1 item
      expect(distinctProducts.length, equals(1));

      // Must find exactly one matching item for p2
      final matching = distinctProducts.where((p) => p == p2);
      expect(matching.length, equals(1));
    });
  });
}
