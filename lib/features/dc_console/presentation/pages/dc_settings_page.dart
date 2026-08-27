import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../providers/dc_console_provider.dart';

class DCSettingsDraftState {
  final String chargeMode;
  final bool isReimbursable;
  final bool autoReconcile;
  final double simAmount;

  const DCSettingsDraftState({
    this.chargeMode = 'dynamic',
    this.isReimbursable = true,
    this.autoReconcile = true,
    this.simAmount = 35000.0,
  });

  DCSettingsDraftState copyWith({
    String? chargeMode,
    bool? isReimbursable,
    bool? autoReconcile,
    double? simAmount,
  }) {
    return DCSettingsDraftState(
      chargeMode: chargeMode ?? this.chargeMode,
      isReimbursable: isReimbursable ?? this.isReimbursable,
      autoReconcile: autoReconcile ?? this.autoReconcile,
      simAmount: simAmount ?? this.simAmount,
    );
  }
}

class DCSettingsDraftNotifier extends StateNotifier<DCSettingsDraftState> {
  DCSettingsDraftNotifier(DCFinanceSettings initial)
      : super(DCSettingsDraftState(
          chargeMode: initial.posChargeMode,
          isReimbursable: initial.isPosFeeReimbursable,
          autoReconcile: initial.autoReconcileWebhooks,
        ));

  void setChargeMode(String mode) => state = state.copyWith(chargeMode: mode);
  void setReimbursable(bool val) => state = state.copyWith(isReimbursable: val);
  void setAutoReconcile(bool val) => state = state.copyWith(autoReconcile: val);
  void setSimAmount(double amount) => state = state.copyWith(simAmount: amount);
  void reset(DCFinanceSettings defaults) => state = DCSettingsDraftState(
        chargeMode: defaults.posChargeMode,
        isReimbursable: defaults.isPosFeeReimbursable,
        autoReconcile: defaults.autoReconcileWebhooks,
      );
}

final dcSettingsDraftProvider =
    StateNotifierProvider.autoDispose<DCSettingsDraftNotifier, DCSettingsDraftState>((ref) {
  final current = ref.watch(dcConsoleProvider.select((s) => s.financeSettings));
  return DCSettingsDraftNotifier(current);
});

class DCSettingsPage extends ConsumerStatefulWidget {
  const DCSettingsPage({super.key});

  @override
  ConsumerState<DCSettingsPage> createState() => _DCSettingsPageState();
}

