import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Negotiated Operational Charges & 3-Way Split Tests', () {
    test('DCFinanceSettings defaults reflect negotiated operational standards (5000, 1000, 500)', () {
      const settings = DCFinanceSettings();

      expect(settings.defaultClientDeliveryFee, 5000.0);
      expect(settings.failedOrderCharge, 1000.0);
      expect(settings.platformFeeValue, 500.0);

      final deserialized = DCFinanceSettings.fromJson({});
      expect(deserialized.defaultClientDeliveryFee, 5000.0);
      expect(deserialized.failedOrderCharge, 1000.0);
      expect(deserialized.platformFeeValue, 500.0);
    });

    test('ClientPortalState accurately computes standard Novacare tariffs with ZERO variance', () {
      const novacareProfile = ClientProfile(
        id: 'client-novacare-001',
        companyName: 'Novacare Health & Wellness',
        contactPerson: 'Joel Novacare',
        phone: '08012345678',
        email: 'billing@novacare.ng',
        address: 'Wuse 2, Abuja',
        customDeliveryFee: 5000.0,
        customFailedAttemptFee: 1000.0,
        customPlatformFeeValue: 500.0,
        bankName: 'Access Bank',
        accountNumber: '0123456789',
        accountName: 'Novacare Health Ltd',
      );

      final now = DateTime.now();

      // 4 Delivered Orders (Gross = 35k + 45k + 50k + 56.5k = 186,500)
      final deliveredOrders = [
        OrderEntity(
          id: 'ord-1',
          orderNumber: 'NVX-001',
          customerName: 'Customer 1',
          customerPhone: '08011111111',
          deliveryAddress: 'Wuse 2',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 35000.0,
          upsellAmount: 0.0,
          totalAmount: 35000.0,
          status: 'delivered',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-2',
          orderNumber: 'NVX-002',
          customerName: 'Customer 2',
          customerPhone: '08022222222',
          deliveryAddress: 'Maitama',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 45000.0,
          upsellAmount: 0.0,
          totalAmount: 45000.0,
          status: 'delivered',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-3',
          orderNumber: 'NVX-003',
          customerName: 'Customer 3',
          customerPhone: '08033333333',
          deliveryAddress: 'Garki',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 2,
          basePrice: 50000.0,
          upsellAmount: 0.0,
          totalAmount: 50000.0,
          status: 'delivered',
          deliveredAt: now,
          paymentType: 'prepaid',
          paymentStatus: 'paid',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-4',
          orderNumber: 'NVX-004',
          customerName: 'Customer 4',
          customerPhone: '08044444444',
          deliveryAddress: 'Jabi',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 56500.0,
          upsellAmount: 0.0,
          totalAmount: 56500.0,
          status: 'delivered',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          createdAt: now,
        ),
      ];

      // 1 Failed Order
      final failedOrders = [
        OrderEntity(
          id: 'ord-5',
          orderNumber: 'NVX-005',
          customerName: 'Customer 5',
          customerPhone: '08055555555',
          deliveryAddress: 'Kubwa',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 30000.0,
          upsellAmount: 0.0,
          totalAmount: 30000.0,
          status: 'failed',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'failed',
          createdAt: now,
        ),
      ];

      final state = ClientPortalState(
        clientProfile: novacareProfile,
        orders: [...deliveredOrders, ...failedOrders],
      );

      // Verify Gross Cash Holding
      expect(state.todayGrossCashHolding, 186500.0);
      expect(state.todayCompletedOrdersCount, 4);

      // 1. Delivery Fees: 4 successful deliveries * 5,000 = 20,000
      expect(state.todayLogisticsDeliveryFees, 20000.0);

      // 2. Failed Delivery Fee: 1 failed delivery * 1,000 = 1,000
      expect(state.todayFailedOrdersCount, 1);
      expect(state.todayFailedAttemptFees, 1000.0);

      // 3. Platform Charges:
      // ord-3 is prepaid (50,000 * 0.015 = 750)
      expect(state.todayThirdPartySwitchFees, 750.0);
      // 4 delivered orders * 500 = 2,000 dedicated system operation charge
      expect(state.todaySystemOperationCharges, 2000.0);
      // Total Platform Charge = 750 + 2000 = 2750.0
      expect(state.todayPlatformClearingFees, 2750.0);

      // Total Charges Deducted = 20,000 + 1,000 + 2,750 = 23,750
      expect(state.todayTotalChargesDeducted, 23750.0);

      // Net Expected Payout = 186,500 - 23,750 = 162,750
      expect(state.todayNetExpectedPayout, 162750.0);

      // ZERO VARIANCE CHECK
      final totalAccounted = state.todayNetExpectedPayout +
          state.todayLogisticsDeliveryFees +
          state.todayFailedAttemptFees +
          state.todayPlatformClearingFees;

      expect(totalAccounted, state.todayGrossCashHolding);
    });

    test('ClientPortalState dynamically adapts when custom negotiated tariffs are changed', () {
      const premiumProfile = ClientProfile(
        id: 'client-premium-001',
        companyName: 'VIP Merchant Ltd',
        contactPerson: 'VIP Merchant',
        phone: '08099999999',
        email: 'vip@merchant.ng',
        address: 'Asokoro, Abuja',
        customDeliveryFee: 6500.0, // Negotiated custom 6,500
        customFailedAttemptFee: 1500.0, // Negotiated custom 1,500
        customPlatformFeeValue: 800.0, // Negotiated custom 800
      );

      final now = DateTime.now();
      final orders = [
        OrderEntity(
          id: 'vip-ord-1',
          orderNumber: 'VIP-001',
          customerName: 'VIP Customer 1',
          customerPhone: '08011111111',
          deliveryAddress: 'Asokoro',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 100000.0,
          upsellAmount: 0.0,
          totalAmount: 100000.0,
          status: 'delivered',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          createdAt: now,
        ),
        OrderEntity(
          id: 'vip-ord-2',
          orderNumber: 'VIP-002',
          customerName: 'VIP Customer 2',
          customerPhone: '08022222222',
          deliveryAddress: 'Maitama',
          deliveryCity: 'Abuja',
          deliveryState: 'FCT',
          quantity: 1,
          basePrice: 50000.0,
          upsellAmount: 0.0,
          totalAmount: 50000.0,
          status: 'failed',
          deliveredAt: now,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'failed',
          createdAt: now,
        ),
      ];

      final state = ClientPortalState(
        clientProfile: premiumProfile,
        orders: orders,
      );

      expect(state.todayGrossCashHolding, 100000.0);
      expect(state.todayLogisticsDeliveryFees, 6500.0); // 1 * 6,500
      expect(state.todayFailedAttemptFees, 1500.0); // 1 * 1,500
      expect(state.todayPlatformClearingFees, 800.0); // 1 * 800

      // Net Expected Payout = 100,000 - (6,500 + 1,500 + 800) = 91,200
      expect(state.todayNetExpectedPayout, 91200.0);

      // Zero-variance validation
      expect(
        state.todayNetExpectedPayout +
            state.todayLogisticsDeliveryFees +
            state.todayFailedAttemptFees +
            state.todayPlatformClearingFees,
        state.todayGrossCashHolding,
      );
    });

    test('ClientSettlement model deserializes charges breakdown and financial balances', () {
      final json = {
        'id': 'settle-1234',
        'settlement_number': 'SETTLE-2026-09-16-0001',
        'client_id': 'client-novacare-001',
        'company_id': '11111111-1111-4111-8111-111111111111',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        'period_start': '2026-09-15T22:00:00.000Z',
        'period_end': '2026-09-16T22:00:00.000Z',
        'total_orders_count': 4,
        'gross_collections': 186500.00,
        'logistics_fees_deducted': 20000.00,
        'failed_attempt_fees_deducted': 0.00,
        'platform_fees_deducted': 2000.00,
        'gateway_fees_deducted': 200.00,
        'other_charges_deducted': 0.00,
        'net_payout_amount': 164500.00,
        'charges_breakdown': {
          'rate_per_delivery': 5000.0,
          'rate_per_failed_attempt': 1000.0,
          'platform_charge_rate': 500.0,
          'system_operation_charge': 1800.0,
          'third_party_switch_fee': 200.0,
          'app_operational_finance_note': 'Platform maintenance, tech engineering team & feature upgrades',
        },
        'destination_bank_name': 'Access Bank',
        'destination_account_number': '0123456789',
        'destination_account_name': 'Novacare Health Ltd',
        'status': 'pending',
        'created_at': '2026-09-16T22:00:00.000Z',
      };

      final settlement = ClientSettlement.fromJson(json);

      expect(settlement.grossCollections, 186500.0);
      expect(settlement.logisticsFeesDeducted, 20000.0);
      expect(settlement.platformFeesDeducted, 2000.0);
      expect(settlement.netPayoutAmount, 164500.0);
      expect(settlement.chargesBreakdown['rate_per_delivery'], 5000.0);
      expect(settlement.chargesBreakdown['system_operation_charge'], 1800.0);
      expect(settlement.chargesBreakdown['third_party_switch_fee'], 200.0);
      expect(
        settlement.chargesBreakdown['app_operational_finance_note'],
        contains('Platform maintenance'),
      );
    });
  });
}
