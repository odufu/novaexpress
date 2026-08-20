import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_riders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_onboard_rider_modal.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('PDA & Rider Onboarding and Unique Agreement Verification Suite', () {
    testWidgets('1. DCOnboardRiderModal renders with Login & Security step and generates onboarding slip', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRemoteDataSourceProvider.overrideWithValue(_MockAuthRemoteDSWithRegister()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCOnboardRiderModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Onboard Delivery Agent / Rider'), findsOneWidget);
      // Advance to Step 2: Login & Security
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Agent Login Account & Mobile Credentials'), findsOneWidget);
      expect(find.text('Rider Login Email Address'), findsOneWidget);
      expect(find.text('Temporary Password'), findsOneWidget);
      expect(find.text('Require Password Change on First Login'), findsOneWidget);

      // Advance to Step 3: Vehicle & Asset
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Vehicle Details (PDA)'), findsOneWidget);

      // Advance to Step 4: Agreement
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Unique Compensation & Transport Agreement (BR-010 to BR-015)'), findsOneWidget);
      expect(find.text('Per-Delivery Entitlement Calculation'), findsOneWidget);
      expect(find.text('Base Commission (₦ per drop)'), findsOneWidget);
      expect(find.text('Transport / Fuel Allowance (₦ per drop)'), findsOneWidget);

      // Advance to Step 5: Payout Bank
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Rider Payout Bank Account Details (for "My Balance" Withdrawals)'), findsOneWidget);
      expect(find.text('Issue Credentials & Activate'), findsOneWidget);

      // Complete Onboarding
      await tester.tap(find.text('Issue Credentials & Activate'));
      await tester.pumpAndSettle();

      // Verify Credentials & Agreement Slip Card is shown
      expect(find.text('Rider Onboarded Successfully!'), findsOneWidget);
      expect(find.text('Agent Identification:'), findsOneWidget);
      expect(find.text('Copy Credentials'), findsOneWidget);
      expect(find.text('Save & Close'), findsOneWidget);
    });

    testWidgets('2. DCRidersPage displays PDA and In-House Fleet summary metrics and roster', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) {
              final notifier = DCConsoleNotifier();
              notifier.state = notifier.state.copyWith(
                drivers: const [
                  DCFleetDriver(
                    id: 'pda-1',
                    driverCode: 'PDA-7000',
                    name: 'Emeka Rider',
                    phone: '08012345678',
                    avatarUrl: '',
                    vehicleModel: 'Bajaj Boxer',
                    vehiclePlate: 'ABJ-204-XY',
                    vehicleType: 'Motorcycle',
                    status: 'active',
                    assignedZone: 'Wuse II & Abuja Central',
                    totalAssignedOrders: 53,
                    completedOrders: 51,
                    routeProgressPercent: 96.0,
                    efficiencyRating: 99.2,
                    cashInCustody: 953000.0,
                    itemsInCustody: 22,
                    personnelType: 'pda',
                    compensationType: 'commission',
                  ),
                  DCFleetDriver(
                    id: 'inhouse-1',
                    driverCode: 'RDR-102',
                    name: 'Babatunde Lawal',
                    phone: '08034567890',
                    avatarUrl: '',
                    vehicleModel: 'Haojue 125',
                    vehiclePlate: 'ABJ-894-XA',
                    vehicleType: 'Motorcycle',
                    status: 'active',
                    assignedZone: 'Garki I & II',
                    totalAssignedOrders: 15,
                    completedOrders: 15,
                    routeProgressPercent: 100.0,
                    efficiencyRating: 94.1,
                    cashInCustody: 45000.0,
                    itemsInCustody: 8,
                    personnelType: 'in_house_rider',
                    compensationType: 'salary',
                  ),
                ],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRidersPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riders & Delivery Fleet Control'), findsOneWidget);
      expect(find.text('Onboard Delivery Agent'), findsOneWidget);
      expect(find.text('PDA Agents (Personal Transport)'), findsOneWidget);
      expect(find.text('In-House Fleet Riders'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsOneWidget);
      expect(find.text('Babatunde Lawal'), findsOneWidget);
    });

    test('3. Verifies that unique compensation agreements accurately calculate total entitlement per delivery', () {
      const pdaDriver = DCFleetDriver(
        id: 'pda-1',
        driverCode: 'PDA-7000',
        name: 'Emeka Rider',
        phone: '08012345678',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'ABJ-204-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse II',
        totalAssignedOrders: 10,
        completedOrders: 10,
        routeProgressPercent: 100.0,
        efficiencyRating: 99.0,
        cashInCustody: 0.0,
        itemsInCustody: 0,
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
        failedDeliveryAllowance: 500.0,
      );

      const inHouseRider = DCFleetDriver(
        id: 'rdr-1',
        driverCode: 'RDR-102',
        name: 'Babatunde Lawal',
        phone: '08034567890',
        avatarUrl: '',
        vehicleModel: 'Haojue 125',
        vehiclePlate: 'ABJ-894-XA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Garki',
        totalAssignedOrders: 10,
        completedOrders: 10,
        routeProgressPercent: 100.0,
        efficiencyRating: 95.0,
        cashInCustody: 0.0,
        itemsInCustody: 0,
        personnelType: 'in_house_rider',
        compensationType: 'salary',
        baseSalary: 120000.0,
        commissionRate: 500.0,
        transportAllowance: 800.0,
        failedDeliveryAllowance: 300.0,
      );

      // Verify PDA entitlement: ₦1,000 + ₦1,500 = ₦2,500
      expect(pdaDriver.isPda, isTrue);
      expect(pdaDriver.isInHouseRider, isFalse);
      expect(pdaDriver.totalPerDeliveryEntitlement, equals(2500.0));

      // Verify In-House Rider entitlement: ₦500 + ₦800 = ₦1,300
      expect(inHouseRider.isInHouseRider, isTrue);
      expect(inHouseRider.isPda, isFalse);
      expect(inHouseRider.totalPerDeliveryEntitlement, equals(1300.0));
      expect(inHouseRider.baseSalary, equals(120000.0));
    });

    test('4. Newly registered rider account can immediately log in with issued credentials', () async {
      final mockAuthDS = _MockAuthRemoteDSWithRegister();

      // 1. Register new PDA rider
      final registeredUser = await mockAuthDS.registerDeliveryAgent(
        email: 'chinedu.pda@novaexpress.ng',
        password: 'Password123!',
        firstName: 'Chinedu',
        lastName: 'Okafor',
        phone: '08098765432',
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1200.0,
        transportAllowance: 1500.0,
        fuelAllowance: 0.0,
        baseSalary: 0.0,
        vehicleType: 'Motorcycle',
        vehiclePlateNumber: 'ABJ-382-KU',
        bankName: 'GTBank',
        bankAccountNumber: '0123456789',
        bankAccountName: 'Chinedu Logistics Ent.',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        assignedZone: 'Wuse II',
      );

      expect(registeredUser.email, equals('chinedu.pda@novaexpress.ng'));
      expect(registeredUser.role, equals('delivery_agent'));
      expect(registeredUser.commissionRate, equals(1200.0));
      expect(registeredUser.transportAllowance, equals(1500.0));

      // 2. Perform Login with the exact email and password
      final loggedInUser = await mockAuthDS.login('chinedu.pda@novaexpress.ng', 'Password123!');

      expect(loggedInUser.email, equals('chinedu.pda@novaexpress.ng'));
      expect(loggedInUser.role, equals('delivery_agent'));
      expect(loggedInUser.isPda, isTrue);
      expect(loggedInUser.isDcManager, isFalse);
      expect(loggedInUser.deliveryAgentCode, isNotEmpty);
      expect(loggedInUser.commissionRate, equals(1200.0));
      expect(loggedInUser.transportAllowance, equals(1500.0));
      expect(loggedInUser.bankName, equals('GTBank'));
    });
  });
}

class _MockAuthRemoteDSWithRegister implements AuthRemoteDataSource {
  final Map<String, UserModel> _users = {};
  final Map<String, String> _passwords = {};

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
    required String assignedZone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final isPda = personnelType.toLowerCase() == 'pda';
    final user = UserModel(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'delivery_agent',
      deliveryAgentId: 'a-${DateTime.now().millisecondsSinceEpoch}',
      deliveryAgentCode: isPda ? 'PDA-7890' : 'RDR-201',
      distributionCenterId: distributionCenterId,
      distributionCenterName: 'Wuse Distribution Center',
      personnelType: personnelType,
      compensationType: compensationType,
      commissionRate: commissionRate,
      transportAllowance: transportAllowance,
      fuelAllowance: fuelAllowance,
      baseSalary: baseSalary,
      vehicleType: vehicleType,
      vehiclePlateNumber: vehiclePlateNumber,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
    _users[cleanEmail] = user;
    _passwords[cleanEmail] = password;
    return user;
  }

  @override
  Future<UserModel> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_users.containsKey(cleanEmail) && _passwords[cleanEmail] == password) {
      return _users[cleanEmail]!;
    }
    throw Exception('Invalid credentials');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
