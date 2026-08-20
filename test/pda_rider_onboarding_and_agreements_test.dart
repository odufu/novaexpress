import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
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
        const ProviderScope(
          child: MaterialApp(
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
  });
}
