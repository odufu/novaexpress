import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/domain/repositories/finance_repository.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';

import 'package:novexps/features/finance/domain/entities/transaction_item.dart';

class MockFinanceRepository implements FinanceRepository {
  final Map<String, List<RemittanceEntity>> dcRemittances;

  MockFinanceRepository(this.dcRemittances);

  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String id) async {
    return dcRemittances[id] ?? [];
  }

  @override
  Future<RemittanceEntity> submitRemittance({
    required String agentId,
    required String companyId,
    String? distributionCenterId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
  }) async {
    final rem = RemittanceModel(
      id: 'mock-rem-${DateTime.now().millisecondsSinceEpoch}',
      referenceNumber: referenceNumber ?? 'REM-TEST',
      companyId: companyId,
      deliveryAgentId: agentId,
      distributionCenterId: distributionCenterId,
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
    );
    if (distributionCenterId != null) {
      dcRemittances.putIfAbsent(distributionCenterId, () => []).add(rem);
    }
    return rem;
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async => [];

  @override
  Future<List<TransactionItem>> getRiderTransactions(String agentId) async => [];

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async => null;

  @override
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async => {'status': 'success'};
}

class MockLocalStorageService extends LocalStorageServiceImpl {
  final Map<String, List<Map<String, dynamic>>> storage = {};

  @override
  Future<void> cacheRemittances(List<RemittanceEntity> remittances, [String? scopeKey]) async {
    final key = (scopeKey != null && scopeKey.isNotEmpty) ? 'remittances_$scopeKey' : 'remittances';
    storage[key] = remittances.map((r) => RemittanceModel.fromEntity(r).toJson()).toList();
  }

