import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );
  });

  test('Diagnose live rider profile, stock, orders, and remittance reconciliation', () async {
    final client = Supabase.instance.client;
    final authDatasource = AuthRemoteDataSourceImpl(client);
    final ordersDatasource = OrdersRemoteDataSourceImpl(client);
    final stockDatasource = StockRemoteDataSourceImpl(supabaseClient: client);
    final financeDatasource = FinanceRemoteDataSourceImpl(client);

    print('\n========================================');
    print('1. AUTH DIAGNOSIS FOR JOEL ODUFU');
    print('========================================');
    
    // Check user in database
    final userRes = await client.from('users').select().ilike('email', '%joel%');
    print('Users matching joel: $userRes');

    final agentRes = await client.from('delivery_agents').select().or('agent_code.ilike.%7182%,user_id.eq.44ce8d3c-9f96-45d2-a051-2d1b9463cd10,id.eq.c32c038f-ff3d-4a4f-867d-a749092fb2a9');
    print('Agents matching joel: $agentRes');

    // Simulate login for joel
    final loggedInUser = await authDatasource.login('joel.odufu@novaexpress.ng', 'Password123!');
    print('\nLogged in UserModel:');
    print('  id: ${loggedInUser.id}');
    print('  email: ${loggedInUser.email}');
    print('  deliveryAgentId: ${loggedInUser.deliveryAgentId}');
    print('  deliveryAgentCode: ${loggedInUser.deliveryAgentCode}');

    final targetAgentId = loggedInUser.deliveryAgentId ?? loggedInUser.id;
    print('\nTarget Agent ID for queries: $targetAgentId');

    print('\n========================================');
    print('2. STOCK DIAGNOSIS FOR AGENT: $targetAgentId');
    print('========================================');
    final stockItems = await stockDatasource.getVehicleStockItems(targetAgentId);
    print('Stock Items Count: ${stockItems.length}');
    for (final it in stockItems) {
      print('  📦 ${it.name}: Available=${it.availableCount}, Assigned=${it.assignedCount}, Delivered=${it.deliveredCount}');
    }

    print('\n========================================');
    print('3. ORDERS DIAGNOSIS FOR AGENT: $targetAgentId');
    print('========================================');
    final orders = await ordersDatasource.getAssignedOrders(targetAgentId);
    print('Orders Count: ${orders.length}');
    final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
    final deliveredCash = deliveredOrders.where((o) => o.isCashPod).toList();
    print('Delivered Cash Orders Count: ${deliveredCash.length}');
    double sumDeliveredCash = 0;
    for (final o in deliveredCash) {
      sumDeliveredCash += o.totalAmount;
    }
    print('Sum Delivered Cash: ₦$sumDeliveredCash');

    print('\n========================================');
    print('4. REMITTANCE DIAGNOSIS FOR AGENT: $targetAgentId');
    print('========================================');
    final remittances = await financeDatasource.getAgentRemittances(targetAgentId);
    print('Remittances Count: ${remittances.length}');
    for (final r in remittances) {
      print('  💵 Remittance #${r.id} (${r.referenceNumber}): Amount=₦${r.amount}, Status=${r.status}, isVerified=${r.isVerified}, Date=${r.createdAt}');
    }

    print('\n========================================');
    print('5. FINANCIAL SUMMARY CALCULATION');
    print('========================================');
    final summary = FinancialSummary.calculate(
      orders: orders,
      remittances: remittances,
      user: loggedInUser,
    );
    print('Cash Collected (All Time): ₦${summary.cashCollectedAllTime}');
    print('Total Remitted (All Time): ₦${summary.totalRemittedAllTime}');
    print('Commission Retained: ₦${summary.totalCommissionRetained}');
    print('Transport Retained: ₦${summary.totalTransportRetained}');
    print('Pending Remittance to DC: ₦${summary.pendingRemittanceToDC}');
    print('========================================\n');
  });
}
