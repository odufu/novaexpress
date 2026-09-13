# 05. Client Portal: Daily Settlements & Asset Custody Valuation Specification

## 1. Overview & Merchant Experience Goals

The **Client Portal Finance Subsystem** provides merchants with complete financial transparency, eliminating disputes through verifiable accounting trails. It accomplishes two primary goals:
1. **Daily Settlement Visibility**: Communicating the **10:00 PM Daily Remittance Closeout** status, showing orders gathered for the night's batch and itemizing all operational deductions.
2. **Asset Custody & Inventory Valuation**: Tracking total merchant capital held by NovaExpress in two distinct forms:
   - **Liquid Cash in Custody**: Physical COD collections held in DC vaults and digital funds held in Paystack escrow.
   - **In-Kind Inventory Holdings**: Physical stock stored in DC distribution warehouses and rider vehicle mini-hubs, valued using a sophisticated dual-valuation model.

---

## 2. Dual Inventory Valuation Model (Package Deal Variance)

### 2.1 The Multi-Pack Variance Problem
Merchants frequently sell goods in tiered multi-packs (e.g., 1 bottle for ₦12,000; 2 bottles for ₦20,000; 3 bottles for ₦28,000). Evaluating inventory strictly by multiplying physical units by the single-unit price results in an inflated valuation, while using raw cost price understates operational asset value.

### 2.2 Mathematical Model
NovaExpress computes and displays two complementary asset values:

1. **Conservative Base Liquidation Value**:
   $$\text{Valuation}_{\text{base}} = \sum_{i=1}^{N} \Big(\text{Units Held}_i \times \text{Base Unit Price}_i\Big)$$
   - Represents the guaranteed floor asset recovery value.

2. **Estimated Historical Realized Value**:
   $$\overline{P}_{\text{realized}, i} = \frac{\text{Total Delivered Sales Revenue for Product } i}{\text{Total Units Delivered for Product } i}$$
   $$\text{Valuation}_{\text{realized}} = \sum_{i=1}^{N} \Big(\text{Units Held}_i \times \overline{P}_{\text{realized}, i}\Big)$$
   - Reflects the true blended revenue expectation based on actual consumer multi-pack purchasing patterns.

---

## 3. UI Component Architecture: `ClientFinancePage`

### 3.1 File Location
`lib/features/client_portal/presentation/pages/client_finance_page.dart`

### 3.2 Visual Hierarchy
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 10:00 PM Daily Remittance Closeout Status Banner (Countdown + Cutoff Info) │
├─────────────────────────────────────────────────────────────────────────────┤
│ Asset Custody & Valuation (Liquid Escrow vs. In-Kind Inventory)             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4 Major Financial KPI Metrics Cards                                         │
│ • Delivered Sales  • Money Outside  • Awaiting Remittance  • Remitted Bank  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Verified Settlement Bank Details                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Historical Daily Settlement Batches Table (Itemized Fee Pills & Receipts)   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Granular Order Ledger (Search, Status Filter, Delivery Fee Inspection)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. UI Implementation Code

### 4.1 Daily 10:00 PM Remittance Closeout Status Banner

