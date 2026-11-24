import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/core/theme/app_theme.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/datasources/open_registration_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/domain/entities/registration_lookups.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/pages/login_page.dart';
import 'package:novexps/features/auth/presentation/pages/registration_page.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Open Multi-Role Registration & Dynamic Step Wizard Suite', () {
    test('1. Route guard permits unauthenticated /register & routes signed-up roles home', () {
      // Unauthenticated user on /register stays on /register
      final unauthRegister = appRouteRedirect(
        authState: const AuthState(user: null, isInitialized: true),
        matchedLocation: '/register',
        hasSupabaseSession: false,
      );
      expect(unauthRegister, isNull);

      final roleCases = <({String role, String expectedRoute})>[
        (role: 'closer', expectedRoute: '/closer'),
        (role: 'sales_supervisor', expectedRoute: '/sales-supervisor'),
        (role: 'marketer', expectedRoute: '/marketer'),
        (role: 'marketing_supervisor', expectedRoute: '/marketer'),
        (role: 'merchant_accountant', expectedRoute: '/merchant-settlements'),
        (role: 'client', expectedRoute: '/client'),
        (role: 'dc_operations', expectedRoute: '/ops'),
        (role: 'dc_stock_admin', expectedRoute: '/stock-ops'),
        (role: 'dc_finance_admin', expectedRoute: '/finance-ops'),
        (role: 'dc_manager', expectedRoute: '/dc'),
        (role: 'general_accountant', expectedRoute: '/accountant'),
        (role: 'delivery_agent', expectedRoute: '/'),
      ];

      for (final c in roleCases) {
        final u = UserModel(
          id: 'u-${c.role}',
          email: '${c.role}@novaxpress.ng',
          firstName: 'Test',
          lastName: 'User',
          phone: '08030000001',
          role: c.role,
          isSupervisor: c.role.contains('supervisor'),
        );
        expect(u.homeConsoleRoute, c.expectedRoute, reason: 'Role ${c.role}');
        final redirect = appRouteRedirect(
          authState: AuthState(user: u, isInitialized: true),
          matchedLocation: '/register',
        );
        expect(redirect, c.expectedRoute, reason: 'Redirect for ${c.role}');
      }
    });

    testWidgets(
      '2. Selecting different account types dynamically regenerates exact required steps & fields',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockRegDs = MockOpenRegistrationDataSource();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRemoteDataSourceProvider
                  .overrideWithValue(MockAuthRemoteDataSource()),
              openRegistrationDataSourceProvider.overrideWithValue(mockRegDs),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const RegistrationPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default closer -> 4 steps
        expect(find.textContaining('Step 1 of 4'), findsOneWidget);
        expect(find.text('2. Merchant & Team'), findsAtLeastNWidgets(1));
        expect(find.text('4. Bank & Review'), findsAtLeastNWidgets(1));

        // Advance to Step 2 for Closer -> requires Partner Merchant & Call Target
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Partner Merchant *'), findsOneWidget);
        expect(
          find.text('Daily Confirmed Orders / Call Target *'),
          findsOneWidget,
        );

        // Trying to advance without selecting Merchant is blocked by validation
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Please select your Partner Merchant'), findsOneWidget);

        // Go back to Step 1 and switch to Digital Marketer
        await tester.ensureVisible(find.byKey(const Key('reg_back_btn')));
        await tester.tap(find.byKey(const Key('reg_back_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('reg_role_marketer')));
        await tester.tap(find.byKey(const Key('reg_role_marketer')));
        await tester.pumpAndSettle();
        expect(find.text('2. Merchant & Ads'), findsAtLeastNWidgets(1));

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Daily Ad Spend Budget (₦) *'), findsOneWidget);

        // Back to Step 1 and switch to DC Dispatch & Orders Officer (3 steps)
        await tester.ensureVisible(find.byKey(const Key('reg_back_btn')));
        await tester.tap(find.byKey(const Key('reg_back_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('reg_role_dc_operations')),
        );
        await tester.tap(find.byKey(const Key('reg_role_dc_operations')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Step 1 of 3'), findsOneWidget);
        expect(find.text('2. Distribution Center'), findsAtLeastNWidgets(1));
        expect(find.text('3. Profile & Review'), findsAtLeastNWidgets(1));

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Assigned Distribution Center *'), findsOneWidget);
        expect(find.text('Partner Merchant *'), findsNothing);

        // Back to Step 1 and switch to E-Commerce Merchant (4 steps, brand profile)
        await tester.ensureVisible(find.byKey(const Key('reg_back_btn')));
        await tester.tap(find.byKey(const Key('reg_back_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('reg_role_client')));
        await tester.tap(find.byKey(const Key('reg_role_client')));
        await tester.pumpAndSettle();
        expect(find.text('2. Brand & Address'), findsAtLeastNWidgets(1));

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Company / Store Brand Name *'), findsOneWidget);

        // Back to Step 1 and switch to Field Delivery Agent (4 steps, DC + Fleet/Vehicle)
        await tester.ensureVisible(find.byKey(const Key('reg_back_btn')));
        await tester.tap(find.byKey(const Key('reg_back_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('reg_role_delivery_agent')),
        );
        await tester.tap(find.byKey(const Key('reg_role_delivery_agent')));
        await tester.pumpAndSettle();
        expect(find.text('2. DC & Vehicle'), findsAtLeastNWidgets(1));
        expect(find.text('4. Pay, Bank & Review'), findsAtLeastNWidgets(1));

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Home Distribution Center *'), findsOneWidget);
        expect(
          find.text('Vehicle Registration / Plate Number *'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '3. Complete Closer registration via wizard UI links Partner Merchant & authenticates',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockRegDs = MockOpenRegistrationDataSource();
        UserEntity? capturedUser;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRemoteDataSourceProvider
                  .overrideWithValue(MockAuthRemoteDataSource()),
              openRegistrationDataSourceProvider.overrideWithValue(mockRegDs),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: RegistrationPage(
                    initialRole: RegistrationAccountType.closer,
                    onRegistrationSuccess: (u) => capturedUser = u,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> Step 2
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        // Open Merchant Dropdown & pick NOVACARE LIMITED
        final merchantDd = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(merchantDd);
        await tester.tap(merchantDd);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('NOVACARE LIMITED').last);
        await tester.pumpAndSettle();

        // Verify Supervisor dropdown loaded for NOVACARE LIMITED
        expect(find.text('Reporting Supervisor (Optional)'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('reg_daily_call_target')),
        );
        await tester.enterText(
          find.byKey(const Key('reg_daily_call_target')),
          '65',
        );

        // Step 2 -> Step 3
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('reg_first_name')), 'Chidi');
        await tester.enterText(find.byKey(const Key('reg_last_name')), 'Okonkwo');
        await tester.enterText(
          find.byKey(const Key('reg_email')),
          'chidi.closer@novaxpress.ng',
        );
        await tester.enterText(
          find.byKey(const Key('reg_phone')),
          '08055112233',
        );
        await tester.enterText(
          find.byKey(const Key('reg_password')),
          'CloserPass2026!',
        );
        await tester.enterText(
          find.byKey(const Key('reg_confirm_password')),
          'CloserPass2026!',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Step 3 -> Step 4
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Account Provisioning Summary'), findsOneWidget);
        expect(find.text('NOVACARE LIMITED'), findsWidgets);

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        expect(capturedUser, isNotNull);
        expect(capturedUser!.role, 'closer');
        expect(capturedUser!.clientId, '00000000-0000-4000-8000-791731264594');
        expect(capturedUser!.clientCompanyName, 'NOVACARE LIMITED');
        expect(capturedUser!.homeConsoleRoute, '/closer');

        final authState = container.read(authProvider);
        expect(authState.isAuthenticated, isTrue);
        expect(authState.user?.email, 'chidi.closer@novaxpress.ng');
      },
    );

    testWidgets(
      '4. Complete DC Dispatch Ops & Rider registrations assign DC hub + vehicle + bank',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockRegDs = MockOpenRegistrationDataSource();
        UserEntity? capturedDcOps;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRemoteDataSourceProvider
                  .overrideWithValue(MockAuthRemoteDataSource()),
              openRegistrationDataSourceProvider.overrideWithValue(mockRegDs),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: RegistrationPage(
                initialRole: RegistrationAccountType.dcOperations,
                onRegistrationSuccess: (u) => capturedDcOps = u,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> Step 2 (DC & Dispatch Sector)
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        final dcDd = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(dcDd);
        await tester.tap(dcDd);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Lagos Mainland Regional Hub').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Inbound Dispatch Desk'));
        await tester.tap(find.text('Inbound Dispatch Desk'));
        await tester.pumpAndSettle();

        // Step 2 -> Step 3 (Credentials & Final Review for 3-step DC Ops)
        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('reg_first_name')), 'Tunde');
        await tester.enterText(find.byKey(const Key('reg_last_name')), 'Bakare');
        await tester.enterText(
          find.byKey(const Key('reg_email')),
          'tunde.ops@novaxpress.ng',
        );
        await tester.enterText(
          find.byKey(const Key('reg_phone')),
          '08066112233',
        );
        await tester.enterText(
          find.byKey(const Key('reg_password')),
          'OpsPass2026!',
        );
        await tester.enterText(
          find.byKey(const Key('reg_confirm_password')),
          'OpsPass2026!',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Account Provisioning Summary'), findsOneWidget);
        expect(find.text('Create Account & Launch Console'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('reg_next_or_submit_btn')),
        );
        await tester.tap(find.byKey(const Key('reg_next_or_submit_btn')));
        await tester.pumpAndSettle();

        expect(capturedDcOps, isNotNull);
        expect(capturedDcOps!.role, 'dc_operations');
        expect(
          capturedDcOps!.distributionCenterId,
          '33333333-3333-4333-8333-333333333333',
        );
        expect(capturedDcOps!.homeConsoleRoute, '/ops');

        // Now test Delivery Agent registration directly via AuthNotifier
        final riderContainer = ProviderContainer(
          overrides: [
            authRemoteDataSourceProvider
                .overrideWithValue(MockAuthRemoteDataSource()),
            openRegistrationDataSourceProvider.overrideWithValue(mockRegDs),
          ],
        );
        addTearDown(riderContainer.dispose);

        final riderUser =
            await riderContainer.read(authProvider.notifier).completeOpenRegistration(
          const OpenRegistrationRequest(
            accountType: RegistrationAccountType.deliveryAgent,
            firstName: 'Musa',
            lastName: 'Abdullahi',
            email: 'musa.rider.new@novaxpress.ng',
            phone: '08077889900',
            password: 'RiderPass2026!',
            distributionCenterId: '33333333-3333-4333-8333-333333333333',
            distributionCenterName: 'Lagos Mainland Regional Hub',
            assignedZone: 'Ikeja (GRA / Allen / Alausa)',
            personnelType: 'pda',
            compensationType: 'commission',
            vehicleType: 'Motorcycle (Bajaj Boxer)',
            vehiclePlateNumber: 'LAG-901-QA',
            bankName: 'Access Bank',
            bankAccountNumber: '0123456789',
            bankAccountName: 'Musa Abdullahi',
          ),
        );

        expect(riderUser.role, 'delivery_agent');
        expect(riderUser.isRider, isTrue);
        expect(riderUser.homeConsoleRoute, '/');
        expect(riderUser.vehiclePlateNumber, 'LAG-901-QA');
        expect(riderUser.bankAccountNumber, '0123456789');
        expect(
          riderContainer.read(authProvider).isAuthenticated,
          isTrue,
        );
      },
    );

    testWidgets(
      '5. Mobile (390x844) Dark Mode renders Registration & Login Create Account CTA without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> errors = [];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          prevOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = prevOnError);

        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (_, __) => const LoginPage(),
            ),
            GoRoute(
              path: '/register',
              builder: (_, __) => const RegistrationPage(),
            ),
            GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const Scaffold(body: Text('Forgot')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRemoteDataSourceProvider
                  .overrideWithValue(MockAuthRemoteDataSource()),
              openRegistrationDataSourceProvider
                  .overrideWithValue(MockOpenRegistrationDataSource()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Login provides Dev Pilot Selector & Create Account CTA
        expect(find.text('DEV PILOT LOGIN'), findsOneWidget);
        final createBtn = find.byKey(const Key('login_create_account_btn'));
        expect(createBtn, findsOneWidget);

        await tester.ensureVisible(createBtn);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        expect(find.text('NovaXpress Onboarding'), findsOneWidget);
        expect(find.byKey(const Key('reg_role_closer')), findsOneWidget);
        final riderCard = find.byKey(const Key('reg_role_delivery_agent'));
        await tester.ensureVisible(riderCard);
        expect(riderCard, findsOneWidget);
        await tester.tap(riderCard);
        await tester.pumpAndSettle();

        final nextBtn = find.byKey(const Key('reg_next_or_submit_btn'));
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
        expect(find.text('Home Distribution Center *'), findsOneWidget);

        final overflowErrors = errors
            .where((e) => e.exceptionAsString().contains('RenderFlex'))
            .toList();
        expect(overflowErrors, isEmpty, reason: 'No RenderFlex overflow at 390px');
      },
    );

    test('6. Duplicate email & New Merchant self-registration update lookup registry', () async {
      final mockRegDs = MockOpenRegistrationDataSource();
      final container = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider
              .overrideWithValue(MockAuthRemoteDataSource()),
          openRegistrationDataSourceProvider.overrideWithValue(mockRegDs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Register a new merchant brand
      final newMerchant = await notifier.completeOpenRegistration(
        const OpenRegistrationRequest(
          accountType: RegistrationAccountType.client,
          firstName: 'Zainab',
          lastName: 'Bello',
          email: 'zainab@emeraldherbals.ng',
          phone: '08091234567',
          password: 'MerchantPass2026!',
          companyName: 'Emerald Herbals Ltd',
          merchantTier: 'enterprise',
          stateName: 'Lagos',
          city: 'Ikeja (GRA / Allen / Alausa)',
          address: '10 Toyin Street, Ikeja, Lagos',
          bankName: 'Zenith Bank',
          bankAccountNumber: '1012345678',
          bankAccountName: 'Emerald Herbals Ltd',
        ),
      );

      expect(newMerchant.role, 'client');
      expect(newMerchant.clientCompanyName, 'Emerald Herbals Ltd');
      expect(newMerchant.homeConsoleRoute, '/client');

      // Newly registered merchant now appears in partner merchant lookup
      final merchants = await notifier.fetchRegistrationMerchants();
      expect(
        merchants.any((m) => m.name == 'Emerald Herbals Ltd'),
        isTrue,
      );

      // Duplicate email registration must throw clearly
      await expectLater(
        notifier.completeOpenRegistration(
          const OpenRegistrationRequest(
            accountType: RegistrationAccountType.closer,
            firstName: 'Other',
            lastName: 'User',
            email: 'zainab@emeraldherbals.ng',
            phone: '08099998888',
            password: 'Password123!',
            clientId: '00000000-0000-4000-8000-791731264594',
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('already registered'))),
      );
    });
  });
}

