
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMDE0NzIsImV4cCI6MjEwNzY3NzQ3Mn0.B1epG9i_R1pryMVFo78DcL-Ett21L3HR_4VST34QifA';
const baseUrl = 'https://hwyqqjilcifxajruusoa.supabase.co';

async function testOr() {
  const cleanId = '22222222-2222-4222-8222-222222222222';
  const riderIds = [
    'b1111111-1111-4111-8111-111111111111',
    'fcc5842c-8355-455c-9d79-962e2e3ba357',
    '842bc86e-ada4-4ddb-9e96-2db063c84ba5',
    '1c2fd3b5-e67c-49de-b28b-2d1e656f26cb',
    'aa44b738-ed88-4862-a06a-06047d9b2fe9'
  ];
  
  const inList = riderIds.map(id => '%22' + id + '%22').join(',');
  const orClause = 'distribution_center_id.eq.' + cleanId + ',delivery_agent_id.in.(' + inList + ')';
  console.log('OR clause:', orClause);

  const url = baseUrl + '/rest/v1/cash_remittances?or=(' + orClause + ')&order=created_at.desc';
  console.log('URL:', url);

  const res = await fetch(url, {
    headers: {
      apikey: anonKey,
      Authorization: 'Bearer ' + anonKey
    }
  });
  console.log('Status:', res.status, res.statusText);
  const data = await res.json();
  console.log('Response:', data);
}
testOr();
