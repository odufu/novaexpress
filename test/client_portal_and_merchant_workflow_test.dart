import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Client Portal & E-Commerce Merchant Workflow Suite', () {
    test('1. Client Demo Authentication loads scoped UserModel with role client and Novacale Limited', () async {
      final authDataSource = AuthRemoteDataSourceImpl(
        SupabaseClient(SupabaseConstants.supabaseUrl, SupabaseConstants.supabaseAnonKey),
      );

      final user = await authDataSource.login('client.novacale@novaexpress.ng', 'ClientPass123!');

      expect(user, isNotNull);
      expect(user.role, equals('client'));
      expect(user.isClient, isTrue);
      expect(user.clientCompanyName, equals('Novacale Limited'));
      expect(user.email, equals('client.novacale@novaexpress.ng'));
    });

    test('2. Client creates commercial package deal on Grazer Tea product', () async {
      final container = ProviderContainer();
      try {
        final notifier = container.read(clientPortalProvider.notifier);

        final pkg = await notifier.createPackage(
          productId: 'prod-grazer-01',
          productName: 'Grazer Tea',
          packageName: '4 Packs Executive Saver Deal',
          quantity: 4,
          paidQuantity: 3,
          freeQuantity: 1,
          packagePrice: 60000.0,
          description: 'Buy 3 packs, get 1 pack free for VIP executives',
        );

        expect(pkg.packageName, equals('4 Packs Executive Saver Deal'));
        expect(pkg.quantity, equals(4));
        expect(pkg.packagePrice, equals(60000.0));
        expect(pkg.unitPrice, equals(15000.0));
        expect(pkg.clientName, equals('Novacale Limited'));

        final state = container.read(clientPortalProvider);
        expect(state.packages.any((p) => p.packageName == '4 Packs Executive Saver Deal'), isTrue);
      } finally {
        container.dispose();
      }
    });

    test('3. Client creates an order with State/LGA routing -> auto-dispatches to Grand DC and AMAC Rider', () async {
      final container = ProviderContainer();
      try {
        final notifier = container.read(clientPortalProvider.notifier);

        final order = await notifier.createOrder(
          customerName: 'Barrister Nnamdi Okon',
          customerPhone: '08091122334',
          deliveryState: 'Federal Capital Territory',
          deliveryLga: 'Abuja Municipal (AMAC)',
          deliveryAddress: 'Plot 77, Aminu Kano Crescent, Wuse II',
          productId: 'prod-grazer-01',
          productName: 'Grazer Tea',
          packageName: '2 Packs Promo Deal',
          quantity: 2,
          totalAmount: 35000.0,
          paymentType: 'Pay on Delivery (Cash/POS)',
        );

        expect(order.orderNumber, startsWith('NOV-'));
        expect(order.customerName, equals('Barrister Nnamdi Okon'));
        expect(order.deliveryLga, equals('Abuja Municipal (AMAC)'));
        expect(order.totalAmount, equals(35000.0));
        expect(order.quantity, equals(2));
        expect(order.clientName, equals('Novacale Limited'));
        expect(order.assignedAgentId, isNotNull); // Matched to AMAC rider (Emeka)
        expect(order.status, equals('assigned'));

        final state = container.read(clientPortalProvider);
        expect(state.orders.any((o) => o.id == order.id), isTrue);
        expect(state.totalOrdersCount, greaterThanOrEqualTo(1));
      } finally {
        container.dispose();
      }
    });

    test('4. Client creates order in unserviced state/LGA -> Escalates to Grand DC HQ for manual triage', () async {
      final container = ProviderContainer();
      try {
        final notifier = container.read(clientPortalProvider.notifier);

        final order = await notifier.createOrder(
          customerName: 'Mallam Bello Sokoto',
          customerPhone: '08039988771',
          deliveryState: 'Sokoto',
          deliveryLga: 'Wamakko',
          deliveryAddress: 'Near Usman Danfodiyo University Gate, Sokoto',
          productId: 'prod-grazer-01',
          productName: 'Grazer Tea',
          packageName: '1 Pack (Standard Retail)',
          quantity: 1,
          totalAmount: 22000.0,
        );

        expect(order.orderNumber, startsWith('NOV-'));
        expect(order.deliveryState, equals('Sokoto'));
        expect(order.deliveryLga, equals('Wamakko'));
        expect(order.status, equals('pending_dispatch'));
        // Escalated to Grand DC HQ
        expect(order.distributionCenterId, equals('22222222-2222-4222-8222-222222222222'));
        expect(order.assignedAgentId, isNull);
      } finally {
        container.dispose();
      }
    });

    test('5. Bulk CSV Order Import creates and routes multiple orders automatically', () async {
      final container = ProviderContainer();
      try {
        final notifier = container.read(clientPortalProvider.notifier);

        final importedCount = await notifier.importOrdersCsv([
          {
            'customer_name': 'Hajia Aisha Garba',
            'customer_phone': '08023344556',
            'state': 'Federal Capital Territory',
            'lga': 'Abuja Municipal (AMAC)',
            'address': 'House 22, 1st Avenue, Gwarinpa',
            'product_name': 'Grazer Tea',
            'quantity': '2',
            'amount': '35000',
          },
          {
            'customer_name': 'Engr. David Mark',
            'customer_phone': '07038877665',
            'state': 'Federal Capital Territory',
            'lga': 'Bwari',
            'address': 'Kubwa Extension Phase 4',
            'product_name': 'Grazer Tea',
            'quantity': '1',
            'amount': '22000',
          },
        ]);

        expect(importedCount, equals(2));
        final state = container.read(clientPortalProvider);
        expect(state.orders.length, greaterThanOrEqualTo(2));
      } finally {
        container.dispose();
      }
    });

    testWidgets('6. ClientPortalLayout renders sidebar navigation and merchant KPIs', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClientPortalLayout(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Novacale Limited'), findsWidgets);
      expect(find.text('Dashboard & KPIs'), findsOneWidget);
      expect(find.text('Customer Orders'), findsOneWidget);
      expect(find.text('Products & Deals'), findsOneWidget);
      expect(find.text('Create New Order'), findsWidgets);
    });
  });
}
