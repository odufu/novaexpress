import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Scoping & Isolation Tests', () {
    test('Regional DC supervisor has all resources isolated to their DC and zeroed for new DC', () {
      final grandDc = DistributionCenter(
        id: '22222222-2222-4222-8222-222222222222',
        companyId: '11111111-1111-4111-8111-111111111111',
        name: 'Central Command Distribution Center',
        code: 'DC-CMD-01',
        state: 'Federal Capital Territory',
        city: 'Central Command Hub',
        address: 'Plot 100 Command Boulevard',
        isGrandDc: true,
        isHub: true,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final lokojaDc = DistributionCenter(
        id: 'lokoja-uuid-001',
        companyId: '11111111-1111-4111-8111-111111111111',
        name: 'Lokoja DC',
        code: 'DC-LKJ-001',
        state: 'Kogi',
        city: 'Lokoja',
        address: 'Plot 10 Ganaja Junction',
        isGrandDc: false,
        isHub: false,
        isActive: true,
        parentDcId: grandDc.id,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      final centralDriver = DCFleetDriver(
        id: 'drv-central-1',
        driverCode: 'RDR-001',
        name: 'Ahmed Rider',
        phone: '08012345678',
        email: 'ahmed.rider@novaxpress.ng',
        assignedZone: 'Central Area',
        distributionCenterId: grandDc.id,
      );

      var state = DCConsoleState(
        activeHubId: grandDc.id,
        activeHubName: grandDc.name,
        activeHubCode: grandDc.code,
        distributionCenters: [grandDc, lokojaDc],
        drivers: [centralDriver],
      );

      expect(state.isCurrentHubGrandDc, isTrue);

      // Simulate login as Chenemi Samuel (Lokoja DC Manager)
      final chenemi = UserModel(
        id: 'user-chenemi-1',
        email: 'chenemi.samuel@novaxpress.ng',
        firstName: 'Chenemi',
        lastName: 'Samuel',
        phone: '08099998888',
        role: 'dc_manager',
        distributionCenterId: lokojaDc.id,
        distributionCenterName: lokojaDc.name,
      );

      // Sync user to state
      state = state.copyWith(
        activeHubId: lokojaDc.id,
        activeHubName: lokojaDc.name,
        activeHubCode: lokojaDc.code,
        selectedDcId: lokojaDc.id,
      );

      // Verify Lokoja DC is not Grand DC
      expect(state.isCurrentHubGrandDc, isFalse);
      expect(state.activeHubId, equals('lokoja-uuid-001'));
      expect(state.selectedDcId, equals('lokoja-uuid-001'));

      // Verify drivers are strictly scoped: Lokoja has 0 drivers, Central driver is excluded
      expect(state.dcDrivers.length, equals(0));
      expect(state.filteredDrivers.length, equals(0));

      // Verify transactions and payouts are isolated: 0 for Lokoja DC
      expect(state.dcTransactions.length, equals(0));
      expect(state.dcPayoutClaims.length, equals(0));
      expect(state.dcReturnItems.length, equals(0));
    });

    test('Grand DC switching to child DC scopes active hub and selectedDcId', () {
      final grandDc = DistributionCenter(
        id: '22222222-2222-4222-8222-222222222222',
        companyId: '11111111-1111-4111-8111-111111111111',
        name: 'Central Command Distribution Center',
        code: 'DC-CMD-01',
        state: 'Federal Capital Territory',
        city: 'Central Command Hub',
        address: 'Plot 100 Command Boulevard',
        isGrandDc: true,
        isHub: true,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final lokojaDc = DistributionCenter(
        id: 'lokoja-uuid-001',
        companyId: '11111111-1111-4111-8111-111111111111',
        name: 'Lokoja DC',
        code: 'DC-LKJ-001',
        state: 'Kogi',
        city: 'Lokoja',
        address: 'Plot 10 Ganaja Junction',
        isGrandDc: false,
        isHub: false,
        isActive: true,
        parentDcId: grandDc.id,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      var state = DCConsoleState(
        activeHubId: grandDc.id,
        activeHubName: grandDc.name,
        activeHubCode: grandDc.code,
        distributionCenters: [grandDc, lokojaDc],
      );

      expect(state.isCurrentHubGrandDc, isTrue);

      // Switch to Lokoja DC
      state = state.copyWith(
        activeHubId: lokojaDc.id,
        activeHubName: lokojaDc.name,
        activeHubCode: lokojaDc.code,
        selectedDcId: lokojaDc.id,
      );

      expect(state.activeHubId, equals(lokojaDc.id));
      expect(state.selectedDcId, equals(lokojaDc.id));
      expect(state.activeHubName, equals('Lokoja DC'));
      expect(state.isCurrentHubGrandDc, isFalse);
    });
  });
}

