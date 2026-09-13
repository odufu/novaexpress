import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Finance Architecture Remediation & Settlement Tests', () {
    test('ClientSettlement model deserializes all itemized charges without null-pointer errors', () {
      final sampleJson = {
        'id': 'settle-uuid-001',
        'settlement_number': 'SETTLE-2026-09-13-1001',
        'client_id': 'client-uuid-001',
        'company_id': '11111111-1111-4111-8111-111111111111',
        'distribution_center_id': 'dc-uuid-001',
        'period_start': '2026-09-12T22:00:00.000Z',
        'period_end': '2026-09-13T22:00:00.000Z',
        'total_orders_count': 10,
        'gross_collections': 250000.00,
        'logistics_fees_deducted': 35000.00,
        'platform_fees_deducted': 5000.00,
        'gateway_fees_deducted': 1875.00,
        'failed_attempt_fees_deducted': 1000.00,
        'other_charges_deducted': 0.00,
        'net_payout_amount': 207125.00,
        'charges_breakdown': {
          'base_delivery_fee': 3500.0,
          'platform_rate': 'flat_500',
          'gateway_rate': '1.5%_capped',
        },
        'destination_bank_name': 'Access Bank',
        'destination_account_number': '0123456789',
        'destination_account_name': 'Acme Stores Enterprise',
        'payout_reference': 'TRX-PAYOUT-998822',
        'status': 'completed',
        'settled_at': '2026-09-13T22:05:00.000Z',
        'created_at': '2026-09-13T22:05:00.000Z',
      };

      final settlement = ClientSettlement.fromJson(sampleJson);

      expect(settlement.settlementNumber, 'SETTLE-2026-09-13-1001');
      expect(settlement.grossCollections, 250000.00);
      expect(settlement.logisticsFeesDeducted, 35000.00);
      expect(settlement.platformFeesDeducted, 5000.00);
      expect(settlement.gatewayFeesDeducted, 1875.00);
      expect(settlement.failedAttemptFeesDeducted, 1000.00);
      expect(settlement.netPayoutAmount, 207125.00);
      expect(settlement.chargesBreakdown['platform_rate'], 'flat_500');
    });

    test('ClientProductFinanceSummary.calculate correctly deducts delivery fees for prepaid direct orders', () {
      final order1 = OrderEntity(
        id: 'ord-1',
        orderNumber: 'NVX-001',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryAddress: 'Lekki Phase 1',
        deliveryCity: 'Lekki',
        deliveryState: 'Lagos',
        quantity: 1,
        basePrice: 30000.00,
        upsellAmount: 0.0,
        totalAmount: 30000.00,
        status: 'delivered',
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final order2 = OrderEntity(
        id: 'ord-2',
        orderNumber: 'NVX-002',
        customerName: 'Customer B',
        customerPhone: '08022222222',
        deliveryAddress: 'Ikeja GRA',
        deliveryCity: 'Ikeja',
        deliveryState: 'Lagos',
        quantity: 1,
        basePrice: 20000.00,
        upsellAmount: 0.0,
        totalAmount: 20000.00,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final summary = ClientProductFinanceSummary.calculate(orders: [order1, order2]);

      expect(summary.totalOrders, 2);
      expect(summary.deliveredOrders, 2);
      expect(summary.grossDeliveredValue, 50000.00);
      expect(summary.logisticsDeliveryFees, 7000.00);

      // Total net realized revenue = 50,000 - 7,000 = 43,000
      expect(summary.netRealizedRevenue, 43000.00);

      // Both orders are un-remitted awaiting 10 PM closeout:
      // ord-1 net = 30,000 - 3,500 = 26,500
      // ord-2 net = 20,000 - 3,500 = 16,500
      // Total awaiting remittance = 43,000
      expect(summary.awaitingRemittance, 43000.00);
      expect(summary.remittedToBank, 0.00);
    });

    test('ClientProductFinanceSummary.calculate accurately moves settled orders to remittedToBank', () {
      final order = OrderEntity(
        id: 'ord-settled-1',
        orderNumber: 'NVX-003',
        customerName: 'Customer C',
        customerPhone: '08033333333',
        deliveryAddress: 'Victoria Island',
        deliveryCity: 'Lagos',
        deliveryState: 'Lagos',
        quantity: 1,
        basePrice: 40000.00,
        upsellAmount: 0.0,
        totalAmount: 40000.00,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'remitted',
        financialSettlementStatus: 'client_settled',
        createdAt: DateTime.now(),
      );

      final summary = ClientProductFinanceSummary.calculate(orders: [order]);

      expect(summary.deliveredOrders, 1);
      expect(summary.awaitingRemittance, 0.00);
      expect(summary.remittedToBank, 36500.00); // 40,000 - 3,500
      expect(summary.logisticsDeliveryFees, 3500.00);
    });
  });
}