  @override
  Future<List<RemittanceEntity>?> getCachedRemittances([String? scopeKey]) async {
    final key = (scopeKey != null && scopeKey.isNotEmpty) ? 'remittances_$scopeKey' : 'remittances';
    final list = storage[key];
    if (list == null) return null;
    return list.map((json) => RemittanceModel.fromJson(json)).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const abujaDcId = '22222222-2222-4222-8222-222222222222';
  const otukpoDcId = '00000000-0000-4000-8000-788825051520';

  final otukpoRemittance1 = RemittanceModel(
    id: 'rem-otukpo-1',
    referenceNumber: 'PSTK-OTUKPO-001',
    deliveryAgentId: 'rider-otukpo-daniel',
    distributionCenterId: otukpoDcId,
    distributionCenterName: 'Otukpo Distribution Center',
    amount: 51600.0,
    status: 'verified',
    createdAt: DateTime(2026, 9, 10, 10, 0),
  );

  final otukpoRemittance2 = RemittanceModel(
    id: 'rem-otukpo-2',
    referenceNumber: 'PSTK-OTUKPO-002',
    deliveryAgentId: 'rider-otukpo-daniel',
    distributionCenterId: otukpoDcId,
    distributionCenterName: 'Otukpo Distribution Center',
    amount: 49900.0,
    status: 'verified',
    createdAt: DateTime(2026, 9, 10, 12, 0),
  );

  final abujaRemittance = RemittanceModel(
    id: 'rem-abuja-1',
    referenceNumber: 'PSTK-ABUJA-001',
    deliveryAgentId: 'rider-abuja-main',
    distributionCenterId: abujaDcId,
    distributionCenterName: 'Wuse Central Distribution Hub',
    amount: 75000.0,
    status: 'verified',
    createdAt: DateTime(2026, 9, 10, 9, 0),
  );

  late MockFinanceRepository mockRepo;
  late MockLocalStorageService mockStorage;

  setUp(() {
    mockRepo = MockFinanceRepository({
      otukpoDcId: [otukpoRemittance1, otukpoRemittance2],
      abujaDcId: [abujaRemittance],
    });
    mockStorage = MockLocalStorageService();
  });

  group('Multi-DC Remittance Scoping and Isolation Tests', () {
    test('RemittanceModel properly serializes and deserializes distributionCenterId', () {
      final json = otukpoRemittance1.toJson();
      expect(json['distribution_center_id'], otukpoDcId);
      expect(json['distribution_center_name'], 'Otukpo Distribution Center');

      final deserialized = RemittanceModel.fromJson(json);
      expect(deserialized.distributionCenterId, otukpoDcId);
      expect(deserialized.distributionCenterName, 'Otukpo Distribution Center');
      expect(deserialized.amount, 51600.0);
    });

    test('Otukpo DC only sees Otukpo remittances and NEVER Abuja remittances', () async {
      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(financeProvider.notifier);
      await notifier.loadRemittances(otukpoDcId);

      final state = container.read(financeProvider);
      expect(state.remittances.length, 2);
      expect(state.remittances.every((r) => r.distributionCenterId == otukpoDcId), isTrue);
      expect(state.remittances.any((r) => r.id == abujaRemittance.id), isFalse);
    });

    test('Abuja Grand DC on its main tabs only sees Abuja remittances and NEVER Otukpo remittances', () async {
      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(financeProvider.notifier);
      await notifier.loadRemittances(abujaDcId);

      final state = container.read(financeProvider);
      expect(state.remittances.length, 1);
      expect(state.remittances.first.id, abujaRemittance.id);
      expect(state.remittances.first.distributionCenterId, abujaDcId);
      expect(state.remittances.any((r) => r.distributionCenterId == otukpoDcId), isFalse);
    });

    test('Parent DC can inspect Otukpo DC remittances via loadDcRemittances without polluting global state', () async {
      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(financeProvider.notifier);

      // 1. Abuja DC is currently active in main state
      await notifier.loadRemittances(abujaDcId);
      expect(container.read(financeProvider).remittances.length, 1);
      expect(container.read(financeProvider).remittances.first.id, abujaRemittance.id);

      // 2. Parent hub navigates to DC tab and opens Otukpo DC details
      final otukpoItems = await notifier.loadDcRemittances(otukpoDcId);
      expect(otukpoItems.length, 2);
      expect(otukpoItems.every((r) => r.distributionCenterId == otukpoDcId), isTrue);

      // 3. Verify main financeProvider state is STILL Abuja and not overwritten
      expect(container.read(financeProvider).remittances.length, 1);
      expect(container.read(financeProvider).remittances.first.id, abujaRemittance.id);
    });

    test('Local storage caches remittances separately per DC scope', () async {
      await mockStorage.cacheRemittances([otukpoRemittance1, otukpoRemittance2], otukpoDcId);
      await mockStorage.cacheRemittances([abujaRemittance], abujaDcId);

      final cachedOtukpo = await mockStorage.getCachedRemittances(otukpoDcId);
      final cachedAbuja = await mockStorage.getCachedRemittances(abujaDcId);

      expect(cachedOtukpo?.length, 2);
      expect(cachedOtukpo?.every((r) => r.distributionCenterId == otukpoDcId), isTrue);

      expect(cachedAbuja?.length, 1);
      expect(cachedAbuja?.first.distributionCenterId, abujaDcId);
    });

    test('Submitting a remittance persists distributionCenterId correctly', () async {
      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(financeProvider.notifier);
      final success = await notifier.submitRemittance(
        amount: 30000.0,
        paymentMethod: 'cash_to_dc',
        agentId: 'rider-otukpo-daniel',
        distributionCenterId: otukpoDcId,
        referenceNumber: 'REM-OTUKPO-NEW-01',
      );

      expect(success, isTrue);
      final otukpoList = await notifier.loadDcRemittances(otukpoDcId);
      expect(otukpoList.any((r) => r.referenceNumber == 'REM-OTUKPO-NEW-01'), isTrue);
      expect(otukpoList.firstWhere((r) => r.referenceNumber == 'REM-OTUKPO-NEW-01').distributionCenterId, otukpoDcId);
    });
  });
}
