import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_transaction_record.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_transactions_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  group('DC Transactions Ledger & Forensic Audit Suite', () {
    final now = DateTime(2026, 8, 23, 20, 30);

    final mockPstkTxn = DCTransactionRecord(
      id: 'txn-pstk-101',
      transactionCode: 'PSTK-ORD8924',
      orderNumber: 'ORD-892401',
      orderId: 'ord-uuid-101',
      productName: 'Respira Detox Formula',
      customerName: 'Alhaji Gambo',
      customerPhone: '08034567890',
      deliveryLocation: 'Wuse 2, Abuja',
      riderId: 'agent-101',
      riderName: 'Joel Rider',
      riderCode: 'PDA-7000',
      amount: 35000.0,
      commission: 1000.0,
      transportAllowance: 1500.0,
      category: 'paystack_direct',
      paymentMethod: 'paystack',
      gatewayReference: 'PSTK-ORD8924',
      channel: 'Titan Trust / Paystack',
      status: 'verified',
      isCredit: true,
      notes: '[POD Paid via Paystack Direct Transfer • Ref: PSTK-ORD8924]',
      createdAt: now,
    );

    final mockCashTxn = DCTransactionRecord(
      id: 'txn-cash-102',
      transactionCode: 'ORD-990112',
      orderNumber: 'ORD-990112',
      orderId: 'ord-uuid-102',
      productName: 'Vitality Pro Blend',
      customerName: 'Chief Emeka',
      customerPhone: '08029988776',
      deliveryLocation: 'Maitama, Abuja',
      riderId: 'agent-101',
      riderName: 'Joel Rider',
      riderCode: 'PDA-7000',
      amount: 25000.0,
      commission: 1000.0,
      transportAllowance: 1500.0,
      category: 'cash_pod',
      paymentMethod: 'cash',
      gatewayReference: null,
      channel: 'Cash in Hand (COD)',
      status: 'verified',
      isCredit: true,
      notes: 'Customer paid physical cash at delivery door.',
      createdAt: now.subtract(const Duration(hours: 2)),
    );

    final mockPartialRemittance = DCTransactionRecord(
      id: 'txn-rem-partial-103',
      transactionCode: 'REM-PARTIAL-01',
      riderId: 'agent-101',
      riderName: 'Joel Rider',
      riderCode: 'PDA-7000',
      amount: 15000.0,
      expectedAmount: 25000.0,
      discrepancyAmount: -10000.0,
      discrepancyReason: 'Rider remitted partial cash due to daily bank transfer limit',
      category: 'remittance',
      paymentMethod: 'bank_transfer',
      gatewayReference: 'PSTK-REM-P103',
      channel: 'Titan Trust / Paystack',
      status: 'partial',
      isCredit: false,
      isPartial: true,
      notes: 'Partial Cash Remittance of ₦15,000 against expected ₦25,000.',
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final mockCompleteRemittance = DCTransactionRecord(
      id: 'txn-rem-comp-104',
      transactionCode: 'REM-COMPLETE-02',
      riderId: 'agent-101',
      riderName: 'Joel Rider',
      riderCode: 'PDA-7000',
      amount: 40000.0,
      expectedAmount: 40000.0,
      category: 'remittance',
      paymentMethod: 'bank_transfer',
      gatewayReference: 'PSTK-REM-C104',
      channel: 'Titan Trust / Paystack',
      status: 'verified',
      isCredit: false,
      isPartial: false,
      notes: 'Full Cash Remittance reconciled with zero discrepancy.',
      createdAt: now.subtract(const Duration(hours: 4)),
    );

    test('1. DCTransactionRecord entity properties and computations calculate correctly', () {
      expect(mockPstkTxn.isPaystack, isTrue);
      expect(mockPstkTxn.isCashPod, isFalse);
      expect(mockPstkTxn.isVerified, isTrue);
      expect(mockPstkTxn.totalRiderEntitlement, equals(2500.0));
      expect(mockPstkTxn.categoryDisplay, equals('Paystack Direct Transfer'));

      expect(mockCashTxn.isPaystack, isFalse);
      expect(mockCashTxn.isCashPod, isTrue);
      expect(mockCashTxn.totalRiderEntitlement, equals(2500.0));
      expect(mockCashTxn.categoryDisplay, equals('Cash POD Collection'));

      expect(mockPartialRemittance.isRemittance, isTrue);
      expect(mockPartialRemittance.isPartialRemittance, isTrue);
      expect(mockPartialRemittance.isCompleteRemittance, isFalse);
      expect(mockPartialRemittance.remainingShortage, equals(10000.0));
      expect(mockPartialRemittance.categoryDisplay, equals('Partial Cash Remittance'));

      expect(mockCompleteRemittance.isRemittance, isTrue);
      expect(mockCompleteRemittance.isPartialRemittance, isFalse);
      expect(mockCompleteRemittance.isCompleteRemittance, isTrue);

      final json = mockPstkTxn.toJson();
      final restored = DCTransactionRecord.fromJson(json);
      expect(restored.transactionCode, equals('PSTK-ORD8924'));
      expect(restored.orderNumber, equals('ORD-892401'));
      expect(restored.riderName, equals('Joel Rider'));
      expect(restored.riderCode, equals('PDA-7000'));
      expect(restored.amount, equals(35000.0));
    });

    test('2. DCConsoleState filteredTransactions filters correctly by category and query', () {
      const state = DCConsoleState();
      final populated = state.copyWith(
        transactions: [mockPstkTxn, mockCashTxn, mockPartialRemittance, mockCompleteRemittance],
      );

      expect(populated.transactions.length, equals(4));

      // Category filter: paystack
      final paystackOnly = populated.copyWith(transactionFilter: 'paystack');
      expect(paystackOnly.filteredTransactions.length, equals(1));
      expect(paystackOnly.filteredTransactions.first.transactionCode, equals('PSTK-ORD8924'));

      // Category filter: cash
      final cashOnly = populated.copyWith(transactionFilter: 'cash');
      expect(cashOnly.filteredTransactions.length, equals(1));
      expect(cashOnly.filteredTransactions.first.transactionCode, equals('ORD-990112'));

      // Category filter: remittance
      final remOnly = populated.copyWith(transactionFilter: 'remittance');
      expect(remOnly.filteredTransactions.length, equals(2));

      // Search query: by customer name 'Gambo'
      final searchGambo = populated.copyWith(searchQuery: 'Gambo');
      expect(searchGambo.filteredTransactions.length, equals(1));
      expect(searchGambo.filteredTransactions.first.customerName, equals('Alhaji Gambo'));

      // Search query: by rider code 'PDA-7000'
      final searchRider = populated.copyWith(searchQuery: 'PDA-7000');
      expect(searchRider.filteredTransactions.length, equals(4));
    });

    testWidgets('3. DCTransactionsPage renders metrics, table and partial/complete status badges', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) {
              final notifier = DCConsoleNotifier();
              notifier.state = notifier.state.copyWith(
                transactions: [mockPstkTxn, mockCashTxn, mockPartialRemittance, mockCompleteRemittance],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: DCTransactionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Transactions & Audit Ledger'), findsOneWidget);
      expect(find.text('Total Gross Volume'), findsOneWidget);
      expect(find.text('Paystack Direct Transfers'), findsOneWidget);
      expect(find.text('Cash POD Handled'), findsOneWidget);
      expect(find.text('Rider Entitlements'), findsOneWidget);

      // Verify Transaction Content
      expect(find.text('PSTK-ORD8924'), findsWidgets);
      expect(find.text('REM-PARTIAL-01'), findsWidgets);
      expect(find.text('REM-COMPLETE-02'), findsWidgets);
      expect(find.text('Joel Rider'), findsWidgets);

      // Verify Partial vs Complete Remittance Badges
      expect(find.text('PARTIAL ⚠️'), findsWidgets);
      expect(find.text('COMPLETE ⚡'), findsWidgets);
    });
  });
}
