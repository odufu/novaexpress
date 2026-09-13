$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"
    "Content-Type" = "application/json"
}

$baseUrl = "https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1"

Write-Host "=== 1. calculate_remittance_transfer_fee ==="
$body1 = '{"p_amount": 5000}'
$res1 = Invoke-RestMethod -Uri "$baseUrl/rpc/calculate_remittance_transfer_fee" -Method Post -Headers $headers -Body $body1
Write-Host "Fee for 5,000: $res1"

$body2 = '{"p_amount": 5200}'
$res2 = Invoke-RestMethod -Uri "$baseUrl/rpc/calculate_remittance_transfer_fee" -Method Post -Headers $headers -Body $body2
Write-Host "Fee for 5,200: $res2"

$body3 = '{"p_amount": 55000}'
$res3 = Invoke-RestMethod -Uri "$baseUrl/rpc/calculate_remittance_transfer_fee" -Method Post -Headers $headers -Body $body3
Write-Host "Fee for 55,000: $res3"

Write-Host "`n=== 2. fn_calculate_merchant_asset_custody ==="
$bodyCustody = '{"p_client_id": "33333333-3333-4333-8333-333333333333"}'
$resCustody = Invoke-RestMethod -Uri "$baseUrl/rpc/fn_calculate_merchant_asset_custody" -Method Post -Headers $headers -Body $bodyCustody
Write-Host ($resCustody | ConvertTo-Json -Depth 5)

Write-Host "`n=== 3. fn_approve_cash_remittance on dummy id ==="
try {
    $bodyApproveDummy = '{"p_remittance_id": "00000000-0000-0000-0000-000000000000"}'
    $resApproveDummy = Invoke-RestMethod -Uri "$baseUrl/rpc/fn_approve_cash_remittance" -Method Post -Headers $headers -Body $bodyApproveDummy
    Write-Host ($resApproveDummy | ConvertTo-Json -Depth 5)
} catch {
    Write-Host "Error: $_"
    $stream = $_.Exception.Response.GetResponseStream()
    if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "Response Body: $($reader.ReadToEnd())"
    }
}

Write-Host "`n=== 4. fn_approve_cash_remittance on existing row (05f38799-0d8b-45a8-a7ad-b560567dc653) ==="
try {
    $bodyApprove = '{"p_remittance_id": "05f38799-0d8b-45a8-a7ad-b560567dc653"}'
    $resApprove = Invoke-RestMethod -Uri "$baseUrl/rpc/fn_approve_cash_remittance" -Method Post -Headers $headers -Body $bodyApprove
    Write-Host ($resApprove | ConvertTo-Json -Depth 5)
} catch {
    Write-Host "Error: $_"
    $stream = $_.Exception.Response.GetResponseStream()
    if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "Response Body: $($reader.ReadToEnd())"
    }
}

Write-Host "`n=== 5. fn_generate_merchant_daily_settlement (empty window test) ==="
try {
    $bodySettle = '{"p_client_id": "33333333-3333-4333-8333-333333333333", "p_dc_id": "00000000-0000-4000-8000-788825051520", "p_period_start": "2026-09-01T00:00:00Z", "p_period_end": "2026-09-02T00:00:00Z", "p_custom_deductions": {}}'
    $resSettle = Invoke-RestMethod -Uri "$baseUrl/rpc/fn_generate_merchant_daily_settlement" -Method Post -Headers $headers -Body $bodySettle
    Write-Host ($resSettle | ConvertTo-Json -Depth 5)
} catch {
    Write-Host "Error: $_"
    $stream = $_.Exception.Response.GetResponseStream()
    if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "Response Body: $($reader.ReadToEnd())"
    }
}
