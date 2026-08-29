import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_order_payment_matching_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Remittance Financial Accuracy & Batch Calculation Tests', () {
    const user = UserEntity(
      id: 'c32c038f-ff3d-4a4f-867d-a749092fb2a9',
      email: 'joel.odufu@novaexpress.ng',
      phone: '08031234567',
      firstName: 'Joel',
      lastName: 'Odufu',
      role: 'delivery_agent',
      deliveryAgentId: 'c32c038f-ff3d-4a4f-867d-a749092fb2a9',
      commissionRate: 1000.0,
      transportAllowance: 1500.0,
      failedDeliveryAllowance: 500.0,
      personnelType: 'pda',
    );

    final order1 = OrderEntity(
      id: 'ord-1',
      orderNumber: 'TRK-6562',
      customerName: 'Amina Yusuf',
      customerPhone: '08012345678',
      deliveryState: 'Abuja',
      deliveryCity: 'Garki',
      deliveryAddress: 'Plot 12, Area 3',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 55000.0,
      upsellAmount: 0.0,
      totalAmount: 55000.0,
      paymentType: 'pod',
      paymentStatus: 'collected',
      deliveryNotes: '[POD Collected via Cash] Cash in custody.',
      agentEntitlement: 1000.0,
      transportFee: 1500.0,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

    final order2 = OrderEntity(
      id: 'ord-2',
      orderNumber: 'TRK-6350',
      customerName: 'Babatunde Fashola',
      customerPhone: '08098765432',
      deliveryState: 'Abuja',
      deliveryCity: 'Wuse 2',
      deliveryAddress: 'Adetokunbo Ademola Crescent',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 55000.0,
      upsellAmount: 0.0,
      totalAmount: 55000.0,
      paymentType: 'pod',
      paymentStatus: 'collected',
      deliveryNotes: '[POD Collected via Cash] Cash in custody.',
      agentEntitlement: 1000.0,
      transportFee: 1500.0,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    final order3 = OrderEntity(
      id: 'ord-3',
      orderNumber: 'TRK-5569',
      customerName: 'Chioma Okeke',
      customerPhone: '08123456789',
      deliveryState: 'Abuja',
      deliveryCity: 'Maitama',
      deliveryAddress: 'Gana Street',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      paymentType: 'paystack',
      paymentStatus: 'transfer_verified',
      deliveryNotes: '[POD Paid via Paystack Direct Transfer]',
      agentEntitlement: 1000.0,
      transportFee: 1500.0,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    test('FinancialSummary computes unremitted cash accurately without phantom ₦1500', () {
      final summary = FinancialSummary.calculate(
        orders: [order1, order2, order3],
        remittances: [],
        user: user,
      );

      // Total Cash POD Collected: 55,000 + 55,000 = 110,000
      expect(summary.cashCollectedAllTime, equals(110000.0));
      // Total Commission Retained: 2 * 1,000 = 2,000
      expect(summary.totalCommissionRetained, equals(2000.0));
      // Total Transport Retained: 2 * 1,500 = 3,000
      expect(summary.totalTransportRetained, equals(3000.0));
      // Pending Remittance to DC: 110,000 - 2,000 - 3,000 = 105,000
      expect(summary.pendingRemittanceToDC, equals(105000.0));
    });

    test('Pending Remittance to DC clears completely to 0.00 when orders are remitted', () {
      final remittedOrder1 = order1.copyWith(
        remittanceStatus: 'remitted',
        deliveryNotes: '[POD Collected via Cash] [REMITTED: PSTK-RMT-PDA7182-123456 | Amount: ₦105000]',
      );
      final remittedOrder2 = order2.copyWith(
        remittanceStatus: 'remitted',
        deliveryNotes: '[POD Collected via Cash] [REMITTED: PSTK-RMT-PDA7182-123456 | Amount: ₦105000]',
      );

      final remittance = RemittanceEntity(
        id: 'rem-1',
        referenceNumber: 'PSTK-RMT-PDA7182-123456',
        amount: 105000.0,
        grossCollections: 110000.0,
        commissionDeducted: 2000.0,
        transportAllowanceDeducted: 3000.0,
        paymentMethod: 'paystack',
        status: 'verified',
        createdAt: DateTime.now(),
        verifiedAt: DateTime.now(),
      );

      final summary = FinancialSummary.calculate(
        orders: [remittedOrder1, remittedOrder2, order3],
        remittances: [remittance],
        user: user,
      );

      // Pending Cash in Custody MUST be exactly 0.0
      expect(summary.pendingRemittanceToDC, equals(0.0));
    });

    test('RemittanceOrderItem correctly calculates net contribution to DC', () {
      final item = RemittanceOrderItem(
        orderId: 'ord-1',
        orderNumber: 'TRK-6562',
        customerName: 'Amina Yusuf',
        status: 'delivered',
        paymentType: 'pod',
        cashCollected: 55000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        failedStipend: 0.0,
        date: DateTime.now(),
      );

      expect(item.isDelivered, isTrue);
      expect(item.netToDC, equals(52500.0));
    });

    test('DC Console lifecycle generator captures Paystack cash remittances and links orders', () {
      const page = DCOrderPaymentMatchingPage();
      final pageState = page.createState();

      final paystackRemittance = RemittanceEntity(
        id: 'rem-pstk-7182',
        referenceNumber: 'PSTK-RMT-PDA7182-699122',
        amount: 105000.0,
        grossCollections: 110000.0,
        commissionDeducted: 2000.0,
        transportAllowanceDeducted: 3000.0,
        paymentMethod: 'paystack',
        status: 'verified',
        deliveryAgentId: user.id,
        notes: '[PAYSTACK] Ref: PSTK-RMT-PDA7182-699122 [Orders: TRK-6562, TRK-6350]',
        createdAt: DateTime.now(),
        verifiedAt: DateTime.now(),
        associatedOrders: [
          RemittanceOrderItem(
            orderId: order1.id,
            orderNumber: order1.orderNumber,
            customerName: order1.customerName,
            status: order1.status,
            paymentType: order1.paymentType,
            cashCollected: order1.totalAmount,
            riderCommission: 1000.0,
            transportAllowance: 1500.0,
            date: order1.createdAt,
          ),
          RemittanceOrderItem(
            orderId: order2.id,
            orderNumber: order2.orderNumber,
            customerName: order2.customerName,
            status: order2.status,
            paymentType: order2.paymentType,
            cashCollected: order2.totalAmount,
            riderCommission: 1000.0,
            transportAllowance: 1500.0,
            date: order2.createdAt,
          ),
        ],
      );

      const driver = DCFleetDriver(
        id: 'c32c038f-ff3d-4a4f-867d-a749092fb2a9',
        name: 'Joel Odufu',
        driverCode: 'PDA-7182',
        phone: '08031234567',
        avatarUrl: '',
        vehicleModel: 'Honda Ace 125',
        vehiclePlate: 'ABC-123-XY',
        vehicleType: 'motorcycle',
        status: 'active',
        assignedZone: 'Abuja Central',
        totalAssignedOrders: 10,
        completedOrders: 8,
        routeProgressPercent: 80.0,
        efficiencyRating: 4.9,
        cashInCustody: 105000.0,
        itemsInCustody: 2,
      );

      const dcState = DCConsoleState(
        drivers: [driver],
      );

      final items = pageState.buildRemittanceLifecycleItemsForTest(
        [order1, order2, order3],
        [paystackRemittance],
        dcState,
      );

      // Verify that the Paystack remittance item is present
      final cashRemittanceItem = items.firstWhere((it) => it.referenceNumber == 'PSTK-RMT-PDA7182-699122');
      expect(cashRemittanceItem, isNotNull);
      expect(cashRemittanceItem.type, equals('cash_pod'));
      expect(cashRemittanceItem.grossAmount, equals(110000.0));
      expect(cashRemittanceItem.netAmount, equals(105000.0));
      expect(cashRemittanceItem.commissionAmount, equals(2000.0));
      expect(cashRemittanceItem.transportAllowance, equals(3000.0));
      expect(cashRemittanceItem.orders.length, equals(2));
      expect(cashRemittanceItem.orders.map((o) => o.orderNumber), containsAll(['TRK-6562', 'TRK-6350']));
    });
  });
}
