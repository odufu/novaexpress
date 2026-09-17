# 04. Main DC Console: Daily 10:00 PM Settlement & Settings Specification

## 1. Executive Role of the Main Grand DC Console

In the NovaXpress multi-DC architecture, the **Main Grand DC Console** serves as the central clearinghouse. While branch DCs manage day-to-day rider dispatching and physical package sorting, the Main DC Console exclusively executes:
1. **Global & Merchant Billing Configuration**: Setting base delivery rates, platform fees, payment gateway fee allocations, and failed delivery charges.
2. **Daily 10:00 PM Merchant Settlement Closeouts**: Reconciling all gross collections (physical COD in DC vaults and digital transfers in Paystack) and generating official batch payouts to clients.
3. **Escrow & Cash Vault Custody Audits**: Auditing liquid cash held vs. in-kind inventory valuation across the entire network.

---

## 2. "Merchant Billing & Order Charges" in `DCSettingsPage`

### 2.1 File Location
`lib/features/dc_console/presentation/pages/dc_settings_page.dart`

### 2.2 Tab Architecture
Extend the existing 4-tab bar to a 5-tab layout:
```dart
tabs: const [
  Tab(icon: Icon(Icons.payments_outlined, size: 16), text: 'Finance & POS Rules'),
  Tab(icon: Icon(Icons.handshake_outlined, size: 16), text: 'Rider Entitlements'),
  Tab(icon: Icon(Icons.account_balance_outlined, size: 16), text: 'Settlement Accounts'),
  Tab(icon: Icon(Icons.receipt_long_outlined, size: 16), text: 'Merchant Billing & Charges'), // NEW TAB 4
  Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Automation & Webhooks'),
]
```

### 2.3 State Notifier & Entity Extensions
Update `DCFinanceSettings` entity and `DCSettingsDraftState` with:
- `defaultClientDeliveryFee: double` (default `3500.00`)
- `platformFeeType: String` (`'flat'` or `'percent'`)
- `platformFeeValue: double` (default `500.00`)
- `paystackFeeAbsorbedBy: String` (`'merchant'`, `'company'`, `'shared'`)
- `failedOrderCharge: double` (default `500.00`)
- `dailySettlementCutoffTime: String` (default `'22:00'`)

### 2.4 Tab Content UI Implementation Code

```dart
Widget _buildMerchantBillingTab(bool isDark, bool isMobile) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        _buildSectionHeader(
          title: 'Merchant Billing & Order Charges',
          subtitle: 'Configure default client deductions, platform commissions, gateway fee splits, and the 10:00 PM daily settlement cutoff.',
          icon: Icons.receipt_long_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // Settings Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                // Card 1: Default Logistics Delivery Fee
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                  child: _buildSettingCard(
                    isDark: isDark,
                    title: 'Standard Logistics Delivery Fee',
                    subtitle: 'Base fee deducted from client sales revenue per delivered order.',
                    child: TextFormField(
                      controller: _clientDeliveryFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: '₦ ',
                        labelText: 'Default Delivery Fee (₦)',
                        helperText: 'Applied when merchant has no custom rate override.',
                      ),
                    ),
                  ),
                ),

                // Card 2: Platform Commission Fee
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                  child: _buildSettingCard(
                    isDark: isDark,
                    title: 'Platform Commission Charge',
                    subtitle: 'Operational margin earned by NovaXpress per completed order.',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _platformFeeType,
                                items: const [
                                  DropdownMenuItem(value: 'flat', child: Text('Flat Rate (₦)')),
                                  DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                                ],
                                onChanged: (val) => setState(() => _platformFeeType = val ?? 'flat'),
                                decoration: const InputDecoration(labelText: 'Fee Structure'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _platformFeeValueController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: _platformFeeType == 'flat' ? 'Amount (₦)' : 'Rate (%)',
                                  prefixText: _platformFeeType == 'flat' ? '₦ ' : '',
                                  suffixText: _platformFeeType == 'percent' ? '%' : '',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Card 3: Paystack Gateway Fee Allocation
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                  child: _buildSettingCard(
                    isDark: isDark,
                    title: 'Payment Gateway Fee Absorber',
                    subtitle: 'Who bears the 1.5% Paystack processing fee on direct transfers and card payments.',
                    child: DropdownButtonFormField<String>(
                      value: _paystackFeeAbsorbedBy,
                      items: const [
                        DropdownMenuItem(value: 'merchant', child: Text('Merchant / Client (Deducted from Payout)')),
                        DropdownMenuItem(value: 'company', child: Text('Company / NovaXpress (Absorbed)')),
                        DropdownMenuItem(value: 'shared', child: Text('Shared 50/50 Split')),
                      ],
                      onChanged: (val) => setState(() => _paystackFeeAbsorbedBy = val ?? 'merchant'),
                      decoration: const InputDecoration(labelText: 'Gateway Fee Policy'),
                    ),
                  ),
                ),

                // Card 4: Failed Delivery Attempt Fee
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                  child: _buildSettingCard(
                    isDark: isDark,
                    title: 'Failed Delivery Surcharge',
                    subtitle: 'Administrative return handling fee charged for rejected or customer-unavailable deliveries.',
                    child: TextFormField(
                      controller: _failedOrderChargeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: '₦ ',
                        labelText: 'Failed Order Fee (₦)',
                        helperText: 'Deducted from merchant net settlement during daily closeout.',
                      ),
                    ),
                  ),
                ),

                // Card 5: Daily Settlement Cutoff Time
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                  child: _buildSettingCard(
                    isDark: isDark,
                    title: 'Daily Remittance Closeout Cutoff',
                    subtitle: 'Scheduled cutoff time for aggregating daily delivered orders into the payout batch.',
                    child: TextFormField(
                      controller: _dailyCutoffTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Cutoff Time (24h Format)',
                        hintText: '22:00',
                        suffixIcon: Icon(Icons.access_time_rounded),
                        helperText: 'Default 22:00 (10:00 PM WAT).',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Live Settlement Closeout Preview Simulator
        _buildSettlementPolicySimulator(isDark),
      ],
    ),
  );
}
```

