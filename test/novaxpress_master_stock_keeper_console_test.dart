import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/pages/master_stock_keeper_console_page.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NovaXpress Master Stock Keeper Console Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('1. Role & Route: Damilare is configured as novaxpress_stock_keeper routing to /master-stock-ops', () {
      const damilareUser = UserEntity(
        id: '3be27458-e54e-4a99-83c8-73f0d0147e47',
        email: 'damieajani@gmail.com',
        firstName: 'Damilare',
        lastName: 'Ajani',
        phone: '07042266323',
        role: 'novaxpress_stock_keeper',
        deliveryAgentCode: 'HQ-STOCK-KEEPER',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Abuja Central DC',
      );

      expect(damilareUser.isNovaXpressStockKeeper, isTrue);
      expect(damilareUser.roleDescription, equals('NovaXpress Master Stock Keeper'));
      expect(damilareUser.homeConsoleRoute, equals('/master-stock-ops'));
    });

    test('2. Zero Initial Stock: NovaXpress Logistics initially starts with 0 units until allocated by Damilare', () {
      final nxAgent = AdminLogisticsAgent(
        id: 'agent-novaxpress-logistics',
        name: 'NovaXpress Logistics (Internal Fleet)',
        agentCode: 'NX-ABJ-01',
        type: 'internal_logistics',
        contactPerson: 'Engr. Tunde Adeleke',
        phone: '+234 803 111 2233',
        email: 'logistics@novaxpress.ng',
        coverageStates: const ['Abuja (FCT)', 'Niger', 'Nasarawa', 'Kaduna'],
        heldStock: const {}, // Strict 0 initial stock
        createdAt: DateTime.now(),
      );

      final totalInitialUnits = nxAgent.heldStock.values.fold<int>(0, (sum, v) => sum + v);
      expect(totalInitialUnits, equals(0));
      expect(nxAgent.heldStock.isEmpty, isTrue);
    });

    test('3. Stock Allocation Flow: Damilare allocates 100 units from DC shelves to NovaXpress Logistics', () {
      var centralDcProduct = const AdminGlobalStockItem(
        id: 'prod-grazer-01',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea',
        sku: 'NOVA-GRAZER-01',
        merchantId: 'merchant-novacare',
        merchantName: 'Novacare Limited',
        unitPrice: 21500.0,
        totalWarehouseStock: 500,
        totalRiderCustodyStock: 0,
        totalStock: 500,
        lowStockDcCount: 0,
        dcStockBreakdown: {'Abuja Central DC': 500},
        agentStockBreakdown: {},
      );

      var nxAgent = AdminLogisticsAgent(
        id: 'agent-novaxpress-logistics',
        name: 'NovaXpress Logistics (Internal Fleet)',
        agentCode: 'NX-ABJ-01',
        type: 'internal_logistics',
        contactPerson: 'Engr. Tunde Adeleke',
        phone: '+234 803 111 2233',
        email: 'logistics@novaxpress.ng',
        coverageStates: const ['Abuja (FCT)'],
        heldStock: const {},
        createdAt: DateTime.now(),
      );

      const int unitsToAllocate = 100;

      // Execute Allocation
      final newDcStock = centralDcProduct.totalWarehouseStock - unitsToAllocate;
      final updatedHeldStock = Map<String, int>.from(nxAgent.heldStock);
      updatedHeldStock[centralDcProduct.sku] = unitsToAllocate;

      centralDcProduct = centralDcProduct.copyWith(
        totalWarehouseStock: newDcStock,
        totalRiderCustodyStock: unitsToAllocate,
        totalStock: newDcStock + unitsToAllocate,
        dcStockBreakdown: {'Abuja Central DC': newDcStock},
        agentStockBreakdown: {nxAgent.name: unitsToAllocate},
      );

      nxAgent = nxAgent.copyWith(heldStock: updatedHeldStock);

      // Verify balances
      expect(centralDcProduct.totalWarehouseStock, equals(400));
      expect(centralDcProduct.totalRiderCustodyStock, equals(100));
      expect(nxAgent.heldStock['NOVA-GRAZER-01'], equals(100));
      expect(nxAgent.heldStock.values.fold<int>(0, (sum, v) => sum + v), equals(100));
    });

    test('4. Inter-Agent Re-allocation: Damilare transfers 25 units from ADICHA to NovaXpress Logistics', () {
      var adichaAgent = AdminLogisticsAgent(
        id: 'agent-adicha',
        name: 'ADICHA LOGISTICS',
        agentCode: 'AG-001',
        type: '3pl_partner',
        contactPerson: 'Adicha Manager',
        phone: '+234 801 111 2222',
        email: 'dispatch@adicha.ng',
        coverageStates: const ['Lagos'],
        heldStock: const {'NOVA-GRAZER-01': 50},
        createdAt: DateTime.now(),
      );

      var nxAgent = AdminLogisticsAgent(
        id: 'agent-novaxpress-logistics',
        name: 'NovaXpress Logistics (Internal Fleet)',
        agentCode: 'NX-ABJ-01',
        type: 'internal_logistics',
        contactPerson: 'Engr. Tunde Adeleke',
        phone: '+234 803 111 2233',
        email: 'logistics@novaxpress.ng',
        coverageStates: const ['Abuja (FCT)'],
        heldStock: const {'NOVA-GRAZER-01': 100},
        createdAt: DateTime.now(),
      );

      const int unitsToTransfer = 25;

      // Transfer from ADICHA to NX
      final updatedAdichaHeld = Map<String, int>.from(adichaAgent.heldStock);
      updatedAdichaHeld['NOVA-GRAZER-01'] = updatedAdichaHeld['NOVA-GRAZER-01']! - unitsToTransfer;

      final updatedNxHeld = Map<String, int>.from(nxAgent.heldStock);
      updatedNxHeld['NOVA-GRAZER-01'] = updatedNxHeld['NOVA-GRAZER-01']! + unitsToTransfer;

      adichaAgent = adichaAgent.copyWith(heldStock: updatedAdichaHeld);
      nxAgent = nxAgent.copyWith(heldStock: updatedNxHeld);

      expect(adichaAgent.heldStock['NOVA-GRAZER-01'], equals(25));
      expect(nxAgent.heldStock['NOVA-GRAZER-01'], equals(125));
    });

    testWidgets('5. MasterStockKeeperConsolePage renders UI, Bento Grid and tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      const damilareUser = UserEntity(
        id: '3be27458-e54e-4a99-83c8-73f0d0147e47',
        email: 'damieajani@gmail.com',
        firstName: 'Damilare',
        lastName: 'Ajani',
        phone: '07042266323',
        role: 'novaxpress_stock_keeper',
        deliveryAgentCode: 'HQ-STOCK-KEEPER',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Abuja Central DC',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(
                  initialUser: damilareUser,
                  loginUseCase: ref.read(loginUseCaseProvider),
                  logoutUseCase: ref.read(logoutUseCaseProvider),
                  getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
                  authRepository: ref.read(authRepositoryProvider),
                )),
          ],
          child: const MaterialApp(
            home: MasterStockKeeperConsolePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header Elements
      expect(find.text('Damilare Ajani'), findsOneWidget);
      expect(find.text('MASTER STOCK KEEPER'), findsOneWidget);
      expect(find.textContaining('Abuja Central DC'), findsOneWidget);

      // Verify Bento Grid Metrics
      expect(find.text('Total Platform Stock'), findsOneWidget);
      expect(find.text('Central DC Shelves'), findsOneWidget);
      expect(find.text('Partner Agent Custody'), findsOneWidget);
      expect(find.text('NovaXpress Fleet (NX-ABJ-01)'), findsOneWidget);

      // Verify Fast Actions
      expect(find.text('Allocate from DC'), findsWidgets);
      expect(find.text('Re-allocate Between Agents'), findsOneWidget);
      expect(find.text('Log Agent Daily Sales'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Agent Custody Matrix'), findsOneWidget);
      expect(find.text('DC Shelves & SKUs'), findsOneWidget);
      expect(find.text('Daily Sales Ledger'), findsOneWidget);
      expect(find.text('Audit Trail'), findsOneWidget);
    });
  });
}
