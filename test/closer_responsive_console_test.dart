import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/closer_mobile_portal_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';

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
  FakeClientPortalNotifier(ClientCloser closer)
      : super(ClientPortalState(
          isLoading: false,
          closers: [closer],
          clientProfile: const ClientProfile(
            id: 'cli-nova-01',
            companyName: 'Novacare Health & Wellness',
            contactPerson: 'Alex Okonkwo',
            email: 'alex.closer@novacare.ng',
            phone: '08012345678',
            address: 'Plot 10, Abuja',
            closerLimit: 10,
          ),
          orders: [],
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
  FakeProductCatalogNotifier(List<CatalogProduct> products)
      : super(ProductCatalogState(products: products));

  @override
  Future<void> reloadCatalog() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget buildTestWidget({
    required Size screenSize,
    required UserModel mockUser,
    required ClientCloser mockCloser,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
        clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(mockCloser)),
        productCatalogProvider.overrideWith((ref) => FakeProductCatalogNotifier([])),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            platformBrightness: Brightness.light,
          ),
          child: const CloserMobilePortalPage(),
        ),
      ),
    );
  }

  group('Closer Console Responsive Layout Tests', () {
    const mockUser = UserModel(
      id: 'usr-cls-101',
      email: 'alex.closer@novacare.ng',
      firstName: 'Alex',
      lastName: 'Okonkwo',
      phone: '08012345678',
      role: 'closer',
      clientId: 'cli-nova-01',
      clientCompanyName: 'Novacare Health & Wellness',
      closerId: 'cls-101',
      closerCode: 'CLS-NOVA-101',
      avatarUrl: 'https://example.com/avatar.png',
    );

    const mockCloser = ClientCloser(
      id: 'cls-101',
      clientId: 'cli-nova-01',
      closerCode: 'CLS-NOVA-101',
      fullName: 'Alex Okonkwo',
      email: 'alex.closer@novacare.ng',
      phone: '08012345678',
      dailyCallTarget: 50,
      commissionRate: 1000.0,
      totalOrdersBooked: 24,
      totalOrdersDelivered: 18,
      avatarUrl: 'https://example.com/avatar.png',
    );

    testWidgets('1. Mobile Viewport (< 700px) renders Bottom Navigation Bar and Mobile AppBar', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(400, 800),
          mockUser: mockUser,
          mockCloser: mockCloser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // In mobile view, NavigationBar is present
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Leads'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Desktop sidebar brand title is NOT present on mobile
      expect(find.text('NovaX Telesales'), findsNothing);
      expect(find.text('Closer Desk Console'), findsNothing);
    });

    testWidgets('2. Tablet Viewport (700px - 1100px) activates Side Navigation and Desktop Top Bar', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(800, 1000),
          mockUser: mockUser,
          mockCloser: mockCloser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Mobile bottom bar is NOT present on tablet
      expect(find.byType(NavigationBar), findsNothing);

      // Desktop/tablet sidebar brand and desk console header are present
      expect(find.text('NovaX Telesales'), findsOneWidget);
      expect(find.text('Closer Desk Console'), findsOneWidget);

      // Top App Bar displays section title & desk online status
      expect(find.text('Telesales Dashboard'), findsOneWidget);
      expect(find.text('Desk Online'), findsOneWidget);
    });

    testWidgets('3. Desktop Viewport (>= 1100px) renders full workstation layout with collapsible sidebar', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(1400, 900),
          mockUser: mockUser,
          mockCloser: mockCloser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Desktop view has sidebar and topbar
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('NovaX Telesales'), findsOneWidget);
      expect(find.text('Telesales Dashboard'), findsOneWidget);
      expect(find.text('Desk Online'), findsOneWidget);

      // Quick Action buttons on wide dashboard
      expect(find.text('Book New Order'), findsWidgets);
      expect(find.text('New Package Deal'), findsOneWidget);
      expect(find.text('Dial Leads Desk'), findsOneWidget);

      // KPI card titles
      expect(find.text('Orders Booked'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Gross Closed'), findsOneWidget);
      expect(find.text('Commissions'), findsOneWidget);
      expect(find.text('Daily Call Target'), findsOneWidget);
    });

    testWidgets('4. Desktop sidebar collapses and expands seamlessly', (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(1200, 850),
          mockUser: mockUser,
          mockCloser: mockCloser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially expanded
      expect(find.text('NovaX Telesales'), findsOneWidget);
      final collapseBtn = find.byIcon(Icons.menu_open_rounded);
      expect(collapseBtn, findsOneWidget);

      // Tap collapse
      await tester.tap(collapseBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now collapsed: brand text hidden, expand button visible
      expect(find.text('NovaX Telesales'), findsNothing);
      final expandBtn = find.byIcon(Icons.menu_rounded);
      expect(expandBtn, findsOneWidget);

      // Tap expand
      await tester.tap(expandBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expanded again
      expect(find.text('NovaX Telesales'), findsOneWidget);
    });
  });
}
