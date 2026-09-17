import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';

void main() {
  test('OrderModel and ClientSettlement parse Supabase live payloads seamlessly', () {
    final rawOrder = {
      'id': '00000000-0000-4000-8000-999999001003',
      'order_number': 'ORD-NOV-1003',
      'client_id': '00000000-0000-4000-8000-789382731303',
      'customer_name': 'Hauwa Abubakar',
      'customer_phone': '08099887766',
      'delivery_state': 'Federal Capital Territory',
      'delivery_city': 'Abuja',
      'delivery_address': 'Plot 102, Gwarinpa Estate',
      'status': 'delivered',
      'remittance_status': 'remitted',
      'financial_settlement_status': 'client_settled',
      'total_amount': 27500.0,
      'base_price': 25000.0,
      'upsell_amount': 2500.0,
      'quantity': 1,
      'client_delivery_fee': 5000.0,
      'payment_method': 'cash',
      'payment_status': 'collected',
      'created_at': '2026-09-14T10:00:00Z',
      'delivered_at': '2026-09-14T14:30:00Z',
    };

    final order = OrderModel.fromJson(rawOrder);
    expect(order.orderNumber, equals('ORD-NOV-1003'));
    expect(order.isClientSettled, isTrue);
    expect(order.isDelivered, isTrue);

    final rawSettlement = {
      'id': '33401d2b-0646-404b-9c0b-21187718a4a4',
      'settlement_number': 'SETTLE-20260917-33401d',
      'client_id': '00000000-0000-4000-8000-789382731303',
      'total_orders_count': 2,
      'gross_collections': 79000.0,
      'logistics_fees_deducted': 10000.0,
      'net_payout_amount': 67800.0,
      'charges_breakdown': {
        'rate_basis': {'delivery_fee_per_order': 5000.0},
        'delivery_fees': 10000.0,
        'platform_fees': 1200.0,
        'total_deductions': 11200.0,
      },
      'status': 'completed',
      'settled_at': '2026-09-17T11:03:45Z',
      'created_at': '2026-09-17T11:03:45Z',
    };

    final settlement = ClientSettlement.fromJson(rawSettlement);
    expect(settlement.settlementNumber, equals('SETTLE-20260917-33401d'));
    expect(settlement.totalOrdersCount, equals(2));
    expect(settlement.netPayoutAmount, equals(67800.0));
    expect(settlement.chargesBreakdown['delivery_fees'], equals(10000.0));
  });
}
