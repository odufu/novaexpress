import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Live Supabase Remote DB & Cloud Edge Functions Verification Suite', () {
    late SupabaseClient client;

    setUp(() {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
    });

    test('1. Live Remote Database: Auth Profile & Agent Resolution', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final authDatasource = AuthRemoteDataSourceImpl(client);
      final user = await authDatasource.login('rider.emeka@novaexpress.com', 'Password123!');

      expect(user.email, equals('rider.emeka@novaexpress.com'));
      expect(user.deliveryAgentCode, equals('PDA-7000'));
      expect(user.deliveryAgentId, equals('b1111111-1111-4111-8111-111111111111'));
      expect(user.distributionCenterName, contains('Wuse'));
    });

    test('2. Live Remote Database: Orders List & Relational Integrity', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final ordersDatasource = OrdersRemoteDataSourceImpl(client);
      final orders = await ordersDatasource.getAssignedOrders('b1111111-1111-4111-8111-111111111111');

      expect(orders.isNotEmpty, isTrue);
      expect(orders.length, greaterThanOrEqualTo(10));
      expect(orders.any((o) => o.customerName.isNotEmpty), isTrue);
      expect(orders.any((o) => o.totalAmount > 0), isTrue);
    });

    test('3. Live Remote Database: Vehicle Stock & Product Catalog', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final stockDatasource = StockRemoteDataSourceImpl(supabaseClient: client);
      final items = await stockDatasource.getVehicleStockItems();

      expect(items.isNotEmpty, isTrue);
      expect(items.any((i) => i.name.contains('Grazer') || i.name.contains('Respira')), isTrue);
    });

    test('4. Live Remote Database: Cash Remittances Ledger', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final financeDatasource = FinanceRemoteDataSourceImpl(client);
      final remittances = await financeDatasource.getAgentRemittances('b1111111-1111-4111-8111-111111111111');

      expect(remittances.isNotEmpty, isTrue);
      expect(remittances.any((r) => r.status == 'verified' || r.status == 'approved'), isTrue);
    });

    test('5. Live Cloud Edge Functions: Direct Invocations', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final remRes = await client.functions.invoke(
        'submit-cash-remittance',
        body: {
          'agentId': 'b1111111-1111-4111-8111-111111111111',
          'companyId': '11111111-1111-4111-8111-111111111111',
          'amount': 5000.0,
          'paymentMethod': 'bank_transfer',
          'depositReceiptUrl': 'https://novexps.storage/receipts/rec-test-live.jpg',
          'notes': 'Live automated verification',
        },
      );
      expect(remRes.status, equals(200));

      final payRes = await client.functions.invoke(
        'request-balance-payout',
        body: {
          'agentId': 'b1111111-1111-4111-8111-111111111111',
          'amount': 1500.0,
          'bankName': 'First Bank of Nigeria',
          'accountNumber': '3081294821',
          'accountName': 'Emeka Rider Logistics',
        },
      );
      expect(payRes.status, equals(200));
    });
  });
}
