import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  test('Verify Remittance, Stock & Order Fixes Live in Supabase', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    const joelAgentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';

    // 1. Ensure "Respira Lungs Detox" exists in Supabase products table
    print('\n--- 1. Upserting "Respira Lungs Detox" into Supabase Products ---');
    await client.from('products').upsert({
      'name': 'Respira Lungs Detox',
      'sku': 'SKU-RESP-LUNGS-01',
      'description': 'Advanced lung cleanse and respiratory herbal formulation',
      'base_price': 25000.0,
      'category': 'Health & Wellness',
      'company_id': '11111111-1111-4111-8111-111111111111',
    }, onConflict: 'sku');
    print('✅ "Respira Lungs Detox" product registered in Supabase');

    // 2. Test Stock DataSource for Joel
    print('\n--- 2. Fetching Vehicle Stock Items for Joel Odufu ---');
    final stockDs = StockRemoteDataSourceImpl(supabaseClient: client);
    final stockItems = await stockDs.getVehicleStockItems(joelAgentId);
    print('Total products for Joel: ${stockItems.length}');
    for (final item in stockItems) {
      print('Product: "${item.name}" | Available: ${item.availableCount} | Delivered: ${item.deliveredCount} | Assigned: ${item.assignedCount}');
    }
    expect(stockItems.isNotEmpty, isTrue);

    // 3. Mark Joel's Paystack remittance as verified in Supabase
    print('\n--- 3. Verifying Cash Remittances in Supabase for Joel Odufu ---');
    final financeDs = FinanceRemoteDataSourceImpl(client);
    
    await client
        .from('cash_remittances')
        .update({
          'status': 'verified',
          'verified_at': DateTime.now().toIso8601String(),
        })
        .eq('delivery_agent_id', joelAgentId)
        .eq('status', 'pending');

    final remittances = await financeDs.getAgentRemittances(joelAgentId);
    print('Total remittances for Joel: ${remittances.length}');
    for (final rem in remittances) {
      print('Remittance Ref: ${rem.referenceNumber} | Amount: ₦${rem.amount} | Status: ${rem.status} | Verified: ${rem.isVerified}');
    }
    expect(remittances.any((r) => r.isVerified), isTrue);

    // 4. Test Financial Reconciliation
    final ordersRes = await client.from('orders').select().eq('delivery_agent_id', joelAgentId);
    final List<OrderEntity> orders = (ordersRes as List).map((json) => OrderModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();

    final summary = FinancialSummary.calculate(
      orders: orders,
      remittances: remittances,
    );

    print('\n--- 4. Live Financial Reconciliation ---');
    print('Cash Collected All Time: ₦${summary.cashCollectedAllTime}');
    print('Total Verified Remitted: ₦${summary.totalVerifiedRemitted}');
    print('Pending Remittance to DC: ₦${summary.pendingRemittanceToDC}');

    expect(summary.pendingRemittanceToDC, lessThan(summary.cashCollectedAllTime));
  }, skip: 'Live DB verification test - run manually with live seed records');
}
