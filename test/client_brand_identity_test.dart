import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
import 'package:novexps/features/client_portal/presentation/pages/closer_mobile_portal_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_onboard_client_modal.dart';

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
  FakeClientPortalNotifier(ClientPortalState initialState) : super(initialState);

  @override
  Future<void> loadClientData() async {}

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const customPurple = Color(0xFF7C3AED);
  const customAmber = Color(0xFFF59E0B);
  const customCyan = Color(0xFF06B6D4);

  final brandedProfile = const ClientProfile(
    id: 'cli-aurora',
    companyName: 'Aurora Wellness Labs',
    contactPerson: 'Dr. Jane Doe',
    email: 'hello@aurorawellness.ng',
    phone: '08091122334',
    address: 'Victoria Island, Lagos',
    logoUrl: 'https://cdn.aurorawellness.ng/logo.png',
    primaryColor: '#7C3AED',
    secondaryColor: '#F59E0B',
    accentColor: '#06B6D4',
    brandTheme: {
      'mode': 'light',
      'button_radius': 10,
    },
    servicesEnabled: ['fulfillment', 'delivery', 'inventory_management'],
    hasInventoryManagement: true,
  );

  const testUser = UserModel(
    id: 'user-aurora',
    email: 'hello@aurorawellness.ng',
    firstName: 'Aurora',
    lastName: 'Merchant',
    phone: '08091122334',
    role: 'client',
    clientId: 'cli-aurora',
    clientCompanyName: 'Aurora Wellness Labs',
  );

  const testCloserUser = UserModel(
    id: 'user-closer-1',
    email: 'closer@aurorawellness.ng',
    firstName: 'Amaka',
    lastName: 'Closer',
    phone: '08091122335',
    role: 'closer',
    clientId: 'cli-aurora',
    clientCompanyName: 'Aurora Wellness Labs',
  );

  test('ClientProfile parses brand colors correctly with fallback support', () {
    expect(brandedProfile.brandPrimaryColor.value, customPurple.value);
    expect(brandedProfile.brandSecondaryColor.value, customAmber.value);
    expect(brandedProfile.brandAccentColor.value, customCyan.value);
    expect(brandedProfile.logoUrl, 'https://cdn.aurorawellness.ng/logo.png');

    // Test fallback parsing
    const defaultProfile = ClientProfile(
      id: 'cli-default',
      companyName: 'Default Merchant',
      contactPerson: 'Admin',
      email: 'test@merchant.ng',
      phone: '08000000000',
      address: 'Lagos',
    );
    expect(defaultProfile.brandPrimaryColor, const Color(0xFF0D9488)); // Emerald default
    expect(defaultProfile.brandSecondaryColor, const Color(0xFF1E293B)); // Slate default
    expect(defaultProfile.brandAccentColor, const Color(0xFFF59E0B)); // Amber default
  });

  testWidgets('ClientPortalLayout dynamically applies brand identity and colors', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final portalState = ClientPortalState(
      isLoading: false,
      clientProfile: brandedProfile,
      orders: const [],
      products: const [],
      leads: const [],
      stockBalances: const [],
      stockInvoices: const [],
      suppliers: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(portalState)),
        ],
        child: const MaterialApp(
          home: ClientPortalLayout(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify company name in sidebar header
    expect(find.text('Aurora Wellness Labs'), findsWidgets);
    expect(find.text('Merchant Operations Hub'), findsOneWidget);
  });

  testWidgets('CloserMobilePortalPage displays brand pill and company header', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final portalState = ClientPortalState(
      isLoading: false,
      clientProfile: brandedProfile,
      orders: const [],
      products: const [],
      leads: const [],
      stockBalances: const [],
      stockInvoices: const [],
      suppliers: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testCloserUser)),
          clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(portalState)),
        ],
        child: const MaterialApp(
          home: CloserMobilePortalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Closer console displays the company name
    expect(find.text('Aurora Wellness Labs'), findsWidgets);
  });

  testWidgets('DCOnboardClientModal renders Step 1 Brand Identity & Color Palettes', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DCOnboardClientModal.show(ctx),
                child: const Text('Open Onboard Modal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Onboard Modal'));
    await tester.pumpAndSettle();

    // Verify Step 1 Brand Identity section headers
    expect(find.text('Merchant Brand Identity & Dynamic Theming'), findsOneWidget);

    // Scroll until presets are visible
    final presetFinder = find.text('Imperial Violet');
    await tester.scrollUntilVisible(
      presetFinder,
      100,
      scrollable: find.descendant(of: find.byType(DCOnboardClientModal), matching: find.byType(Scrollable)).first,
    );
    expect(presetFinder, findsOneWidget);
    expect(find.text('Novacare Emerald'), findsOneWidget);

    // Tap Imperial Violet palette preset
    await tester.tap(presetFinder);
    await tester.pumpAndSettle();

    // Verify custom color hex inputs reflect selected palette
    expect(find.text('#7C3AED'), findsWidgets);
  });
}
