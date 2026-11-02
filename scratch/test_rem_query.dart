import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  const url = 'https://hwyqqjilcifxajruusoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzUNIiwiTXPCVCI6IkpXVCJ9.eyJpcyI6Imh3eXFxamp1bGlfaWZycnV1c29SiIwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMDE0CzIsImV4cCI6MjEwNzg3NDcyfQB1epG9i_R1pryMVFo78DcL-Ett21L3HR_4VST34QifA';
  const serviceKey = 'eyJhbGciOiJIUzUNIiwiTXPCVCI6IkpXVCJ9.eyJpcyI6Imh3eXFxamp1bGlfaWZycnV1c29hIiwicm9sZSI6InNlcnZpY2Vf3m9sZSIsIm1hdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrqq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI';
  final client = SupabaseClient(url, serviceKey);

  const cleanId = '22222222-2222-4222-8222-222222222222';

  print('1. Checking DC...');
  final dcCheck = await client
      .table('distribution_centers')
      .select('id')
      .eq('id', cleanId)
      .maybeSingle();
  print('DC check result: $dcCheck');

  print('2. Checking riders in delivery_agents...');
  final ridersRes = await client
      .table('delivery_agents')
      .select('id')
      .eq('distribution_center_id', cleanId);
  final riderIds = (ridersRes as List)
      .map((r) => r['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
  print('Rider ids count: ${riderIds.length}, ids: $riderIds');

  print('3. Testing existing query.or with inList...');
  if (riderIds.isNotEmpty) {
    final inList = riderIds.map((id) => '"' + id + '"').join(',');
    final orClause = 'distribution_center_id.eq.' + cleanId + ',delivery_agent_id.in.(' + inList + ')';
    print('OR clause: ' + orClause);
    try {
      final res = await client
          .table('cash_remittances')
          .select()
          .or(orClause)
          .order('created_at', ascending: false);
      print('Result count with OR: ' + ((res as List).length).toString());
    } catch (err) {
      print('ERROR ON OR QUERY: ' + err.toString());
    }
  }

  print('4. Testing query with anonClient as joelfinances...');
  final anonClient = SupabaseClient(url, anonKey);
  try {
    final authRes = await anonClient.auth.signInWithPassword(
      email: 'joelfinances@gmail.com',
      password: 'password123',
    );
    print('Signed in as joelfinances: ' + (authRes.user?.email ?? 'null'));

    final anonRes = await anonClient
        .table('cash_remittances')
        .select()
        .order('created_at', ascending: false);
    print('Authenticated query count: ' + ((anonRes as List).length).toString());
  } catch (authErr) {
    print('Authenticated query ERROR: ' + authErr.toString());
  }
}
