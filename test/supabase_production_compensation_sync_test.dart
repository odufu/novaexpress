import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase Cloud Database Compensation & Finance Settings Live Sync Test', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    try {
      // 1. Verify dc_finance_settings table exists and can be queried
      final financeRes = await client
          .from('dc_finance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      expect(financeRes, isNotNull);
      final settings = DCFinanceSettings.fromJson(financeRes!);
      expect(settings.posChargeMode, isNotEmpty);
      expect(settings.defaultCommissionRate, equals(1000.0));
      expect(settings.defaultTransportAllowance, equals(1500.0));

      // 2. Verify delivery_agents table has the new compensation columns
      final agentsRes = await client
          .from(SupabaseConstants.deliveryAgentsTable)
          .select('id, agent_code, commission_rate, transport_allowance, failed_delivery_allowance, base_salary, personnel_type, compensation_type')
          .limit(1);

      expect(agentsRes, isNotNull);
      if (agentsRes.isNotEmpty) {
        final agentRow = agentsRes.first;
        expect(agentRow.containsKey('commission_rate'), isTrue);
        expect(agentRow.containsKey('transport_allowance'), isTrue);
        expect(agentRow.containsKey('failed_delivery_allowance'), isTrue);
        expect(agentRow.containsKey('personnel_type'), isTrue);
      }
    } finally {
      client.dispose();
    }
  });
}
