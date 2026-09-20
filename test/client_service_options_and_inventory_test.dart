import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
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
  FakeClientPortalNotifier(ClientProfile profile)
      : super(ClientPortalState(
          isLoading: false,
          clientProfile: profile,
          orders: const [],
          products: const [],
          leads: const [],
        ));

  @override
  Future<void> loadClientData() async {}

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Client Profile & Service Options', () {
    test('ClientProfile correctly reflects hasInventoryManagement and servicesEnabled', () {
      const standardClient = ClientProfile(
        id: 'client-001',
        companyName: 'Standard Brand Ltd',
        contactPerson: 'Jane Doe',
        email: 'jane@standard.com',
        phone: '08011223344',
        address: 'Ikeja, Lagos',
        hasInventoryManagement: false,
        servicesEnabled: ['fulfillment', 'delivery'],
      );

      expect(standardClient.hasInventoryManagement, isFalse);
      expect(standardClient.servicesEnabled, contains('fulfillment'));
      expect(standardClient.servicesEnabled, contains('delivery'));
      expect(standardClient.servicesEnabled.contains('inventory_management'), isFalse);

      final upgradedClient = standardClient.copyWith(
        hasInventoryManagement: true,
        servicesEnabled: ['fulfillment', 'delivery', 'inventory_management'],
      );

      expect(upgradedClient.hasInventoryManagement, isTrue);
      expect(upgradedClient.servicesEnabled, contains('inventory_management'));

      // JSON serialization check
      final json = upgradedClient.toJson();
      expect(json['has_inventory_management'], isTrue);
      final restored = ClientProfile.fromJson(json);
      expect(restored.hasInventoryManagement, isTrue);
      expect(restored.servicesEnabled, contains('inventory_management'));
    });
  });

  group('DC Onboard Client Modal - Service Options Toggle', () {
    testWidgets('Renders Inventory Management toggle in Step 3 of Onboard Client Modal', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCOnboardClientModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Step indicators and form fields
      expect(find.text('Onboard Client Account'), findsOneWidget);
      expect(find.text('Company & Depot'), findsOneWidget);

      final inputsStep0 = find.byType(TextFormField);
      // Input 0: Company Name
      await tester.enterText(inputsStep0.at(0), 'Test Agro Labs');
      // Input 1: Client Code
      await tester.enterText(inputsStep0.at(1), 'CLI-TAL-101');
      // Input 2: City
      await tester.enterText(inputsStep0.at(2), 'Abuja Municipal');
      // Input 3: Address
      await tester.enterText(inputsStep0.at(3), 'Plot 12 Central Business District');
      await tester.pumpAndSettle();

      // Click Next Step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      final inputsStep1 = find.byType(TextFormField);
      // Input 0: Contact person
      await tester.enterText(inputsStep1.at(0), 'Musa Danjuma');
      // Input 1: Phone
      await tester.enterText(inputsStep1.at(1), '08023456781');
      // Input 2: Email
      await tester.enterText(inputsStep1.at(2), 'musa@testagrolabs.ng');
      await tester.pumpAndSettle();

      // Click Next Step to reach Step 2 (Tier & Payouts)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify toggle title is displayed
      expect(find.text('Inventory & Landed Cost Supply Chain'), findsOneWidget);
    });
  });

  group('Client Portal Navigation Layout', () {
    testWidgets('ClientPortalLayout displays Inventory & Landed Cost tab when hasInventoryManagement is true', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const clientUser = UserModel(
        id: 'user-novacare-01',
        email: 'admin@novacare.ng',
        firstName: 'Novacare',
        lastName: 'Admin',
        phone: '08099887766',
        role: 'client',
        clientId: 'cli-novacare',
        clientCompanyName: 'Novacare Ltd',
      );

      const profile = ClientProfile(
        id: 'cli-novacare',
        companyName: 'Novacare Ltd',
        contactPerson: 'Director',
        email: 'admin@novacare.ng',
        phone: '08099887766',
        address: 'Central Stores, Abuja',
        isEnterprise: true,
        hasInventoryManagement: true,
        servicesEnabled: ['fulfillment', 'delivery', 'inventory_management'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(clientUser)),
            clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(profile)),
          ],
          child: const MaterialApp(
            home: ClientPortalLayout(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find the 'Inventory & Landed Cost' navigation item
      expect(find.text('Inventory & Landed Cost'), findsWidgets);
    });

    testWidgets('ClientPortalLayout omits Inventory tab when hasInventoryManagement is false', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const clientUser = UserModel(
        id: 'user-regular-01',
        email: 'merchant@regularstore.com',
        firstName: 'Regular',
        lastName: 'Merchant',
        phone: '08011223344',
        role: 'client',
        clientId: 'cli-regular-99',
        clientCompanyName: 'Regular Store',
      );

      const profile = ClientProfile(
        id: 'cli-regular-99',
        companyName: 'Regular Store',
        contactPerson: 'Manager',
        email: 'merchant@regularstore.com',
        phone: '08011223344',
        address: 'Lagos',
        isEnterprise: false,
        hasInventoryManagement: false,
        servicesEnabled: ['fulfillment', 'delivery'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(clientUser)),
            clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(profile)),
          ],
          child: const MaterialApp(
            home: ClientPortalLayout(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT find the 'Inventory & Landed Cost' navigation item
      expect(find.text('Inventory & Landed Cost'), findsNothing);
    });
  });
}
