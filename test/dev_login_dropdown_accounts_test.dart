import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/theme/app_theme.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/presentation/pages/login_page.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Dev Pilot Fast-Login Dropdown & Comprehensive Multi-Account Suite', () {
    test('1. Pre-seeded development accounts cover all 21 operational roles', () {
      AuthRemoteDataSourceImpl.seedDefaultDevelopmentAccounts();

      final requiredEmails = [
        'emeraldcodelines@gmail.com', // Super Admin
        'admin@novaxpress.ng', // Platform Admin
        'logistics.admin@novaxpress.ng', // Logistics Admin
        'joelaccount@gmail.com', // General Accountant
        'dc.supervisor@novaxpress.ng', // DC Manager
        'abigail.kooyon@novaxpress.net', // Dispatch Ops
        'joelstock@novaxpress.ng', // DC Stock Keeper
        'joelfinance@gmail.com', // DC Finance
        'gig.operations@novaxpress.ng', // 3PL GIG Partner
        'speedaf.operations@novaxpress.ng', // 3PL Speedaf Partner
        'novacare@novaxpress.net', // Novacare Merchant
        'shop11@novaxpress.net', // Shop11 Merchant
        'accountant@novacare.com', // Merchant Accountant
        'joelsupervisor@novaxpress.ng', // Sales Supervisor
        'prestige.godwin@novaxpress.net', // Head Closer
        'ojo.modupeolami@novaxpress.ng', // Closer
        'adewole.ibukun@novaxpress.ng', // Closer
        'chioma.marketing@novaxpress.ng', // Marketer
        'oladele.omowaye@novaxpress.ng', // Courier
        'simon.tazha@novaxpress.ng', // Courier
        'uche.okafor@novaxpress.ng', // Courier
      ];

      for (final email in requiredEmails) {
        final hasUser = AuthRemoteDataSourceImpl.hasEmailInMemory(email);
        expect(hasUser, isTrue, reason: 'Expected $email to be registered in memory');
      }
    });

    test('2. Every pre-seeded account authenticates and returns correct designated route', () async {
      final mockDataSource = MockAuthRemoteDataSource();

      // Test a key representative of each tier
      final testCases = [
        ('emeraldcodelines@gmail.com', '@EmeraldXpress2026', '/admin'),
        ('admin@novaxpress.ng', 'AdminPass123!', '/admin'),
        ('logistics.admin@novaxpress.ng', 'LogisticsAdmin123!', '/logistics-admin'),
        ('joelaccount@gmail.com', 'joelaccount@gmail.com', '/accountant'),
        ('dc.supervisor@novaxpress.ng', 'Password123!', '/dc'),
        ('abigail.kooyon@novaxpress.net', 'CDV8pRxC#b', '/ops'),
        ('joelstock@novaxpress.ng', 'joelstock@novaxpress.ng', '/stock-ops'),
        ('joelfinance@gmail.com', 'joelfinance@gmail.com', '/finance-ops'),
        ('gig.operations@novaxpress.ng', 'Password123!', '/logistics-partner'),
        ('novacare@novaxpress.net', 'novacare@novaxpress.net', '/client'),
        ('accountant@novacare.com', 'Password123!', '/merchant-settlements'),
        ('joelsupervisor@novaxpress.ng', 'joelsupervisor@novaxpress.ng', '/sales-supervisor'),
        ('prestige.godwin@novaxpress.net', 'Closer123!', '/closer'),
        ('chioma.marketing@novaxpress.ng', 'Marketing123!', '/marketer'),
        ('simon.tazha@novaxpress.ng', 'SimonPass123!', '/'),
      ];

      for (final (email, pass, expectedRoute) in testCases) {
        final user = await mockDataSource.login(email, pass);
        expect(user.email.toLowerCase(), equals(email.toLowerCase()));
        expect(user.homeConsoleRoute, equals(expectedRoute),
            reason: 'User $email with role ${user.role} expected route $expectedRoute');
      }
    });

    testWidgets('3. Production build cleanly hides Dev Pilot selector and presents standard sign-in',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(MockAuthRemoteDataSource()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dev Pilot Banner is completely hidden for production deployment
      expect(find.text('DEV PILOT LOGIN'), findsNothing);
      expect(find.text('Test Role Selector'), findsNothing);

      // Verify standard enterprise inputs and button are ready
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email/Staff Code and Password
      expect(find.text('Sign In to Assigned Workspace'), findsOneWidget);
    });
  });
}