class _DCSettingsPageState extends ConsumerState<DCSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for POS & Finance
  late TextEditingController _posFlatRateController;
  late TextEditingController _posTierAmountController;
  late TextEditingController _posTierFeeController;
  late TextEditingController _posMaxCapFeeController;
  late TextEditingController _paystackFeePercentController;
  late TextEditingController _paystackFeeCapController;

  // Controllers for Entitlements
  late TextEditingController _commissionRateController;
  late TextEditingController _transportAllowanceController;
  late TextEditingController _failedStipendController;

  // Controllers for Bank Settlement
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;

  // Interactive Simulator Controller
  final TextEditingController _simAmountController = TextEditingController(text: '35000');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final settings = ref.read(dcConsoleProvider).financeSettings;

    _posFlatRateController = TextEditingController(text: settings.posFlatRate.toInt().toString());
    _posTierAmountController = TextEditingController(text: settings.posTierAmount.toInt().toString());
    _posTierFeeController = TextEditingController(text: settings.posTierFee.toInt().toString());
    _posMaxCapFeeController = TextEditingController(text: settings.posMaxCapFee.toInt().toString());
    _paystackFeePercentController = TextEditingController(text: settings.paystackDirectFeePercent.toString());
    _paystackFeeCapController = TextEditingController(text: settings.paystackFeeCap.toInt().toString());

    _commissionRateController = TextEditingController(text: settings.defaultCommissionRate.toInt().toString());
    _transportAllowanceController = TextEditingController(text: settings.defaultTransportAllowance.toInt().toString());
    _failedStipendController = TextEditingController(text: settings.defaultFailedStipend.toInt().toString());

    _bankNameController = TextEditingController(text: settings.settlementBankName);
    _accountNumberController = TextEditingController(text: settings.settlementAccountNumber);
    _accountNameController = TextEditingController(text: settings.settlementAccountName);

    _simAmountController.addListener(() {
      final parsed = double.tryParse(_simAmountController.text.replaceAll(',', '')) ?? 0.0;
      ref.read(dcSettingsDraftProvider.notifier).setSimAmount(parsed);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _posFlatRateController.dispose();
    _posTierAmountController.dispose();
    _posTierFeeController.dispose();
    _posMaxCapFeeController.dispose();
    _paystackFeePercentController.dispose();
    _paystackFeeCapController.dispose();
    _commissionRateController.dispose();
    _transportAllowanceController.dispose();
    _failedStipendController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _simAmountController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final draft = ref.read(dcSettingsDraftProvider);
    final updated = DCFinanceSettings(
      posChargeMode: draft.chargeMode,
      posFlatRate: double.tryParse(_posFlatRateController.text) ?? 350.0,
      posTierAmount: double.tryParse(_posTierAmountController.text) ?? 5000.0,
      posTierFee: double.tryParse(_posTierFeeController.text) ?? 100.0,
      posMaxCapFee: double.tryParse(_posMaxCapFeeController.text) ?? 1500.0,
      isPosFeeReimbursable: draft.isReimbursable,
      paystackDirectFeePercent: double.tryParse(_paystackFeePercentController.text) ?? 1.5,
      paystackFeeCap: double.tryParse(_paystackFeeCapController.text) ?? 2000.0,
      defaultCommissionRate: double.tryParse(_commissionRateController.text) ?? 1000.0,
      defaultTransportAllowance: double.tryParse(_transportAllowanceController.text) ?? 1500.0,
      defaultFailedStipend: double.tryParse(_failedStipendController.text) ?? 500.0,
      settlementBankName: _bankNameController.text.trim(),
      settlementAccountNumber: _accountNumberController.text.trim(),
      settlementAccountName: _accountNameController.text.trim(),
      autoReconcileWebhooks: draft.autoReconcile,
    );

    ref.read(dcConsoleProvider.notifier).updateFinanceSettings(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✅ Finance & POS Remittance Rules successfully saved and applied to live reconciliations.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetDefaults() {
    const defaults = DCFinanceSettings();
    ref.read(dcSettingsDraftProvider.notifier).reset(defaults);

    _posFlatRateController.text = defaults.posFlatRate.toInt().toString();
    _posTierAmountController.text = defaults.posTierAmount.toInt().toString();
    _posTierFeeController.text = defaults.posTierFee.toInt().toString();
    _posMaxCapFeeController.text = defaults.posMaxCapFee.toInt().toString();
    _paystackFeePercentController.text = defaults.paystackDirectFeePercent.toString();
    _paystackFeeCapController.text = defaults.paystackFeeCap.toInt().toString();
    _commissionRateController.text = defaults.defaultCommissionRate.toInt().toString();
    _transportAllowanceController.text = defaults.defaultTransportAllowance.toInt().toString();
    _failedStipendController.text = defaults.defaultFailedStipend.toInt().toString();

    ref.read(dcConsoleProvider.notifier).updateFinanceSettings(defaults);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 Reset to default NovaExpress standard policies.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeHubName = ref.watch(dcConsoleProvider.select((s) => s.activeHubName));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Save Actions
            _buildPageHeader(isDark, activeHubName),

            const SizedBox(height: 20),

            // Tab Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFFF37021),
                indicatorWeight: 3,
                labelColor: isDark ? Colors.white : const Color(0xFF031632),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Finance & POS Rules'),
                  Tab(icon: Icon(Icons.handshake_rounded, size: 18), text: 'Rider Entitlements'),
                  Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Settlement Accounts'),
                  Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Automation & Webhooks'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFinanceAndPosTab(isDark),
                  _buildEntitlementsTab(isDark),
                  _buildSettlementBankTab(isDark),
                  _buildAutomationTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isDark, String activeHubName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFF37021), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distribution Center Policy & Finance Settings',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF031632),
                            ),
                          ),
                          Text(
                            'Configure POS transfer fees (Flat vs Dynamic), Paystack automated rules, and real-time reconciliation matrices.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Reset Defaults'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Apply & Save Rules',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF031632),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: FINANCE & POS RULES (Flat vs Dynamic)
  // ==========================================
  Widget _buildFinanceAndPosTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // 1. POS Transfer Charge Rule Selector
        Consumer(
          builder: (context, ref, _) {
            final chargeMode = ref.watch(dcSettingsDraftProvider.select((s) => s.chargeMode));
            final isReimbursable = ref.watch(dcSettingsDraftProvider.select((s) => s.isReimbursable));

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POS Remittance Transfer Fee Strategy',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF031632)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose whether POS cash handover transfers use tiered dynamic scaling or a fixed flat fee.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          chargeMode == 'dynamic' ? 'DYNAMIC TIERED ACTIVE' : 'FLAT RATE ACTIVE',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Segmented Choice Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'Dynamic Tiered Scaling',
                          subtitle: 'Fee scales with transfer amount (e.g. ₦100 per ₦5,000 cash deposited)',
                          icon: Icons.auto_graph_rounded,
                          isSelected: chargeMode == 'dynamic',
                          onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('dynamic'),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'Flat Rate Fee',
                          subtitle: 'A fixed standard fee per deposit regardless of volume (e.g. ₦350 flat)',
                          icon: Icons.tag_rounded,
                          isSelected: chargeMode == 'flat',
                          onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('flat'),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // Inputs based on choice
                  if (chargeMode == 'dynamic') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Tier Step Amount (₦)',
                            controller: _posTierAmountController,
                            hint: '5000',
                            isDark: isDark,
                            helper: 'Bracket size in Naira',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Fee per Tier (₦)',
                            controller: _posTierFeeController,
                            hint: '100',
                            isDark: isDark,
                            helper: 'Charged per bracket',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Maximum Cap Fee (₦)',
                            controller: _posMaxCapFeeController,
                            hint: '1500',
                            isDark: isDark,
                            helper: 'Maximum charge ceiling',
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Fixed Flat POS Transfer Fee (₦)',
                            controller: _posFlatRateController,
                            hint: '350',
                            isDark: isDark,
                            helper: 'Standard fee applied to all cash deposits',
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Reimbursable policy switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Company Reimburses POS Transfer Fees', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('When enabled, the rider retains the POS transfer charge from collected cash and it is factored into reconciliation.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: isReimbursable,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) => ref.read(dcSettingsDraftProvider.notifier).setReimbursable(val),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // 2. Interactive Reconciliation Simulator Card
        Consumer(
          builder: (context, ref, _) {
            final draft = ref.watch(dcSettingsDraftProvider);
            final chargeMode = draft.chargeMode;
            final simAmount = draft.simAmount;
            final isReimbursable = draft.isReimbursable;

            final currentPosFee = chargeMode == 'flat'
                ? (double.tryParse(_posFlatRateController.text) ?? 350.0)
                : ((simAmount / (double.tryParse(_posTierAmountController.text) ?? 5000.0)).ceil() *
                        (double.tryParse(_posTierFeeController.text) ?? 100.0))
                    .clamp(
                        double.tryParse(_posTierFeeController.text) ?? 100.0,
                        double.tryParse(_posMaxCapFeeController.text) ?? 1500.0);

            const sampleOrdersCount = 1;
            final commission = double.tryParse(_commissionRateController.text) ?? 1000.0;
            final transport = double.tryParse(_transportAllowanceController.text) ?? 1500.0;
            final riderRetained = sampleOrdersCount * (commission + transport);
            final netToRemit = (simAmount - riderRetained - (isReimbursable ? currentPosFee : 0.0)).clamp(0.0, double.infinity);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Live Financial Reconciliation Simulator',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text('Formula Preview', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _simAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Sample Collected Cash (₦)',
                            labelStyle: GoogleFonts.inter(fontSize: 12),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0B1021) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildSimMetricPill('Mode', chargeMode.toUpperCase(), const Color(0xFF2563EB)),
                            _buildSimMetricPill('POS Fee', CurrencyFormatter.formatNaira(currentPosFee), const Color(0xFFEF4444)),
                            _buildSimMetricPill('Rider Cut Retained', CurrencyFormatter.formatNaira(riderRetained), const Color(0xFF8B5CF6)),
                            _buildSimMetricPill('Net To Remit to DC', CurrencyFormatter.formatNaira(netToRemit), const Color(0xFF10B981), isBold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // 3. Paystack Direct Transfer Rules
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paystack Gateway Charges & Settlements', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Standard gateway fees charged by Paystack for customer direct transfers to company Nuban.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Direct Paystack Fee (%)',
                      controller: _paystackFeePercentController,
                      hint: '1.5',
                      isDark: isDark,
                      helper: 'Standard Paystack percentage',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Paystack Max Fee Cap (₦)',
                      controller: _paystackFeeCapController,
                      hint: '2000',
                      isDark: isDark,
                      helper: 'Cap on high volume transactions',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: ENTITLEMENTS & AGREEMENTS
  // ==========================================
  Widget _buildEntitlementsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Default Rider Delivery Entitlements', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Standard compensation matrix assigned to newly onboarded delivery agents across the distribution center.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Default Delivery Commission (₦ / drop)',
                      controller: _commissionRateController,
                      hint: '1000',
                      isDark: isDark,
                      helper: 'Base delivery fee per drop',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Default Transport / Fuel Allowance (₦ / drop)',
                      controller: _transportAllowanceController,
                      hint: '1500',
                      isDark: isDark,
                      helper: 'Fuel subsidy per drop',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Failed Attempt Stipend (₦ / drop)',
                      controller: _failedStipendController,
                      hint: '500',
                      isDark: isDark,
                      helper: 'Compensation for verified attempt',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: SETTLEMENT ACCOUNTS
  // ==========================================
  Widget _buildSettlementBankTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DC Corporate Settlement Bank Account', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('The designated corporate banking account into which Paystack transfers and POS handovers settle.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Receiving Bank Name',
                controller: _bankNameController,
                hint: 'Titan Trust Bank',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildInputField(
                label: 'Settlement Account Number (NUBAN)',
                controller: _accountNumberController,
                hint: '0098234123',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildInputField(
                label: 'Account Name',
                controller: _accountNameController,
                hint: 'NovaExpress Logistics Limited',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: AUTOMATION & WEBHOOKS
  // ==========================================
  Widget _buildAutomationTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Consumer(
          builder: (context, ref, _) {
            final autoReconcile = ref.watch(dcSettingsDraftProvider.select((s) => s.autoReconcile));

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Automated Webhook & Reconciliation Rules', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Instant Paystack Auto-Reconciliation', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Automatically settle transactions and clear rider remittance custody as soon as Paystack webhooks fire without waiting for manual supervisor clicks.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: autoReconcile,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) => ref.read(dcSettingsDraftProvider.notifier).setAutoReconcile(val),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // REUSABLE FORM WIDGETS
  // ==========================================
  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF031632)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSimMetricPill(String label, String value, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
