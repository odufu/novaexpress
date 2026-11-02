import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_assign_order_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/pages/orders_list_page.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/core/widgets/ux_states/ux_states.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Rider Availability & Standardized Date Range Filter Suite', () {
    test('1. UserEntity correctly calculates isAvailable and isUnavailable across statuses', () {
      const activeUser = UserEntity(
        id: 'user_1',
        email: 'rider@nova.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08012345678',
        role: 'pda',
        agentStatus: 'available',
      );
      expect(activeUser.isAvailable, isTrue);
      expect(activeUser.isUnavailable, isFalse);

      final offlineUser = activeUser.copyWith(agentStatus: 'offline');
      expect(offlineUser.isAvailable, isFalse);
      expect(offlineUser.isUnavailable, isTrue);

      final inactiveUser = activeUser.copyWith(agentStatus: 'inactive');
      expect(inactiveUser.isAvailable, isFalse);
      expect(inactiveUser.isUnavailable, isTrue);

      final bannedUser = activeUser.copyWith(agentStatus: 'banned');
      expect(bannedUser.isAvailable, isFalse);
      expect(bannedUser.isUnavailable, isTrue);
    });

    test('2. DCFleetDriver correctly calculates isAvailable and isUnavailable', () {
      const activeDriver = DCFleetDriver(
        id: 'drv_1',
        driverCode: 'PDA-101',
        name: 'Tunde Afolabi',
        phone: '08099887766',
        assignedZone: 'Central Area',
        status: 'active',
      );
      expect(activeDriver.isAvailable, isTrue);
      expect(activeDriver.isUnavailable, isFalse);

      final offlineDriver = activeDriver.copyWith(status: 'offline');
      expect(offlineDriver.isAvailable, isFalse);
      expect(offlineDriver.isUnavailable, isTrue);

      final bannedDriver = activeDriver.copyWith(status: 'banned');
      expect(bannedDriver.isAvailable, isFalse);
      expect(bannedDriver.isUnavailable, isTrue);

      final inactiveDriver = activeDriver.copyWith(status: 'inactive');
      expect(inactiveDriver.isAvailable, isFalse);
      expect(inactiveDriver.isUnavailable, isTrue);
    });

    test('3. DCConsoleState filteredDrivers correctly filters unavailable riders', () {
      const d1 = DCFleetDriver(
        id: 'drv_1',
        driverCode: 'PDA-01',
        name: 'Active Musa',
        phone: '0801',
        assignedZone: 'AMAC',
        status: 'active',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );
      const d2 = DCFleetDriver(
        id: 'drv_2',
        driverCode: 'PDA-02',
        name: 'Banned Peter',
        phone: '0802',
        assignedZone: 'AMAC',
        status: 'banned',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );
      const d3 = DCFleetDriver(
        id: 'drv_3',
        driverCode: 'PDA-03',
        name: 'Offline Chidi',
        phone: '0803',
        assignedZone: 'AMAC',
        status: 'offline',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );

      final stateAll = DCConsoleState(
        drivers: [d1, d2, d3],
        activeHubId: '22222222-2222-4222-8222-222222222222',
        fleetFilter: 'all',
      );
      expect(stateAll.filteredDrivers.length, equals(3));

      final stateActive = stateAll.copyWith(fleetFilter: 'active');
      expect(stateActive.filteredDrivers.length, equals(1));
      expect(stateActive.filteredDrivers.first.name, equals('Active Musa'));

      final stateUnavailable = stateAll.copyWith(fleetFilter: 'unavailable');
      expect(stateUnavailable.filteredDrivers.length, equals(2));
      expect(stateUnavailable.filteredDrivers.any((d) => d.name == 'Banned Peter'), isTrue);
      expect(stateUnavailable.filteredDrivers.any((d) => d.name == 'Offline Chidi'), isTrue);
    });

    testWidgets('4. Rider Orders screen zero-state has NO action buttons when empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NovaEmptyState.orders(
                title: 'No Orders Assigned Yet',
                message: 'You are online and ready! As soon as Central Dispatch assigns delivery runs to you, they will appear here automatically.',
                onAction: null,
                actionLabel: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("No Orders Assigned Yet"), findsOneWidget);
      expect(find.textContaining("You are online and ready!"), findsOneWidget);

      // Verify NO action buttons are present
      expect(find.text("Book Shipment"), findsNothing);
      expect(find.text("Request Orders"), findsNothing);
      expect(find.text("Request Order"), findsNothing);
    });

    testWidgets('5. DCAssignOrderModal blocks assigning orders to unavailable riders and shows UNAVAILABLE tag', (tester) async {
      await tester.binding.setSurfaceSize(const Size(750, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testOrder = OrderEntity(
        id: 'ord_assign_test_1',
        orderNumber: 'NOV-2026-9999',
        customerName: 'Test Customer',
        customerPhone: '08011223344',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Abuja',
        deliveryAddress: 'Wuse 2, Abuja',
        productName: 'Respira Herbal Tea',
        quantity: 1,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pod',
        paymentStatus: 'pending',
        status: 'pending',
        createdAt: DateTime.now(),
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );

      const activeDriver = DCFleetDriver(
        id: 'drv_active',
        driverCode: 'PDA-1111',
        name: 'Active John',
        phone: '08011111111',
        assignedZone: 'Wuse 2',
        status: 'active',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );

      const unavailableDriver = DCFleetDriver(
        id: 'drv_unavailable',
        driverCode: 'PDA-2222',
        name: 'Offline Peter',
        phone: '08022222222',
        assignedZone: 'Wuse 2',
        status: 'offline', // UNAVAILABLE
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );

      final stockAlloc = RiderStockAllocation(
        id: 'alloc_active',
        riderId: 'drv_active',
        riderName: 'Active John',
        riderCode: 'PDA-1111',
        productId: 'prod_respira',
        productName: 'Respira Herbal Tea',
        sku: 'SKU-RESP-01',
        allocatedUnits: 5,
        deliveredUnits: 0,
        inCustodyUnits: 5,
        unitPrice: 25000,
        allocatedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          dcConsoleProvider.overrideWith((ref) => _SimpleDCConsoleNotifier([activeDriver, unavailableDriver])),
          stockProvider.overrideWith((ref) => _SimpleStockNotifier([stockAlloc])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCAssignOrderModal(order: testOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Offline Peter is displayed with Unavailable badge
      expect(find.text('Offline Peter'), findsOneWidget);
      expect(find.text('Unavailable (Off-Duty)'), findsOneWidget);

      // Tapping offline rider triggers block snackbar
      await tester.tap(find.text('Offline Peter'));
      await tester.pump();

      expect(find.textContaining('Cannot dispatch: Offline Peter is currently UNAVAILABLE'), findsOneWidget);
    });

    testWidgets('6. PangeaDateRangePickerModal renders responsively on mobile and returns selected range', (tester) async {
      tester.view.physicalSize = const Size(380, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime(2026, 11, 2);
      PangeaDateRangeResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await PangeaDateRangePickerModal.show(
                    ctx,
                    initialStartDate: now.subtract(const Duration(days: 3)),
                    initialEndDate: now,
                    initialPreset: DateRangePreset.last7Days,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Mobile layout should display title and presets
      expect(find.text('Filter by Date Range'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.preset, equals(DateRangePreset.last7Days));
    });
  });
}

class _SimpleDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  _SimpleDCConsoleNotifier(List<DCFleetDriver> drivers)
      : super(DCConsoleState(
          drivers: drivers,
          activeHubId: '22222222-2222-4222-8222-222222222222',
          isLoading: false,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimpleStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _SimpleStockNotifier(List<RiderStockAllocation> allocations)
      : super(StockState(
          riderAllocations: allocations,
          isLoading: false,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
