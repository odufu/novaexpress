import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_distribution_centers_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

// Mock LocalStorageService
class MockLocalStorageService implements LocalStorageService {
  List<DistributionCenter>? cachedDcs;

  @override
  Future<List<DistributionCenter>?> getCachedDistributionCenters() async => cachedDcs;

  @override
  Future<void> cacheDistributionCenters(List<DistributionCenter> dcs) async {
    cachedDcs = dcs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DistributionCenter Entity Tests', () {
    test('DistributionCenter entity properties and JSON roundtrip', () {
      final dc = DistributionCenter(
        id: 'dc_test_1',
        name: 'Asokoro Satellite Depot',
        code: 'DC-ABJ-05',
        state: 'Abuja FCT',
        city: 'Asokoro',
        address: '14 Nelson Mandela Way',
        contactPhone: '+234 811 222 3333',
        contactEmail: 'asokoro@novaexpress.com',
        managerName: 'Chidi Okonkwo',
        isHub: false,
        isActive: true,
        operatingZones: const ['Asokoro', 'Guzape'],
        storageCapacityUnits: 15000,
      );

      expect(dc.isPrimaryHub, isFalse);
      expect(dc.fullLocation, 'Asokoro, Abuja FCT');
      expect(dc.displayCapacity, '15,000 Units');

      final json = dc.toJson();
      final fromJson = DistributionCenter.fromJson(json);

      expect(fromJson.id, dc.id);
      expect(fromJson.code, dc.code);
      expect(fromJson.name, dc.name);
      expect(fromJson.operatingZones, dc.operatingZones);
    });
  });

  group('DCConsoleNotifier Distribution Centers State & Operations', () {
    late MockLocalStorageService mockStorage;
    late DCConsoleNotifier notifier;

    setUp(() {
      mockStorage = MockLocalStorageService();
      notifier = DCConsoleNotifier(mockStorage);
    });

    test('Initializes with default distribution centers', () {
      expect(notifier.state.distributionCenters.length, greaterThanOrEqualTo(4));
      expect(notifier.state.distributionCenters.any((d) => d.code == 'DC-ABJ-01'), isTrue);
      expect(notifier.state.distributionCenters.any((d) => d.code == 'DC-LOS-01'), isTrue);
    });

    test('Filter distribution centers by Hubs vs Satellites', () {
      notifier.setDcFilter('hubs');
      expect(notifier.state.filteredDistributionCenters.every((d) => d.isHub), isTrue);

      notifier.setDcFilter('satellites');
      expect(notifier.state.filteredDistributionCenters.every((d) => !d.isHub), isTrue);

      notifier.setDcFilter('all');
      expect(notifier.state.filteredDistributionCenters.length, notifier.state.distributionCenters.length);
    });

    test('Filter distribution centers by state and search query', () {
      notifier.setSelectedStateFilter('Lagos State');
      expect(notifier.state.filteredDistributionCenters.every((d) => d.state == 'Lagos State'), isTrue);

      notifier.setSelectedStateFilter('all');
      notifier.setSearchQuery('Ikeja');
      expect(notifier.state.filteredDistributionCenters.every((d) => d.name.contains('Ikeja') || d.city.contains('Ikeja')), isTrue);
    });

    test('Create new distribution center with unique code enforcement', () async {
      final created = await notifier.createDistributionCenter(
        name: 'Victoria Island Express Depot',
        code: 'DC-LOS-05',
        stateName: 'Lagos State',
        city: 'Victoria Island',
        address: '88 Adeola Odeku Street',
        isHub: false,
        operatingZones: ['VI', 'Oniru'],
        storageCapacityUnits: 20000,
      );

      expect(created.code, 'DC-LOS-05');
      expect(notifier.state.distributionCenters.any((d) => d.code == 'DC-LOS-05'), isTrue);
      expect(mockStorage.cachedDcs?.any((d) => d.code == 'DC-LOS-05'), isTrue);

      // Attempt duplicate code creation
      expect(
        () => notifier.createDistributionCenter(
          name: 'Duplicate Code Center',
          code: 'DC-LOS-05',
          stateName: 'Lagos State',
          city: 'Lekki',
          address: 'Test address',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Update operating zones and toggle active status', () async {
      final dc = notifier.state.distributionCenters.first;

      await notifier.updateOperatingZones(dc.id, ['Zone A', 'Zone B', 'Zone C']);
      final updatedDc = notifier.state.distributionCenters.firstWhere((d) => d.id == dc.id);
      expect(updatedDc.operatingZones, ['Zone A', 'Zone B', 'Zone C']);

      await notifier.toggleDistributionCenterStatus(dc.id, false);
      final disabledDc = notifier.state.distributionCenters.firstWhere((d) => d.id == dc.id);
      expect(disabledDc.isActive, isFalse);
    });

    test('Switch active workspace distribution center hub', () {
      final targetDc = notifier.state.distributionCenters.firstWhere((d) => d.code == 'DC-LOS-01');
      notifier.switchActiveHub(targetDc);

      expect(notifier.state.activeHubId, targetDc.id);
      expect(notifier.state.activeHubName, targetDc.name);
      expect(notifier.state.activeHubCode, targetDc.code);
    });
  });

  group('DCDistributionCentersPage Widget Rendering & User Interaction', () {
    testWidgets('Renders KPI statistics, filter toolbar, and distribution center cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Top KPIs
      expect(find.text('Distribution Centers Network'), findsOneWidget);
      expect(find.text('Total Network DCs'), findsOneWidget);
      expect(find.text('Primary Regional Hubs'), findsOneWidget);
      expect(find.text('Fleet Attachment Capacity'), findsOneWidget);
      expect(find.text('Network Storage Volume'), findsOneWidget);

      // Verify Default Seed DCs Rendered
      expect(find.text('Wuse Central Distribution Hub'), findsOneWidget);
      expect(find.text('Ikeja Commercial Hub DC'), findsOneWidget);
      expect(find.text('Port Harcourt Gateway DC'), findsOneWidget);
      expect(find.text('Kano Northern Depot DC'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Edit Details'), findsWidgets);
      expect(find.text('+ Register Distribution Center'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Live search keyword filters distribution center cards list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term in search bar
      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'Port Harcourt');
      await tester.pumpAndSettle();

      expect(find.text('Port Harcourt Gateway DC'), findsOneWidget);
      expect(find.text('Wuse Central Distribution Hub'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Tapping Register DC opens Create DC Modal with inputs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Register DC button
      await tester.tap(find.text('+ Register Distribution Center'));
      await tester.pumpAndSettle();

      // Verify Dialog is open
      expect(find.text('Register New Distribution Center'), findsOneWidget);
      expect(find.text('Distribution Center Name *'), findsOneWidget);
      expect(find.text('Unique DC Code *'), findsOneWidget);
      expect(find.text('Full Physical Warehouse Address *'), findsOneWidget);

      // Cancel Dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Register New Distribution Center'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