---

## 3. "Daily Merchant Settlement (10:00 PM Closeout)" Clearinghouse Modal

### 3.1 File Location
`lib/features/dc_console/presentation/widgets/dc_daily_merchant_settlement_modal.dart`

### 3.2 Modal Features & Flow
1. **Client & Date Range Selector**: Filter delivered orders for the target merchant.
2. **Interactive Order Checklist**: Display all delivered orders ready for closeout. Checkboxes allow admins to include or exclude specific orders if an investigation is underway.
3. **Itemized Charges Breakdown**:
   - Gross Delivered Sales (Total customer collected funds).
   - Logistics Delivery Fees (e.g. $10 \times ₦3,500 = ₦35,000$).
   - Platform Commission Fees (e.g. $10 \times ₦500 = ₦5,000$).
   - Payment Gateway Fees (1.5% capped at ₦2,000 on Paystack transactions).
   - Failed Delivery Handling Charges.
   - **Net Liquid Remittance to Bank Account**.
4. **Destination Bank Account Verification**: Prominently display the client's registered settlement bank name, account number, and verified account name.
5. **Atomic Execution Button**: **"Execute & Finalize 10:00 PM Settlement Batch"**.
   - Invokes `fn_generate_merchant_daily_settlement`.
   - Generates settlement receipt with unique number `SETTLE-YYYY-MM-DD-XXXX`.
   - Locks orders from being re-settled.

### 3.3 Modal Source Code

