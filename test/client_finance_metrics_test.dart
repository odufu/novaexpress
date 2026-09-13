import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('ClientSettlement Entity Tests', () {
    test('ClientSettlement decodes from Supabase row correctly', () {
      final row = {
        'id': 'settle-001',
        'client_id': 'client-xyz',
        'settlement_number': 'SETTLE-2026-001',
        'status': 'completed',
        'period_start': '2026-09-01T00:00:00Z',
        'period_end': '2026-09-07T23:59:59Z',
        'total_orders_count': 15,
        'gross_collections': 750000.0,
        'logistics_fees_deducted': 45000.0,
        'net_payout_amount': 705000.0,
        'destination_bank_name': 'Access Bank',
        'destination_account_number': '0123456789',
        'destination_account_name': 'Herbal Glow Ltd',
        'proof_of_payment_url': 'https://example.com/receipt.pdf',
        'settled_at': '2026-09-08T10:00:00Z',
        'created_at': '2026-09-08T09:00:00Z',
      };

      final settlement = ClientSettlement.fromJson(row);

      expect(settlement.id, 'settle-001');
      expect(settlement.settlementNumber, 'SETTLE-2026-001');
      expect(settlement.status, 'completed');
      expect(settlement.totalOrdersCount, 15);
      expect(settlement.grossCollections, 750000.0);
      expect(settlement.logisticsFeesDeducted, 45000.0);
      expect(settlement.netPayoutAmount, 705000.0);
      expect(settlement.destinationBankName, 'Access Bank');
      expect(settlement.destinationAccountNumber, '0123456789');
      expect(settlement.destinationAccountName, 'Herbal Glow Ltd');
      expect(settlement.isCompleted, isTrue);
    });

    test('ClientSettlement toJson generates matching database payload', () {
      final settlement = ClientSettlement(
        id: 'settle-002',
        clientId: 'client-xyz',
        settlementNumber: 'SETTLE-2026-002',
        status: 'pending',
        periodStart: DateTime.utc(2026, 9, 8),
        periodEnd: DateTime.utc(2026, 9, 14),
        totalOrdersCount: 5,
        grossCollections: 250000.0,
        logisticsFeesDeducted: 15000.0,
        netPayoutAmount: 235000.0,
        destinationBankName: 'GTBank',
        destinationAccountNumber: '0987654321',
        destinationAccountName: 'Herbal Glow Payout',
        settledAt: DateTime.utc(2026, 9, 15),
        createdAt: DateTime.utc(2026, 9, 15),
      );

      final map = settlement.toJson();

      expect(map['settlement_number'], 'SETTLE-2026-002');
      expect(map['net_payout_amount'], 235000.0);
      expect(map['status'], 'pending');
      expect(settlement.isPending, isTrue);
    });
  });

  group('ClientProfile Bank Settlement Details Tests', () {
    test('ClientProfile correctly stores payout banking credentials', () {
      final profile = ClientProfile(
        id: 'client-1',
        companyName: 'Health First Global',
        contactPerson: 'Dr. Ade',
        email: 'ade@healthfirst.ng',
        phone: '08011223344',
        address: '10 Victoria Island, Lagos',
        bankName: 'First Bank of Nigeria',
        accountNumber: '3049182736',
        accountName: 'Health First Global Enterprises',
        settlementFrequency: 'weekly',
        settlementDay: 'Friday',
      );

      expect(profile.bankName, 'First Bank of Nigeria');
      expect(profile.accountNumber, '3049182736');
      expect(profile.accountName, 'Health First Global Enterprises');
      expect(profile.settlementFrequency, 'weekly');
      expect(profile.settlementDay, 'Friday');

      final copy = profile.copyWith(
        bankName: 'Zenith Bank',
        accountNumber: '1029384756',
      );
      expect(copy.bankName, 'Zenith Bank');
      expect(copy.accountNumber, '1029384756');
      expect(copy.accountName, 'Health First Global Enterprises');
    });
  });

  group('ClientProductFinanceSummary Calculation Tests', () {
    final now = DateTime.now();

    final deliveredAndRemitted = OrderEntity(
      id: 'ord-1',
      orderNumber: 'NOV-001',
      customerName: 'Amina Bello',
      customerPhone: '08012345678',
      deliveryAddress: 'Wuse 2, Abuja',
      deliveryState: 'FCT',
      deliveryCity: 'Abuja',
      quantity: 1,
      basePrice: 50000.0,
      upsellAmount: 0.0,
      totalAmount: 50000.0,
      clientDeliveryFee: 3000.0,
      status: 'delivered',
      paymentType: 'cod',
      paymentStatus: 'paid',
      remittanceStatus: 'remitted',
      remittedAt: now.subtract(const Duration(days: 2)),
      deliveredAt: now.subtract(const Duration(days: 2)),
      productName: 'Herbal Detox Tea',
      productSku: 'HDT-01',
      createdAt: now.subtract(const Duration(days: 3)),
    );

    final deliveredInCustody = OrderEntity(
      id: 'ord-2',
      orderNumber: 'NOV-002',
      customerName: 'Chidi Okafor',
      customerPhone: '08087654321',
      deliveryAddress: 'Ikeja, Lagos',
      deliveryState: 'Lagos',
      deliveryCity: 'Lagos',
      quantity: 1,
      basePrice: 70000.0,
      upsellAmount: 0.0,
      totalAmount: 70000.0,
      clientDeliveryFee: 4000.0,
      status: 'delivered',
      paymentType: 'cod',
      paymentStatus: 'paid',
      remittanceStatus: 'unremitted',
      deliveredAt: now.subtract(const Duration(hours: 2)),
      productName: 'Herbal Detox Tea',
      productSku: 'HDT-01',
      createdAt: now.subtract(const Duration(hours: 10)),
    );

    final inTransit = OrderEntity(
      id: 'ord-3',
      orderNumber: 'NOV-003',
      customerName: 'Kalu Nwosu',
      customerPhone: '08033445566',
      deliveryAddress: 'Garki, Abuja',
      deliveryState: 'FCT',
      deliveryCity: 'Abuja',
      quantity: 1,
      basePrice: 60000.0,
      upsellAmount: 0.0,
      totalAmount: 60000.0,
      clientDeliveryFee: 3000.0,
      status: 'in_transit',
      paymentType: 'cod',
      paymentStatus: 'pending',
      remittanceStatus: 'unremitted',
      productName: 'Herbal Detox Tea',
      productSku: 'HDT-01',
      createdAt: now.subtract(const Duration(hours: 5)),
    );

    final outForDelivery = OrderEntity(
      id: 'ord-4',
      orderNumber: 'NOV-004',
      customerName: 'Fatima Musa',
      customerPhone: '08055667788',
      deliveryAddress: 'Maitama, Abuja',
      deliveryState: 'FCT',
      deliveryCity: 'Abuja',
      quantity: 1,
      basePrice: 40000.0,
      upsellAmount: 0.0,
      totalAmount: 40000.0,
      clientDeliveryFee: 3000.0,
      status: 'out_for_delivery',
      paymentType: 'cod',
      paymentStatus: 'pending',
      remittanceStatus: 'unremitted',
      productName: 'Slimming Coffee',
      productSku: 'SLC-02',
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final directTransferDelivered = OrderEntity(
      id: 'ord-5',
      orderNumber: 'NOV-005',
      customerName: 'Emeka Eze',
      customerPhone: '08099887766',
      deliveryAddress: 'Lekki Phase 1, Lagos',
      deliveryState: 'Lagos',
      deliveryCity: 'Lagos',
      quantity: 1,
      basePrice: 100000.0,
      upsellAmount: 0.0,
      totalAmount: 100000.0,
      clientDeliveryFee: 5000.0,
      status: 'delivered',
      paymentType: 'direct_transfer',
      paymentStatus: 'paid',
      remittanceStatus: 'remitted',
      financialSettlementStatus: 'client_settled',
      deliveredAt: now.subtract(const Duration(hours: 4)),
      productName: 'Slimming Coffee',
      productSku: 'SLC-02',
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final cancelledOrder = OrderEntity(
      id: 'ord-6',
      orderNumber: 'NOV-006',
      customerName: 'Bisi Akande',
      customerPhone: '08011224455',
      deliveryAddress: 'Surulere, Lagos',
      deliveryState: 'Lagos',
      deliveryCity: 'Lagos',
      quantity: 1,
      basePrice: 30000.0,
      upsellAmount: 0.0,
      totalAmount: 30000.0,
      clientDeliveryFee: 3000.0,
      status: 'cancelled',
      paymentType: 'cod',
      paymentStatus: 'pending',
      remittanceStatus: 'unremitted',
      productName: 'Herbal Detox Tea',
      productSku: 'HDT-01',
      createdAt: now.subtract(const Duration(days: 2)),
    );

    final List<OrderEntity> allOrders = [
      deliveredAndRemitted,
      deliveredInCustody,
      inTransit,
      outForDelivery,
      directTransferDelivered,
      cancelledOrder,
    ];

    test('calculates general finance aggregate across all products', () {
      final summary = ClientProductFinanceSummary.calculate(
        orders: allOrders,
      );

      expect(summary.totalOrders, 6);
      expect(summary.deliveredOrders, 3);
      expect(summary.inTransitOrders, 2); // in_transit + out_for_delivery
      expect(summary.failedOrders, 1);

      // Money outside in the field (COD on active orders: ord-3: 60,000 + ord-4: 40,000)
      expect(summary.moneyOutside, 100000.0);

      // In DC custody awaiting remittance:
      // ord-2 (COD delivered, not remitted): total 70,000 - fee 4,000 = 66,000
      // ord-5 is direct_transfer (prepaid directly to client account, not held in DC cash custody)
      expect(summary.awaitingRemittance, 66000.0);

      // Remitted to Bank:
      // ord-1 (COD delivered, remitted): total 50,000 - fee 3,000 = 47,000
      // ord-5 (direct transfer settled): total 100,000 - fee 5,000 = 95,000
      expect(summary.remittedToBank, 47000.0 + 95000.0);

      // Gross GMV delivered: ord-1 (50k) + ord-2 (70k) + ord-5 (100k) = 220,000
      expect(summary.grossDeliveredValue, 220000.0);

      // Logistics fees on delivered orders: ord-1 (3k) + ord-2 (4k) + ord-5 (5k) = 12,000
      expect(summary.logisticsDeliveryFees, 12000.0);

      // Net Realized Take-Home: 220,000 - 12,000 = 208,000
      expect(summary.netRealizedRevenue, 208000.0);

      // Success Rate: 3 delivered / (6 - 2 in transit) = 3 / 4 = 75%
      expect(summary.deliverySuccessRate, 75.0);
    });

    test('calculates scoped metrics when filtered to specific product', () {
      final List<OrderEntity> teaOrders = allOrders.where((o) => o.productSku == 'HDT-01').toList();

      final teaSummary = ClientProductFinanceSummary.calculate(
        orders: teaOrders,
        productName: 'Herbal Detox Tea',
        productSku: 'HDT-01',
      );

      expect(teaSummary.totalOrders, 4);
      expect(teaSummary.deliveredOrders, 2); // ord-1, ord-2
      expect(teaSummary.inTransitOrders, 1); // ord-3
      expect(teaSummary.failedOrders, 1); // ord-6

      // Money outside for Tea: ord-3 (60,000)
      expect(teaSummary.moneyOutside, 60000.0);

      // Custody for Tea: ord-2 (70k - 4k = 66,000)
      expect(teaSummary.awaitingRemittance, 66000.0);

      // Remitted to Bank for Tea: ord-1 (50k - 3k = 47,000)
      expect(teaSummary.remittedToBank, 47000.0);

      // Gross GMV for Tea: 50,000 + 70,000 = 120,000
      expect(teaSummary.grossDeliveredValue, 120000.0);

      // Logistics fees: 3,000 + 4,000 = 7,000
      expect(teaSummary.logisticsDeliveryFees, 7000.0);

      // Net Realized: 120,000 - 7,000 = 113,000
      expect(teaSummary.netRealizedRevenue, 113000.0);
    });
  });
}
