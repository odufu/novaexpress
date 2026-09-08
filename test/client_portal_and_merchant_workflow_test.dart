import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockAuthRemoteDS implements AuthRemoteDataSource {
  @override
  Future<UserModel?> getCurrentUser() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockRemoteDS implements StockRemoteDataSource {
  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId, String? dcId]) async => [];
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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Client Portal & E-Commerce Merchant Workflow Suite', () {
    test('1. Client Demo Authentication loads scoped UserModel with role client and Novacale Limited', () async {
      final dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseAnonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final authDataSource = AuthRemoteDataSourceImpl(dbClient);

      final user = await authDataSource.login('client.novacale@novaexpress.ng', 'ClientPass123!');

      expect(user, isNotNull);
      expect(user.role, equals('client'));
      expect(user.isClient, isTrue);
      expect(user.clientCompanyName, equals('Novacale Limited'));
      expect(user.email, equals('client.novacale@novaexpress.ng'));
      dbClient.dispose();
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

      const mockClientUser = UserEntity(
        id: 'cli-admin-01',
        email: 'client.novacale@novaexpress.ng',
        firstName: 'Chuka',
        lastName: 'Okafor',
        phone: '08034455667',
        role: 'client',
        clientCompanyName: 'Novacale Limited',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(_MockAuthRemoteDS()),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                loginUseCase: LoginUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
                logoutUseCase: LogoutUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
                getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
              );
              notifier.state = const AuthState(user: mockClientUser);
              return notifier;
            }),
            clientPortalProvider.overrideWith((ref) {
              final notifier = ClientPortalNotifier(ref);
              notifier.state = notifier.state.copyWith(
                clientProfile: const ClientProfile(
                  id: '33333333-3333-4333-8333-333333333333',
                  companyName: 'Novacale Limited',
                  contactPerson: 'Dr. Chuka Okafor',
                  email: 'client.novacale@novaexpress.ng',
                  phone: '08034455667',
                  address: 'Plot 12, Commercial Avenue, Central Business District, Abuja',
                  city: 'Abuja',
                  state: 'Federal Capital Territory',
                  code: 'CLI-NOVACALE-01',
                  tier: 'enterprise',
                  closerLimit: 250,
                  isEnterprise: true,
                  totalClosersCount: 3,
                ),
              );
              return notifier;
            }),
            ordersRemoteDataSourceProvider.overrideWithValue(_MockOrdersRemoteDS()),
            ordersProvider.overrideWith((ref) {
              final notifier = OrdersNotifier(OrdersRepositoryImpl(_MockOrdersRemoteDS()));
              notifier.state = OrdersState(orders: const [], isLoading: false);
              return notifier;
            }),
            stockRemoteDataSourceProvider.overrideWithValue(_MockStockRemoteDS()),
            stockProvider.overrideWith((ref) {
              final notifier = StockNotifier(repository: StockRepositoryImpl(remoteDataSource: _MockStockRemoteDS()));
              notifier.state = const StockState(stockItems: [], isLoading: false);
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
            home: ClientPortalLayout(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Novacale Limited'), findsWidgets);
      expect(find.text('Dashboard & KPIs'), findsOneWidget);
      expect(find.text('Deliveries & Orders'), findsOneWidget);
      expect(find.text('Products & Deals'), findsOneWidget);
      expect(find.text('Closers & Team'), findsOneWidget);
      expect(find.text('Create New Order'), findsWidgets);
    });
  });
}
