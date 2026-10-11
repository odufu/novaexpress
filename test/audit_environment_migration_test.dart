import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  test('Comprehensive Audit: Current Testing (qpcafevjsrbauweuiiyq) vs Original Production (oygtaeriljuelhshfvkv)', () async {
    final clientTesting = SupabaseClient(
      SupabaseConstants.testingUrl,
      SupabaseConstants.testingServiceRoleKey,
    );

    final clientOriginal = SupabaseClient(
      SupabaseConstants.originalUrl,
      SupabaseConstants.originalServiceRoleKey,
    );

    final tables = [
      'companies',
      'distribution_centers',
      'clients',
      'users',
      'delivery_agents',
      'products',
      'product_packages',
      'client_closers',
      'client_marketers',
      'lead_forms',
      'customer_leads',
      'orders',
      'order_items',
      'order_conversations',
      'order_conversation_messages',
      'cash_remittances',
      'notifications',
      'client_suppliers',
      'client_stock_invoices',
      'client_stock_balances',
      'stock_holder_custody',
      'stock_transfers',
      'stock_transfer_items',
      'client_marketer_payouts',
      'client_closer_payouts',
      'client_settlements',
      'paystack_transactions',
      'paystack_virtual_accounts',
    ];

    print('=' * 80);
    print('AUDIT REPORT: SUPABASE TABLES & DATA COMPARISON');
    print('=' * 80);
    print(
      '${'TABLE NAME'.padRight(30)} | ${'TESTING (Current)'.padRight(22)} | ${'ORIGINAL (Target)'.padRight(22)}',
    );
    print('-' * 80);

    final missingInOriginal = <String>[];
    final hasDataInTesting = <String, int>{};

    for (final table in tables) {
      String countTestingStr = '0';
      int countTesting = 0;
      try {
        final res1 = await clientTesting.from(table).select('count').count(CountOption.exact);
        countTesting = res1.count;
        countTestingStr = '${res1.count} rows';
        if (countTesting > 0) {
          hasDataInTesting[table] = countTesting;
        }
      } catch (e) {
        countTestingStr = 'ERR (Missing)';
      }

      String countOriginalStr = '0';
      try {
        final res2 = await clientOriginal.from(table).select('count').count(CountOption.exact);
        countOriginalStr = '${res2.count} rows';
      } catch (e) {
        countOriginalStr = 'MISSING (404)';
        missingInOriginal.add(table);
      }

      print(
        '${table.padRight(30)} | ${countTestingStr.padRight(22)} | ${countOriginalStr.padRight(22)}',
      );
    }

    print('\n' + '=' * 80);
    print('AUDIT SUMMARY: SCHEMA GAPS IN ORIGINAL');
    print('=' * 80);
    print('Tables missing in Original (oygtaeriljuelhshfvkv): ${missingInOriginal.length}');
    for (final m in missingInOriginal) {
      print('  • $m');
    }

    print('\n' + '=' * 80);
    print('DATA TO PRESERVE / MIGRATE FROM TESTING TO ORIGINAL');
    print('=' * 80);
    hasDataInTesting.forEach((tbl, count) {
      print('  • $tbl: $count active records');
    });

    // Storage Buckets check
    print('\n' + '=' * 80);
    print('STORAGE BUCKETS COMPARISON');
    print('=' * 80);
    try {
      final bucketsTesting = await clientTesting.storage.listBuckets();
      print('Testing Buckets: ${bucketsTesting.map((b) => b.id).toList()}');
    } catch (e) {
      print('Testing Buckets Error: $e');
    }

    try {
      final bucketsOriginal = await clientOriginal.storage.listBuckets();
      print('Original Buckets: ${bucketsOriginal.map((b) => b.id).toList()}');
    } catch (e) {
      print('Original Buckets Error: $e');
    }
  });
}
