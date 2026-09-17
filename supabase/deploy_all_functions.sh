#!/usr/bin/env bash
# ============================================================================
# NOVEXPS SUPABASE EDGE FUNCTIONS ONE-CLICK DEPLOYER (Bash)
# ============================================================================

set -e

PROJECT_REF="$1"

echo "============================================================"
echo "⚡ NOVEXPS SUPABASE EDGE FUNCTIONS ONE-CLICK DEPLOYER"
echo "============================================================"

if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed or not in PATH."
    echo "Install via: brew install supabase/tap/supabase or npm install -g supabase"
    exit 1
fi

echo "✅ Supabase CLI detected: $(supabase --version)"

if [ -n "$PROJECT_REF" ]; then
    echo "🔗 Linking to project reference: $PROJECT_REF..."
    supabase link --project-ref "$PROJECT_REF"
fi

FUNCTIONS=(
    "auto-stock-alert"
    "confirm-delivery-pod"
    "dispatch-order"
    "generate-daily-settlements"
    "geocode-and-dispatch"
    "log-delivery-failure"
    "monnify-webhook"
    "paystack-webhook"
    "request-balance-payout"
    "request-stock-transfer"
    "submit-cash-remittance"
    "update-rider-telemetry"
)

echo ""
echo "📦 Found ${#FUNCTIONS[@]} Edge Functions to deploy..."
echo ""

SUCCESS=0
FAILED=0

for fn in "${FUNCTIONS[@]}"; do
    echo "🚀 Deploying function: $fn..."
    if supabase functions deploy "$fn" --no-verify-jwt; then
        echo "   ✅ $fn deployed successfully!"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "   ❌ $fn deployment failed."
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "============================================================"
echo "📊 DEPLOYMENT COMPLETE: $SUCCESS Success, $FAILED Failed"
echo "============================================================"
echo ""
echo "💡 To configure Paystack API secrets on your new Supabase project:"
echo "   supabase secrets set PAYSTACK_SECRET_KEY=sk_test_... PAYSTACK_PUBLIC_KEY=pk_test_..."
