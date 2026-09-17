<#
.SYNOPSIS
    Automated Deployment Script for all NovaExpress Supabase Edge Functions.
.DESCRIPTION
    Deploys all 12 Edge Functions in supabase/functions to a specified or linked Supabase project.
.PARAMETER ProjectRef
    The target Supabase project reference ID (e.g. qpcafevjsrbauweuiiyq).
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ProjectRef = ""
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "⚡ NOVEXPS SUPABASE EDGE FUNCTIONS ONE-CLICK DEPLOYER" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Verify Supabase CLI is installed
try {
    $cliVersion = supabase --version
    Write-Host "✅ Supabase CLI detected: $cliVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Supabase CLI is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install via: winget install Supabase.CLI or npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Link project if reference provided
if ($ProjectRef -ne "") {
    Write-Host "`n🔗 Linking to project reference: $ProjectRef..." -ForegroundColor Yellow
    supabase link --project-ref $ProjectRef
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to link project. Continuing with currently linked project..." -ForegroundColor DarkYellow
    } else {
        Write-Host "✅ Successfully linked project: $ProjectRef" -ForegroundColor Green
    }
}

# List of Edge Functions to deploy
$functions = @(
    "auto-stock-alert",
    "confirm-delivery-pod",
    "dispatch-order",
    "generate-daily-settlements",
    "geocode-and-dispatch",
    "log-delivery-failure",
    "monnify-webhook",
    "paystack-webhook",
    "request-balance-payout",
    "request-stock-transfer",
    "submit-cash-remittance",
    "update-rider-telemetry"
)

Write-Host "`n📦 Found $($functions.Count) Edge Functions to deploy:`n" -ForegroundColor Cyan

$successCount = 0
$failCount = 0

foreach ($fn in $functions) {
    Write-Host "🚀 Deploying function: $fn..." -ForegroundColor Yellow
    supabase functions deploy $fn --no-verify-jwt
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ $fn deployed successfully!" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "   ❌ $fn deployment failed." -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "📊 DEPLOYMENT COMPLETE: $successCount Success, $failCount Failed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "`n💡 Pro-Tip: To configure Paystack API secrets on your new Supabase project:" -ForegroundColor Yellow
Write-Host "   supabase secrets set PAYSTACK_SECRET_KEY=sk_test_... PAYSTACK_PUBLIC_KEY=pk_test_..." -ForegroundColor White
