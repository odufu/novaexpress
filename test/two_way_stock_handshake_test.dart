import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/stock/domain/entities/stock_transfer_record.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockTwoWayStockRepository implements StockRepository {
  List<StockTransferRecord> transfers = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<StockTransferRecord>> fetchStockTransfers({
    String? dcId,
    String? clientId,
    String? riderId,
    String? status,
    String? transferType,
  }) async {
    return transfers.where((t) {
      if (transferType != null && t.transferType != transferType) return false;
      if (status != null && t.status != status) return false;
      if (clientId != null && t.clientId != clientId) return false;
      if (riderId != null && t.receiverId != riderId && t.senderId != riderId) return false;
      if (dcId != null && t.destinationDcId != dcId && t.sourceDcId != dcId) return false;
      return true;
    }).toList();
  }

  @override
  Future<StockTransferRecord?> getStockTransferById(String transferId) async {
    try {
      return transfers.firstWhere((t) => t.id == transferId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> dispatchClientSupply({
    required String clientId,
    required String dcId,
    required List<Map<String, dynamic>> items,
    String? senderId,
    required String senderName,
    required String senderSignatureUrl,
    String? notes,
  }) async {
    final transferId = 'transfer_cs_${transfers.length + 1}';
    final now = DateTime.now();
    final newRecord = StockTransferRecord(
      id: transferId,
      transferNumber: 'WB-TEST-${transfers.length + 1}',
      clientId: clientId,
      sourceDcId: null,
      destinationDcId: dcId,
      transferType: 'client_supply',
      status: 'dispatched',
      senderId: senderId ?? 'client_user_1',
      senderName: senderName,
      senderRole: 'client',
      senderSignatureUrl: senderSignatureUrl,
      dispatchedAt: now,
      receiverId: null,
      receiverName: null,
      receiverRole: null,
      receiverSignatureUrl: null,
      receivedAt: null,
      notes: notes,
      hasDiscrepancy: false,
      createdAt: now,
      items: items.map((i) {
        return StockTransferItemRecord(
          id: 'item_${i['product_id']}',
          transferId: transferId,
          productId: i['product_id'] as String,
          productName: 'Product ${i['product_id']}',
          sku: 'SKU-${i['product_id']}',
          quantity: (i['quantity'] as num).toInt(),
          quantityReceived: 0,
          quantityDamaged: 0,
          quantityMissing: 0,
        );
      }).toList(),
    );
    transfers.add(newRecord);
    return {
      'success': true,
      'transfer_id': transferId,
      'transfer_number': newRecord.transferNumber,
    };
  }

  @override
  Future<Map<String, dynamic>> receiveClientSupply({
    required String transferId,
    required String receiverId,
    required String receiverName,
    required String receiverSignatureUrl,
    required List<Map<String, dynamic>> verifiedItems,
    String? notes,
  }) async {
    final index = transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) throw Exception('Transfer not found');
    final existing = transfers[index];

    bool hasDiscrepancy = false;
    final updatedItems = existing.items.map((it) {
      final match = verifiedItems.firstWhere(
        (m) => m['item_id'] == it.id || m['product_id'] == it.productId,
        orElse: () => {},
      );
      final rQty = match['quantity_received'] != null ? (match['quantity_received'] as num).toInt() : it.quantity;
      final dQty = match['quantity_damaged'] != null ? (match['quantity_damaged'] as num).toInt() : 0;
      final mQty = match['quantity_missing'] != null ? (match['quantity_missing'] as num).toInt() : 0;
      if (rQty != it.quantity || dQty > 0 || mQty > 0) {
        hasDiscrepancy = true;
      }
      return it.copyWith(
        quantityReceived: rQty,
        quantityDamaged: dQty,
        quantityMissing: mQty,
      );
    }).toList();

    final updated = existing.copyWith(
      status: 'completed',
      receiverId: receiverId,
      receiverName: receiverName,
      receiverRole: 'dc_supervisor',
      receiverSignatureUrl: receiverSignatureUrl,
      receivedAt: DateTime.now(),
      hasDiscrepancy: hasDiscrepancy,
      discrepancyNotes: notes,
      items: updatedItems,
    );
    transfers[index] = updated;
    return {
      'success': true,
      'transfer_id': transferId,
      'status': 'completed',
      'has_discrepancy': hasDiscrepancy,
    };
  }

  @override
  Future<Map<String, dynamic>> issueDcStockToRiderWithSignature({
    required String dcId,
    required String riderId,
    required List<Map<String, dynamic>> items,
    required String senderId,
    required String senderName,
    required String senderSignatureUrl,
    String? notes,
  }) async {
    final transferId = 'transfer_rh_${transfers.length + 1}';
    final now = DateTime.now();
    final newRecord = StockTransferRecord(
      id: transferId,
      transferNumber: 'WB-RIDER-${transfers.length + 1}',
      sourceDcId: dcId,
      transferType: 'dc_to_rider',
      status: 'dispatched',
      senderId: senderId,
      senderName: senderName,
      senderRole: 'dc_supervisor',
      senderSignatureUrl: senderSignatureUrl,
      dispatchedAt: now,
      receiverId: riderId,
      receiverRole: 'rider',
      receiverName: 'Rider John',
      createdAt: now,
      items: items.map((i) {
        return StockTransferItemRecord(
          id: 'item_${i['product_id']}',
          transferId: transferId,
          productId: i['product_id'] as String,
          productName: 'Product ${i['product_id']}',
          sku: 'SKU-${i['product_id']}',
          quantity: (i['quantity'] as num).toInt(),
          quantityReceived: 0,
        );
      }).toList(),
    );
    transfers.add(newRecord);
    return {
      'success': true,
      'transfer_id': transferId,
      'transfer_number': newRecord.transferNumber,
    };
  }

  @override
  Future<Map<String, dynamic>> acceptRiderStockHandover({
    required String transferId,
    required String riderId,
    required String riderName,
    required String riderSignatureUrl,
    List<Map<String, dynamic>>? verifiedItems,
    String? notes,
  }) async {
    final index = transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) throw Exception('Transfer not found');
    final existing = transfers[index];

    final updated = existing.copyWith(
      status: 'completed',
      receiverId: riderId,
      receiverName: riderName,
      receiverSignatureUrl: riderSignatureUrl,
      receivedAt: DateTime.now(),
      notes: notes,
      items: existing.items.map((it) => it.copyWith(quantityReceived: it.quantity)).toList(),
    );
    transfers[index] = updated;
    return {
      'success': true,
      'transfer_id': transferId,
      'status': 'completed',
    };
  }

  @override
  Future<Map<String, dynamic>> rejectRiderStockHandover({
    required String transferId,
    required String riderId,
    String? reason,
  }) async {
    final index = transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) throw Exception('Transfer not found');
    final existing = transfers[index];

    final updated = existing.copyWith(
      status: 'rejected',
      discrepancyNotes: reason,
    );
    transfers[index] = updated;
    return {
      'success': true,
      'transfer_id': transferId,
      'status': 'rejected',
    };
  }

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId, String? dcId]) async => [];

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Two-Way Stock Handshake - Entity & Discrepancy Tests', () {
    test('StockTransferRecord deserializes correctly with dual digital signatures', () {
      final rawJson = {
        'id': 'st_1001',
        'transfer_number': 'WB-2026-001',
        'client_id': 'client_alpha',
        'source_dc_id': null,
        'destination_dc_id': 'dc_lagos_central',
        'transfer_type': 'client_supply',
        'status': 'completed',
        'sender_id': 'merchant_user_1',
        'sender_name': 'Alpha Cosmetics Ltd',
        'sender_role': 'client',
        'sender_signature_url': 'https://storage.supabase.co/pod-proofs/sig_sender_alpha.png',
        'dispatched_at': '2026-09-13T10:00:00.000Z',
        'receiver_id': 'supervisor_user_2',
        'receiver_name': 'Tunde Supervisor',
        'receiver_role': 'dc_supervisor',
        'receiver_signature_url': 'https://storage.supabase.co/pod-proofs/sig_receiver_tunde.png',
        'received_at': '2026-09-13T14:30:00.000Z',
        'has_discrepancy': true,
        'discrepancy_notes': '3 damaged units found during physical inspection',
        'created_at': '2026-09-13T09:00:00.000Z',
        'stock_transfer_items': [
          {
            'id': 'sti_1',
            'transfer_id': 'st_1001',
            'product_id': 'prod_tea_1',
            'quantity_shipped': 50,
            'quantity_received': 47,
            'quantity_damaged': 3,
            'quantity_missing': 0,
            'item_notes': 'Crushed packaging',
            'product': {
              'name': 'Respira Detox Tea',
              'sku': 'SKU-RESP-01',
            }
          }
        ]
      };

      final record = StockTransferRecord.fromJson(rawJson);

      expect(record.id, 'st_1001');
      expect(record.transferNumber, 'WB-2026-001');
      expect(record.isClientSupply, isTrue);
      expect(record.isDcToRider, isFalse);
      expect(record.isDispatched, isFalse);
      expect(record.isCompleted, isTrue);
      expect(record.hasDiscrepancy, isTrue);
      expect(record.senderName, 'Alpha Cosmetics Ltd');
      expect(record.senderSignatureUrl, contains('sig_sender_alpha.png'));
      expect(record.receiverName, 'Tunde Supervisor');
      expect(record.receiverSignatureUrl, contains('sig_receiver_tunde.png'));

      expect(record.items.length, 1);
      final item = record.items.first;
      expect(item.productName, 'Respira Detox Tea');
      expect(item.sku, 'SKU-RESP-01');
      expect(item.quantity, 50);
      expect(item.quantityReceived, 47);
      expect(item.quantityDamaged, 3);
      expect(item.quantityMissing, 0);
      expect(item.hasDiscrepancy, isTrue);
    });

    test('Discrepancy calculations correctly compute missing and damaged balances', () {
      final itemClean = const StockTransferItemRecord(
        id: 'i1',
        transferId: 't1',
        productId: 'p1',
        productName: 'Clean Item',
        sku: 'SKU-01',
        quantity: 20,
        quantityReceived: 20,
        quantityDamaged: 0,
        quantityMissing: 0,
      );

      final itemDamaged = const StockTransferItemRecord(
        id: 'i2',
        transferId: 't1',
        productId: 'p2',
        productName: 'Damaged Item',
        sku: 'SKU-02',
        quantity: 20,
        quantityReceived: 18,
        quantityDamaged: 2,
        quantityMissing: 0,
      );

      final itemMissing = const StockTransferItemRecord(
        id: 'i3',
        transferId: 't1',
        productId: 'p3',
        productName: 'Missing Item',
        sku: 'SKU-03',
        quantity: 15,
        quantityReceived: 10,
        quantityDamaged: 0,
        quantityMissing: 5,
      );

      final transfer = StockTransferRecord(
        id: 't1',
        transferNumber: 'WB-DISC-01',
        transferType: 'client_supply',
        status: 'completed',
        hasDiscrepancy: true,
        createdAt: DateTime.now(),
        items: [itemClean, itemDamaged, itemMissing],
      );

      expect(itemClean.hasDiscrepancy, isFalse);
      expect(itemDamaged.hasDiscrepancy, isTrue);
      expect(itemMissing.hasDiscrepancy, isTrue);

      expect(transfer.totalQuantityDamaged, 2);
      expect(transfer.totalQuantityMissing, 5);
      expect(transfer.totalQuantityReceived, 48);
      expect(transfer.totalQuantityRequested, 55);
      expect(transfer.totalQuantityReceived + transfer.totalQuantityDamaged + transfer.totalQuantityMissing, transfer.totalQuantityRequested);
    });
  });

  group('Two-Way Stock Handshake - Provider & Workflow Tests', () {
    late MockTwoWayStockRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockTwoWayStockRepository();
      container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Full Client -> DC Two-Way Handshake with Digital Signatures', () async {
      final notifier = container.read(stockProvider.notifier);

      // Step 1: Merchant Client dispatches supply with digital signature
      final dispatchResult = await notifier.dispatchClientSupply(
        clientId: 'client_alpha',
        dcId: 'dc_lagos_central',
        senderName: 'Alpha Cosmetics Ltd',
        senderSignatureUrl: 'https://storage.supabase.co/pod-proofs/client_sig_001.png',
        items: [
          {
            'product_id': 'prod_tea_1',
            'quantity': 100,
            'notes': 'Fragile carton 1-4',
          }
        ],
      );

      expect(dispatchResult['success'], isTrue);
      final transferId = dispatchResult['transfer_id'] as String;

      // Verify dispatched transfer in state
      await notifier.fetchStockTransfers(dcId: 'dc_lagos_central');
      final stateAfterDispatch = container.read(stockProvider);
      final dispatched = stateAfterDispatch.stockTransfers.firstWhere((t) => t.id == transferId);
      expect(dispatched.isDispatched, isTrue);
      expect(dispatched.senderSignatureUrl, 'https://storage.supabase.co/pod-proofs/client_sig_001.png');
      expect(dispatched.receiverSignatureUrl, isNull);

      // Step 2: DC Supervisor physically inspects incoming cartons and countersigns
      final receiveResult = await notifier.receiveClientSupply(
        transferId: transferId,
        receiverId: 'sup_user_1',
        receiverName: 'DC Warehouse Manager',
        receiverSignatureUrl: 'https://storage.supabase.co/pod-proofs/dc_sig_manager.png',
        notes: '2 units broken in transit',
        dcId: 'dc_lagos_central',
        verifiedItems: [
          {
            'product_id': 'prod_tea_1',
            'quantity_received': 98,
            'quantity_damaged': 2,
            'quantity_missing': 0,
          }
        ],
      );

      expect(receiveResult['success'], isTrue);
      expect(receiveResult['has_discrepancy'], isTrue);

      // Verify that the record now possesses BOTH signatures and discrepancy flag
      await notifier.fetchStockTransfers(dcId: 'dc_lagos_central');
      final stateAfterReceive = container.read(stockProvider);
      final received = stateAfterReceive.stockTransfers.firstWhere((t) => t.id == transferId);
      expect(received.isCompleted, isTrue);
      expect(received.hasDiscrepancy, isTrue);
      expect(received.senderSignatureUrl, isNotNull);
      expect(received.receiverSignatureUrl, isNotNull);
      expect(received.receiverName, 'DC Warehouse Manager');
      expect(received.items.first.quantityReceived, 98);
      expect(received.items.first.quantityDamaged, 2);
    });

    test('Full DC -> Rider Custody Handover and Digital Signature Acceptance', () async {
      final notifier = container.read(stockProvider.notifier);

      // Step 1: DC Supervisor allocates stock and signs on glass
      final issueResult = await notifier.issueDcStockToRiderWithSignature(
        dcId: 'dc_lagos_central',
        riderId: 'rider_emeka_pda',
        senderId: 'dc_sup_user',
        senderName: 'Supervisor Ade',
        senderSignatureUrl: 'https://storage.supabase.co/pod-proofs/supervisor_handover_sig.png',
        items: [
          {
            'product_id': 'prod_tea_1',
            'quantity': 15,
          }
        ],
      );

      expect(issueResult['success'], isTrue);
      final transferId = issueResult['transfer_id'] as String;

      // Verify handover transfer is pending in state
      await notifier.fetchStockTransfers(riderId: 'rider_emeka_pda');
      final stateAfterIssue = container.read(stockProvider);
      final pendingHandover = stateAfterIssue.stockTransfers.firstWhere((t) => t.id == transferId);
      expect(pendingHandover.isDcToRider, isTrue);
      expect(pendingHandover.isDispatched, isTrue);
      expect(pendingHandover.senderSignatureUrl, contains('supervisor_handover_sig.png'));
      expect(pendingHandover.receiverSignatureUrl, isNull);

      // Step 2: Rider Emeka accepts handover on mobile app by signing on glass
      final acceptResult = await notifier.acceptRiderStockHandover(
        transferId: transferId,
        riderId: 'rider_emeka_pda',
        riderName: 'Emeka Rider',
        riderSignatureUrl: 'https://storage.supabase.co/pod-proofs/rider_emeka_acceptance_sig.png',
        notes: 'All 15 units verified intact in hand',
      );

      expect(acceptResult['success'], isTrue);

      // Verify that both party signatures are present and handover is completed
      await notifier.fetchStockTransfers(riderId: 'rider_emeka_pda');
      final stateAfterAccept = container.read(stockProvider);
      final completedHandover = stateAfterAccept.stockTransfers.firstWhere((t) => t.id == transferId);
      expect(completedHandover.isCompleted, isTrue);
      expect(completedHandover.senderSignatureUrl, contains('supervisor_handover_sig.png'));
      expect(completedHandover.receiverSignatureUrl, contains('rider_emeka_acceptance_sig.png'));
    });

    test('Rider Rejection of Stock Handover flags status as rejected', () async {
      final notifier = container.read(stockProvider.notifier);

      // DC Supervisor issues stock
      final issueResult = await notifier.issueDcStockToRiderWithSignature(
        dcId: 'dc_lagos_central',
        riderId: 'rider_musa_pda',
        senderId: 'dc_sup_user',
        senderName: 'Supervisor Ade',
        senderSignatureUrl: 'https://storage.supabase.co/pod-proofs/supervisor_handover_sig2.png',
        items: [
          {
            'product_id': 'prod_tea_2',
            'quantity': 10,
          }
        ],
      );

      final transferId = issueResult['transfer_id'] as String;

      // Rider rejects handover due to physical damage
      final rejectResult = await notifier.rejectRiderStockHandover(
        transferId: transferId,
        riderId: 'rider_musa_pda',
        reason: 'Carton was soaked in water, refused receipt',
      );

      expect(rejectResult['success'], isTrue);
      expect(rejectResult['status'], 'rejected');

      await notifier.fetchStockTransfers(riderId: 'rider_musa_pda');
      final stateAfterReject = container.read(stockProvider);
      final rejected = stateAfterReject.stockTransfers.firstWhere((t) => t.id == transferId);
      expect(rejected.isRejected, isTrue);
      expect(rejected.discrepancyNotes, contains('Carton was soaked'));
    });
  });
}
