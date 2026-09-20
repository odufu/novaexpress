$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"
$baseUrl = "https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1"

$headers = @{
    "apikey" = $apiKey
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

Write-Host "=== 1. AUDIT CLIENTS TABLE ==="
$clients = Invoke-RestMethod -Uri "$baseUrl/clients?select=id,name,company_name,custom_delivery_fee,custom_failed_attempt_fee,custom_platform_fee,custom_platform_fee_type,services_enabled,brand_color_primary,logo_url&limit=3" -Headers $headers
$clients | ConvertTo-Json -Depth 3

Write-Host "`n=== 2. AUDIT DC FINANCE SETTINGS ==="
$dcSettings = Invoke-RestMethod -Uri "$baseUrl/dc_finance_settings?select=*&limit=1" -Headers $headers
$dcSettings | ConvertTo-Json -Depth 3

Write-Host "`n=== 3. AUDIT ORDERS SCHEMA & COLUMNS ==="
$orders = Invoke-RestMethod -Uri "$baseUrl/orders?select=id,order_number,client_id,client_name,product_id,product_name,package_deal_id,package_deal_name,quantity,paid_quantity,free_quantity,source_warehouse,total_amount,client_delivery_fee,status,financial_settlement_status&limit=3" -Headers $headers
$orders | ConvertTo-Json -Depth 3

Write-Host "`n=== 4. AUDIT CLIENT SETTLEMENTS ==="
$settlements = Invoke-RestMethod -Uri "$baseUrl/client_settlements?select=id,settlement_number,gross_collections,logistics_fees_deducted,platform_fees_deducted,failed_attempt_fees_deducted,other_charges_deducted,net_payout_amount&limit=2" -Headers $headers
$settlements | ConvertTo-Json -Depth 3
