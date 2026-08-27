```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
const supabaseUrl = 'https://oygtaeriljuelhshfvkv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM';
Map<String, String> get headers => {
  'apikey': supabaseServiceKey,
  'Authorization': 'Bearer $supabaseServiceKey',
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};
void main() async {
  print('=== Querying Joel Data via Supabase REST API ===');
  final joelAgentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';
  final defaultAgentId = 'b1111111-1111-4111-8111-111111111111';
  final companyId = '11111111-1111-4111-8111-111111111111';
  // 1. Total cash collected for Joel
  final ordersUri = Uri.parse('$supabaseUrl/rest/v1/orders?or=(delivery_agent_id.eq.$joelAgentId,delivery_agent_id.eq.$defaultAgentId)&select=*');
  final ordersRes = await http.get(ordersUri, headers: headers);
  final List orders = jsonDecode(ordersRes.body);
  double totalCash = 0.0;
  for (var o in orders) {
    if (o['status']?.toString().toLowerCase() == 'delivered') {
      final pm = o['payment_method']?.toString().toLowerCase();
      if (pm == 'cash' || pm == null || pm.isEmpty) {
        totalCash += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
  }
  // 2. Existing verified remittances
  final remUri = Uri.parse('$supabaseUrl/rest/v1/cash_remittances?or=(delivery_agent_id.eq.$joelAgentId,delivery_agent_id.eq.$defaultAgentId)&select=*');
  final remRes = await http.get(remUri, headers: headers);
  final List remittances = jsonDecode(remRes.body);
  double totalRemitted = 0.0;
  for (var r in remittances) {
    final status = r['status']?.toString().toLowerCase();
    if (status == 'approved' || status == 'verified') {
      totalRemitted += (r['amount'] as num?)?.toDouble() ?? 0.0;
    }
  }
  ```