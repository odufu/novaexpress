$url = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/orders?select=*,products(name,sku,base_price)&limit=5'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU'
$headers = @{ 'apikey' = $key; 'Authorization' = "Bearer $key" }
try {
  $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
  Write-Host "Success! Count: $($resp.Count)"
  if ($resp.Count -gt 0) {
    Write-Host "First Order: $($resp[0].order_number)"
    Write-Host "Product object: $(ConvertTo-Json $resp[0].products -Compress)"
  }
} catch {
  Write-Host "Error: $($_.Exception.Message)"
  if ($_.ErrorDetails) { Write-Host "Details: $($_.ErrorDetails.Message)" }
}
