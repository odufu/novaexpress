import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/closer_mobile_portal_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/widgets/order_card.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserModel user)
      : super(AuthState(
          user: user,
          isInitialized: true,
        ));

  @override
  Future<void> checkCurrentUser() async {}

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClientPortalNotifier extends StateNotifier<ClientPortalState>
    implements ClientPortalNotifier {
  FakeClientPortalNotifier(ClientCloser closer, OrderEntity order)
      : super(ClientPortalState(
          isLoading: false,
          closers: [closer],
          clientProfile: const ClientProfile(
            id: 'cli-nova-01',
            companyName: 'Novacare Health & Wellness',
            contactPerson: 'Maribel Nwalozie',
            email: 'maribel@novacare.ng',
            phone: '08107418058',
            address: 'Plot 10, Abuja',
            closerLimit: 10,
          ),
          orders: [order],
          products: [],
          leads: [],
        ));

  @override
  Future<void> loadClientData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProductCatalogNotifier extends StateNotifier<ProductCatalogState>
    implements ProductCatalogNotifier {
  FakeProductCatalogNotifier()
      : super(const ProductCatalogState(products: []));

  @override
  Future<void> reloadCatalog() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleOrder = OrderEntity(
    id: 'ord-test-01',
    orderNumber: 'Novacare Ltd-CRM-ORD-10-021340',
    customerName: 'Michael A',
    customerPhone: '+2348035798687',
    deliveryAddress: '12, road A Ifedayo Avenue Iju Akure north LG',
    deliveryCity: 'Akure South',
    deliveryState: 'Ondo',
    productName: 'URA Clear',
    packageDealName: '1 Box',
    quantity: 1,
    basePrice: 24500.0,
    upsellAmount: 0.0,
    totalAmount: 24500.0,
    status: 'in_transit',
    paymentType: 'cod',
    paymentStatus: 'pending',
    closerName: 'Maribel Nwalozie',
    deliveryAgentId: 'rider-01',
    deliveryAgentName: 'Test Rider',
    createdAt: DateTime.now(),
  );

  const mockCloser = ClientCloser(
    id: 'cls-102',
    clientId: 'cli-nova-01',
    closerCode: 'CLS-NOVA-102',
    fullName: 'Maribel Nwalozie',
    email: 'maribel@novacare.ng',
    phone: '08107418058',
    isCommissionEnabled: true,
    commissionRate: 500.0,
    dailyCallTarget: 500,
  );

  const mockUser = UserModel(
    id: 'usr-cls-102',
    email: 'maribel@novacare.ng',
    firstName: 'Maribel',
    lastName: 'Nwalozie',
    phone: '08107418058',
    role: 'closer',
    clientId: 'cli-nova-01',
    clientCompanyName: 'Novacare Health & Wellness',
    closerId: 'cls-102',
    closerCode: 'CLS-NOVA-102',
  );

  testWidgets('CloserMobilePortalPage Live In-Transit Monitor does not overflow on 360x750', (tester) async {
    tester.view.physicalSize = const Size(360, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool hasOverflow = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
        hasOverflow = true;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
          clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(mockCloser, sampleOrder)),
          productCatalogProvider.overrideWith((ref) => FakeProductCatalogNotifier()),
        ],
        child: const MaterialApp(
          home: CloserMobilePortalPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(hasOverflow, isFalse, reason: 'Live in-transit order card should not have RenderFlex overflow');
    expect(find.text('Novacare Ltd-CRM-ORD-10-021340'), findsWidgets);
    expect(find.text('IN TRANSIT'), findsWidgets);
    expect(find.text('₦24,500'), findsWidgets);
  });

  testWidgets('Standalone OrderCard does not overflow on 360x750', (tester) async {
    tester.view.physicalSize = const Size(360, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool hasOverflow = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
        hasOverflow = true;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OrderCard(order: sampleOrder),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(hasOverflow, isFalse, reason: 'OrderCard should not have RenderFlex overflow');
  });
}
