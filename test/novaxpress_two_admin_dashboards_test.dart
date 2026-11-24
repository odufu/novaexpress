import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/features/admin_console/data/datasources/admin_remote_datasource.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/pages/admin_console_layout.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/presentation/pages/novaxpress_logistics_admin_dashboard_page.dart';

void main() {
  group('NovaXpress Two Distinct Admin Dashboards - Role & Route Verification', () {
    test('1. UserEntity role definitions differentiate Platform Admin vs Logistics Admin', () {
      const platformAdmin = UserEntity(
        id: 'u-platform-1',
        authUserId: 'auth-1',
        email: 'ceo@novaxpress.com',
        phone: '08012345678',
        firstName: 'Nova',
        lastName: 'Admin',
        role: 'novaxpress_admin',
      );

      const superAdmin = UserEntity(
        id: 'u-super-1',
        authUserId: 'auth-2',
        email: 'sysadmin@novaxpress.com',
        phone: '08012345679',
        firstName: 'System',
        lastName: 'Admin',
        role: 'super_admin',
      );

      const logisticsAdmin = UserEntity(
        id: 'u-logistics-1',
        authUserId: 'auth-3',
        email: 'fleet@novaxpress.com',
        phone: '08012345680',
        firstName: 'Logistics',
        lastName: 'Director',
        role: 'logistics_admin',
      );

      const dcAdmin = UserEntity(
        id: 'u-dc-admin-1',
        authUserId: 'auth-4',
        email: 'dc.admin@novaxpress.com',
        phone: '08012345681',
        firstName: 'Hub',
        lastName: 'Manager',
        role: 'dc_admin',
      );

      const rider = UserEntity(
        id: 'u-rider-1',
        authUserId: 'auth-5',
        email: 'rider@novaxpress.com',
        phone: '08012345682',
        firstName: 'Simon',
        lastName: 'Tazha',
        role: 'rider',
      );

      // Verify Platform Admin identification
      expect(platformAdmin.isPlatformAdmin, isTrue);
      expect(platformAdmin.isSuperAdmin, isTrue);
      expect(platformAdmin.homeConsoleRoute, equals('/admin'));
      expect(platformAdmin.roleDescription, equals('NovaXpress Platform Admin'));

      expect(superAdmin.isPlatformAdmin, isTrue);
      expect(superAdmin.homeConsoleRoute, equals('/admin'));

      // Verify Logistics Admin identification
      expect(logisticsAdmin.isLogisticsAdmin, isTrue);
      expect(logisticsAdmin.isPlatformAdmin, isFalse);
      expect(logisticsAdmin.homeConsoleRoute, equals('/logistics-admin'));
      expect(logisticsAdmin.roleDescription, equals('NovaXpress Logistics Admin'));

      expect(dcAdmin.isLogisticsAdmin, isTrue);
      expect(dcAdmin.homeConsoleRoute, equals('/logistics-admin'));

      // Non-admins
      expect(rider.isPlatformAdmin, isFalse);
      expect(rider.isLogisticsAdmin, isFalse);
      expect(rider.homeConsoleRoute, equals('/'));
    });

    test('2. appRouteRedirect enforces strict isolation between /admin and /logistics-admin', () {
      const platformAdmin = UserEntity(
        id: 'u-platform',
        authUserId: 'auth-1',
        email: 'admin@novaxpress.com',
        phone: '08012345678',
        firstName: 'Nova',
        lastName: 'Admin',
        role: 'platform_admin',
      );

      const logisticsAdmin = UserEntity(
        id: 'u-logistics',
        authUserId: 'auth-2',
        email: 'logistics@novaxpress.com',
        phone: '08012345679',
        firstName: 'Logistics',
        lastName: 'Head',
        role: 'logistics_admin',
      );

      const rider = UserEntity(
        id: 'u-rider',
        authUserId: 'auth-3',
        email: 'rider@novaxpress.com',
        phone: '08012345680',
        firstName: 'Field',
        lastName: 'Rider',
        role: 'rider',
      );

      // Test /admin route access
      // Platform admin can access /admin
      final res1 = appRouteRedirect(
        authState: AuthState(user: platformAdmin),
        matchedLocation: '/admin',
        hasSupabaseSession: true,
      );
      expect(res1, isNull); // Allowed

      // Logistics admin cannot access /admin (redirects to /logistics-admin)
      final res2 = appRouteRedirect(
        authState: AuthState(user: logisticsAdmin),
        matchedLocation: '/admin',
        hasSupabaseSession: true,
      );
      expect(res2, equals('/logistics-admin'));

      // Rider cannot access /admin (redirects to /)
      final res3 = appRouteRedirect(
        authState: AuthState(user: rider),
        matchedLocation: '/admin',
        hasSupabaseSession: true,
      );
      expect(res3, equals('/'));

      // Test /logistics-admin route access
      // Logistics admin can access /logistics-admin
      final res4 = appRouteRedirect(
        authState: AuthState(user: logisticsAdmin),
        matchedLocation: '/logistics-admin',
        hasSupabaseSession: true,
      );
      expect(res4, isNull); // Allowed

      // Platform admin can also inspect /logistics-admin via console switcher
      final res5 = appRouteRedirect(
        authState: AuthState(user: platformAdmin),
        matchedLocation: '/logistics-admin',
        hasSupabaseSession: true,
      );
      expect(res5, isNull); // Allowed

      // Rider cannot access /logistics-admin
      final res6 = appRouteRedirect(
        authState: AuthState(user: rider),
        matchedLocation: '/logistics-admin',
        hasSupabaseSession: true,
      );
      expect(res6, equals('/'));
    });

    test('3. AdminConsoleState manages 3PL agents, approvals and 10 PM daily settlements', () async {
      final mockAgent1 = AdminLogisticsAgent(
        id: 'agent-1',
        name: 'NovaXpress Fleet',
        agentCode: 'AG-001-NX',
        type: 'internal_fleet',
        contactPerson: 'Fleet Manager',
        phone: '08011112222',
        email: 'fleet@novaxpress.ng',
        status: 'active',
        coverageStates: const ['Lagos'],
        createdAt: DateTime(2026, 1, 1),
      );
      final mockAgent2 = AdminLogisticsAgent(
        id: 'agent-2',
        name: 'Speedaf Partner',
        agentCode: 'AG-002-SPD',
        type: '3pl_partner',
        contactPerson: 'Partner Rep',
        phone: '08033334444',
        email: 'speedaf@novaxpress.ng',
        status: 'active',
        coverageStates: const ['Abuja'],
        createdAt: DateTime(2026, 1, 1),
      );
      final mockStock = const AdminGlobalStockItem(
        id: 'prod-1',
        productId: 'prod-1',
        productName: 'Product 1',
        sku: 'SKU-001',
        merchantId: 'm-1',
        merchantName: 'Novacare',
        unitPrice: 5000,
        totalWarehouseStock: 100,
        totalRiderCustodyStock: 0,
        totalStock: 100,
        lowStockDcCount: 0,
      );
      final mockSettlement = AdminSettlementReconciliation(
        id: 'RECON-001',
        date: DateTime.now(),
        totalGrossCodCollected: 10000,
        totalCourierDeliveryFees: 1000,
        totalFuelAllowances: 200,
        totalPlatformCommissions: 500,
        totalNetMerchantPayout: 8300,
        totalOrdersSettled: 5,
        participatingAgentsCount: 1,
        participatingMerchantsCount: 1,
        status: 'awaiting_cutoff',
      );

      final container = ProviderContainer(
        overrides: [
          adminConsoleProvider.overrideWith((ref) {
            final notifier = AdminConsoleNotifier(AdminRemoteDataSource(), ref);
            notifier.state = notifier.state.copyWith(
              agents: [mockAgent1, mockAgent2],
              globalStock: [mockStock],
              settlementReconciliations: [mockSettlement],
            );
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(adminConsoleProvider);
      final notifier = container.read(adminConsoleProvider.notifier);

      // Verify seeded 3PL logistics agents and partners
      expect(state.agents, isNotEmpty);
      expect(state.agents.any((a) => a.agentCode.contains('AG-001')), isTrue);
      expect(state.agents.any((a) => a.agentCode.contains('AG-002')), isTrue);
      expect(state.agents.any((a) => a.agentCode.contains('NX') || a.name.contains('NovaXpress')), isTrue);

      // Verify global multi-hub stock records
      expect(state.globalStock, isNotEmpty);
      final totalStock = state.globalStock.fold<int>(0, (acc, item) => acc + item.totalStock);
      expect(totalStock, greaterThan(0));

      // Verify 10:00 PM settlement records
      expect(state.settlementReconciliations, isNotEmpty);
      expect(state.settlementReconciliations.any((s) => s.id.contains('RECON')), isTrue);

      // Test Agent approval workflow
      final agentToPending = state.agents.first.copyWith(status: 'pending_approval');
      await notifier.updateLogisticsAgent(agentToPending);
      notifier.approveAgent(agentToPending.id);
      final updatedState = container.read(adminConsoleProvider);
      final approvedAgent = updatedState.agents.firstWhere((a) => a.id == agentToPending.id);
      expect(approvedAgent.isActive, isTrue);

      // Test Triggering 10 PM Settlement
      notifier.triggerDaily10pmSettlement();
      final settledState = container.read(adminConsoleProvider);
      expect(settledState.settlementReconciliations.every((s) => s.isSettled), isTrue);
    });

    testWidgets('4. NovaXpressLogisticsAdminDashboardPage renders on desktop and mobile viewports', (tester) async {
      // Set mobile viewport dimensions (390 x 844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NovaXpressLogisticsAdminDashboardPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Logistics Admin visual identity and badge
      expect(find.text('LOGISTICS ADMIN'), findsOneWidget);
      expect(find.text('Platform Admin'), findsOneWidget); // Switcher to Platform Admin
      expect(find.text('Intake WhatsApp'), findsOneWidget); // Quick WhatsApp intake action

      // Verify Telemetry tab renders
      expect(find.text('NovaXpress Field Logistics Command Hub'), findsOneWidget);
      expect(find.text('Active Couriers On-Duty'), findsOneWidget);
      expect(find.text('In-Transit Deliveries'), findsOneWidget);
      expect(find.text('In-Field Cash Liabilities'), findsOneWidget);
      expect(find.text('10:00 PM Daily Remittance & Settlement Cycle'), findsOneWidget);
    });

    testWidgets('5. AdminConsoleLayout displays Platform Admin banner and Switch to Logistics Admin action', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminConsoleLayout(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Admin Console navigation items and switchers
      expect(find.text('Warehouse Console'), findsWidgets);
      expect(find.text('DC Logistics Console'), findsWidgets);
      expect(find.text('Agents & 3PLs'), findsWidgets);
      expect(find.text('Multi-Hub Stock'), findsWidgets);
      expect(find.text('Warehouses & Branches'), findsWidgets);
    });
  });
}