```dart
// lib/features/dc_console/presentation/widgets/dc_daily_merchant_settlement_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/dc_console_provider.dart';

class DCDailyMerchantSettlementModal extends ConsumerStatefulWidget {
  final ClientProfile client;
  final List<OrderEntity> eligibleOrders;

  const DCDailyMerchantSettlementModal({
    super.key,
    required this.client,
    required this.eligibleOrders,
  });

  static Future<void> show({
    required BuildContext context,
    required ClientProfile client,
    required List<OrderEntity> eligibleOrders,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DCDailyMerchantSettlementModal(
        client: client,
        eligibleOrders: eligibleOrders,
      ),
    );
  }

  @override
  ConsumerState<DCDailyMerchantSettlementModal> createState() => _DCDailyMerchantSettlementModalState();
}

class _DCDailyMerchantSettlementModalState extends ConsumerState<DCDailyMerchantSettlementModal> {
  late Set<String> _selectedOrderIds;
  final TextEditingController _otherChargesController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default select all eligible orders
    _selectedOrderIds = widget.eligibleOrders.map((o) => o.id).toSet();
  }

  @override
  void dispose() {
    _otherChargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    final dcSettings = ref.watch(dcConsoleProvider.select((s) => s.financeSettings));
    final activeDcId = ref.watch(dcConsoleProvider.select((s) => s.activeDcId));

    // Calculate active metrics based on selected orders
    final activeOrders = widget.eligibleOrders.where((o) => _selectedOrderIds.contains(o.id)).toList();
    final double grossCollections = activeOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    
    // Delivery fees calculation (merchant override or DC default)
    final double deliveryFeePerOrder = widget.client.customDeliveryFee ?? dcSettings.defaultClientDeliveryFee;
    final double totalDeliveryFees = activeOrders.length * deliveryFeePerOrder;

    // Platform fees calculation
    double totalPlatformFees = 0.0;
    if (dcSettings.platformFeeType == 'percent') {
      totalPlatformFees = grossCollections * (dcSettings.platformFeeValue / 100.0);
    } else {
      totalPlatformFees = activeOrders.length * dcSettings.platformFeeValue;
    }

    // Gateway fees calculation
    double totalGatewayFees = 0.0;
    if (dcSettings.paystackFeeAbsorbedBy == 'merchant') {
      final directOrders = activeOrders.where((o) => o.isDirectTransfer);
      for (final d in directOrders) {
        final calculatedFee = d.totalAmount * (dcSettings.paystackDirectFeePercent / 100.0);
        totalGatewayFees += calculatedFee > dcSettings.paystackFeeCap ? dcSettings.paystackFeeCap : calculatedFee;
      }
    }

    final double otherCharges = double.tryParse(_otherChargesController.text) ?? 0.0;
    final double totalDeductions = totalDeliveryFees + totalPlatformFees + totalGatewayFees + otherCharges;
    final double netPayout = grossCollections - totalDeductions;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 850,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: Color(0xFFF37021), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Merchant Settlement (10:00 PM Closeout)',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Merchant: ${widget.client.companyName} | Verified Account: ${widget.client.bankName} - ${widget.client.accountNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Order Selection & Charges Matrix
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Order Checklist
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivered Orders (${activeOrders.length}/${widget.eligibleOrders.length})',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedOrderIds.length == widget.eligibleOrders.length) {
                                    _selectedOrderIds.clear();
                                  } else {
                                    _selectedOrderIds = widget.eligibleOrders.map((o) => o.id).toSet();
                                  }
                                });
                              },
                              child: Text(_selectedOrderIds.length == widget.eligibleOrders.length ? 'Deselect All' : 'Select All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.eligibleOrders.length,
                            itemBuilder: (context, idx) {
                              final o = widget.eligibleOrders[idx];
                              final isSelected = _selectedOrderIds.contains(o.id);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedOrderIds.add(o.id);
                                    } else {
                                      _selectedOrderIds.remove(o.id);
                                    }
                                  });
                                },
                                title: Text('${o.orderNumber} - ${o.customerName}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text('${o.paymentMethod.toUpperCase()} | Delivered: ${o.deliveredAt?.toLocal().toString().split('.')[0] ?? "Today"}', style: GoogleFonts.inter(fontSize: 11)),
                                secondary: Text(currency.format(o.totalAmount), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0D9488))),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right: Itemized Charges Breakdown Card
                  Expanded(
                    flex: 2,
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
                          Text('Itemized Settlement Calculation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 12),
                          _buildCalculationRow('Gross Delivered Sales', currency.format(grossCollections), isPositive: true),
                          const Divider(height: 16),
                          _buildCalculationRow('Logistics Delivery Fees', '- ${currency.format(totalDeliveryFees)}', isNegative: true),
                          _buildCalculationRow('Platform Commission Fees', '- ${currency.format(totalPlatformFees)}', isNegative: true),
                          _buildCalculationRow('Paystack Gateway Fees', '- ${currency.format(totalGatewayFees)}', isNegative: true),
                          if (otherCharges > 0)
                            _buildCalculationRow('Auxiliary Charges', '- ${currency.format(otherCharges)}', isNegative: true),
                          const Divider(height: 20),
                          _buildCalculationRow('Net Liquid Payout', currency.format(netPayout > 0 ? netPayout : 0.0), isBold: true, isHighlight: true),
                          const Spacer(),

                          // Execution Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: activeOrders.isEmpty ? null : () async {
                                await showAppLoadingDialog(
                                  context: context,
                                  message: 'Finalizing 10:00 PM Closeout...',
                                  subMessage: 'Locking ${activeOrders.length} orders & generating settlement receipt...',
                                  isDark: isDark,
                                  task: () async {
                                    final now = DateTime.now();
                                    await ref.read(dcConsoleProvider.notifier).executeDailyMerchantSettlement(
                                      clientId: widget.client.id,
                                      dcId: activeDcId,
                                      periodStart: now.subtract(const Duration(days: 1)),
                                      periodEnd: now,
                                      customDeductions: {
                                        'other_charges': otherCharges,
                                        'notes': _notesController.text,
                                      },
                                    );
                                  },
                                );
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                              label: Text('Finalize 10:00 PM Closeout', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? const Color(0xFF0D9488)
                  : isNegative
                      ? const Color(0xFFEF4444)
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 4. Remittance Reconciliation Modal (`DCRemittanceDetailModal`)

### 4.1 Verification & COD Debt Liquidation
In `lib/features/dc_console/presentation/widgets/dc_remittance_detail_modal.dart`, update the verification action:
- Replace client-side state mutation with RPC `fn_approve_cash_remittance`.
- Display deducted failed delivery stipends (`failed_stipends_deducted`).
- Display instant updated rider COD debt balance.