```dart
Widget _buildDailySettlementStatusBanner(BuildContext context, ClientPortalState state, bool isDark) {
  final now = DateTime.now();
  final closeoutTime = DateTime(now.year, now.month, now.day, 22, 0); // 10:00 PM
  final isPastCloseout = now.isAfter(closeoutTime);
  final difference = isPastCloseout 
      ? closeoutTime.add(const Duration(days: 1)).difference(now) 
      : closeoutTime.difference(now);

  final hours = difference.inHours;
  final minutes = difference.inMinutes % 60;
  final pendingOrdersCount = state.financeOrders.where((o) => o.isDelivered && !o.isRemitted).length;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFF86EFAC),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.nightlight_round, color: Color(0xFF0D9488), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '10:00 PM Daily Remittance Closeout',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Next Batch in ${hours}h ${minutes}m',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'All orders delivered today before 10:00 PM are automatically reconciled, fee-deducted, and scheduled for bank disbursement. Currently, $pendingOrdersCount orders are queued for tonight\'s closeout.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### 4.2 Asset Custody & Valuation Dual-Card

```dart
Widget _buildAssetCustodyCard(BuildContext context, Map<String, dynamic> custodyData, bool isDark) {
  final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  final double liquidInCustody = (custodyData['liquid_cash_in_custody'] as num?)?.toDouble() ?? 0.0;
  final double codInVault = (custodyData['physical_cod_in_dc_vault'] as num?)?.toDouble() ?? 0.0;
  final double directInPaystack = (custodyData['direct_transfer_in_paystack'] as num?)?.toDouble() ?? 0.0;

  final double inventoryEstimated = (custodyData['inventory_estimated_retail_value'] as num?)?.toDouble() ?? 0.0;
  final double inventoryBaseline = (custodyData['inventory_baseline_liquidation_value'] as num?)?.toDouble() ?? 0.0;
  final int totalUnits = (custodyData['total_inventory_units_held'] as num?)?.toInt() ?? 0;

  final double grandTotalValue = (custodyData['grand_total_asset_value'] as num?)?.toDouble() ?? (liquidInCustody + inventoryEstimated);

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asset Custody & Valuation',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  'Liquid funds in NovaExpress custody + In-kind warehouse inventory valuation',
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF37021).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Capital in Custody', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF37021), fontWeight: FontWeight.w600)),
                  Text(currency.format(grandTotalValue), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFFF37021))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),

        // 2 Sub-Cards: Liquid Cash vs In-Kind Inventory
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Liquid Cash in Custody
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488), size: 20),
                        const SizedBox(width: 8),
                        Text('Liquid Cash in Custody', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currency.format(liquidInCustody), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0D9488))),
                    const SizedBox(height: 12),
                    _buildSubDetailRow('Physical COD in DC Vaults', currency.format(codInVault)),
                    _buildSubDetailRow('Digital Transfers in Paystack', currency.format(directInPaystack)),
                    const SizedBox(height: 6),
                    Text('Disbursed daily at 10:00 PM closeout.', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Right Card: In-Kind Inventory Holdings
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 20),
                        const SizedBox(width: 8),
                        Text('In-Kind Inventory Holdings', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currency.format(inventoryEstimated), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3B82F6))),
                    const SizedBox(height: 12),
                    _buildSubDetailRow('Total Physical Units in Warehouse', '$totalUnits units'),
                    _buildSubDetailRow('Baseline Liquidation Floor', currency.format(inventoryBaseline)),
                    const SizedBox(height: 6),
                    Text('Factoring package deal volume discounts.', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSubDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
```

### 4.3 Historical Daily Settlements Table with Itemized Charges

```dart
Widget _buildDailySettlementsTable(BuildContext context, List<ClientSettlement> settlements, bool isDark) {
  final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

  if (settlements.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No Daily Settlement Batches Yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Batches finalized at 10:00 PM will appear here with itemized deductions and payment receipts.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Settlement Batches & Receipts', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${settlements.length} Batches Processed', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: settlements.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final s = settlements[idx];
            return ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              title: Text(s.settlementNumber, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                'Settled: ${DateFormat('MMM dd, yyyy - hh:mm a').format(s.settledAt)} | ${s.totalOrdersCount} Orders',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currency.format(s.netPayoutAmount), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0D9488))),
                  Text('Disbursed to ${s.destinationBankName}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  child: Column(
                    children: [
                      _buildSettlementDetailRow('Gross Sales Collected', currency.format(s.grossCollections)),
                      _buildSettlementDetailRow('Logistics Delivery Fees', '- ${currency.format(s.logisticsFeesDeducted)}', isNegative: true),
                      _buildSettlementDetailRow('Platform Commission Fees', '- ${currency.format(s.platformFeesDeducted)}', isNegative: true),
                      _buildSettlementDetailRow('Paystack Gateway Charges', '- ${currency.format(s.gatewayFeesDeducted)}', isNegative: true),
                      if (s.failedAttemptFeesDeducted > 0)
                        _buildSettlementDetailRow('Failed Attempt Charges', '- ${currency.format(s.failedAttemptFeesDeducted)}', isNegative: true),
                      if (s.otherChargesDeducted > 0)
                        _buildSettlementDetailRow('Auxiliary Charges', '- ${currency.format(s.otherChargesDeducted)}', isNegative: true),
                      const Divider(height: 16),
                      _buildSettlementDetailRow('Net Disbursed to Bank', currency.format(s.netPayoutAmount), isBold: true),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (s.payoutReference != null && s.payoutReference!.isNotEmpty)
                            Text('Bank Ref: ${s.payoutReference}  |  ', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          OutlinedButton.icon(
                            onPressed: () {
                              // Download or view PDF/CSV statement receipt
                            },
                            icon: const Icon(Icons.file_download_outlined, size: 14),
                            label: const Text('Download Receipt', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildSettlementDetailRow(String label, String value, {bool isNegative = false, bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: isBold ? 13 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isNegative ? const Color(0xFFEF4444) : null,
          ),
        ),
      ],
    ),
  );
}
```
