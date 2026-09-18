import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
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

  // Controllers for Merchant Billing & Order Charges
  late TextEditingController _clientDeliveryFeeController;
  late TextEditingController _platformFeeValueController;
  late TextEditingController _failedOrderChargeController;
  late TextEditingController _dailyCutoffTimeController;
  String _platformFeeType = 'flat';
  String _paystackFeeAbsorbedBy = 'merchant';
  bool _merchantGracePeriod = true;

  // Interactive Simulator Controller
  final TextEditingController _simAmountController = TextEditingController(text: '35000');

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final _integerFormat = NumberFormat('#,##0', 'en_US');

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final settings = ref.read(dcConsoleProvider).financeSettings;

    _posFlatRateController = TextEditingController(text: _integerFormat.format(settings.posFlatRate.toInt()));
    _posTierAmountController = TextEditingController(text: _integerFormat.format(settings.posTierAmount.toInt()));
    _posTierFeeController = TextEditingController(text: _integerFormat.format(settings.posTierFee.toInt()));
    _posMaxCapFeeController = TextEditingController(text: _integerFormat.format(settings.posMaxCapFee.toInt()));
    _paystackFeePercentController = TextEditingController(text: settings.paystackDirectFeePercent.toString());
    _paystackFeeCapController = TextEditingController(text: _integerFormat.format(settings.paystackFeeCap.toInt()));

    _commissionRateController = TextEditingController(text: _integerFormat.format(settings.defaultCommissionRate.toInt()));
    _transportAllowanceController = TextEditingController(text: _integerFormat.format(settings.defaultTransportAllowance.toInt()));
    _failedStipendController = TextEditingController(text: _integerFormat.format(settings.defaultFailedStipend.toInt()));

    _bankNameController = TextEditingController(text: settings.settlementBankName);
    _accountNumberController = TextEditingController(text: settings.settlementAccountNumber);
    _accountNameController = TextEditingController(text: settings.settlementAccountName);

    _clientDeliveryFeeController = TextEditingController(text: _currencyFormat.format(settings.defaultClientDeliveryFee));
    _platformFeeValueController = TextEditingController(text: _currencyFormat.format(settings.platformFeeValue));
    _failedOrderChargeController = TextEditingController(text: _currencyFormat.format(settings.failedOrderCharge));
    _dailyCutoffTimeController = TextEditingController(text: settings.dailySettlementCutoffTime);
    _platformFeeType = settings.platformFeeType;
    _paystackFeeAbsorbedBy = settings.paystackFeeAbsorbedBy;

    _posFlatRateController.addListener(_onFieldChanged);
    _posTierAmountController.addListener(_onFieldChanged);
    _posTierFeeController.addListener(_onFieldChanged);
    _posMaxCapFeeController.addListener(_onFieldChanged);
    _commissionRateController.addListener(_onFieldChanged);
    _transportAllowanceController.addListener(_onFieldChanged);
    _clientDeliveryFeeController.addListener(_onFieldChanged);
    _platformFeeValueController.addListener(_onFieldChanged);
    _failedOrderChargeController.addListener(_onFieldChanged);

    _simAmountController.addListener(() {
      final parsed = double.tryParse(_simAmountController.text.replaceAll(',', '').replaceAll('₦', '').trim()) ?? 0.0;
      ref.read(dcSettingsDraftProvider.notifier).setSimAmount(parsed);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _posFlatRateController.removeListener(_onFieldChanged);
    _posTierAmountController.removeListener(_onFieldChanged);
    _posTierFeeController.removeListener(_onFieldChanged);
    _posMaxCapFeeController.removeListener(_onFieldChanged);
    _commissionRateController.removeListener(_onFieldChanged);
    _transportAllowanceController.removeListener(_onFieldChanged);
    _clientDeliveryFeeController.removeListener(_onFieldChanged);
    _platformFeeValueController.removeListener(_onFieldChanged);
    _failedOrderChargeController.removeListener(_onFieldChanged);

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
    _clientDeliveryFeeController.dispose();
    _platformFeeValueController.dispose();
    _failedOrderChargeController.dispose();
    _dailyCutoffTimeController.dispose();
    _simAmountController.dispose();
    super.dispose();
  }

  double _parseField(TextEditingController controller, double fallback) {
    final cleaned = controller.text.replaceAll(',', '').replaceAll('₦', '').replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? fallback;
  }

  Future<void> _saveSettings(bool isDark) async {
    await showAppLoadingDialog(
      context: context,
      message: 'Applying Policy & Rules...',
      subMessage: 'Updating distribution center reconciliation matrices...',
      isDark: isDark,
      task: () async {
        final draft = ref.read(dcSettingsDraftProvider);
        final updated = DCFinanceSettings(
          posChargeMode: draft.chargeMode,
          posFlatRate: _parseField(_posFlatRateController, 350.0),
          posTierAmount: _parseField(_posTierAmountController, 5000.0),
          posTierFee: _parseField(_posTierFeeController, 100.0),
          posMaxCapFee: _parseField(_posMaxCapFeeController, 1500.0),
          isPosFeeReimbursable: draft.isReimbursable,
          paystackDirectFeePercent: _parseField(_paystackFeePercentController, 1.5),
          paystackFeeCap: _parseField(_paystackFeeCapController, 2000.0),
          defaultCommissionRate: _parseField(_commissionRateController, 1000.0),
          defaultTransportAllowance: _parseField(_transportAllowanceController, 1500.0),
          defaultFailedStipend: _parseField(_failedStipendController, 500.0),
          settlementBankName: _bankNameController.text.trim(),
          settlementAccountNumber: _accountNumberController.text.trim(),
          settlementAccountName: _accountNameController.text.trim(),
          autoReconcileWebhooks: draft.autoReconcile,
          defaultClientDeliveryFee: _parseField(_clientDeliveryFeeController, 5000.0),
          platformFeeType: _platformFeeType,
          platformFeeValue: _parseField(_platformFeeValueController, 500.0),
          paystackFeeAbsorbedBy: _paystackFeeAbsorbedBy,
          failedOrderCharge: _parseField(_failedOrderChargeController, 1000.0),
          dailySettlementCutoffTime: _dailyCutoffTimeController.text.trim().isNotEmpty
              ? _dailyCutoffTimeController.text.trim()
              : '22:00',
        );

        ref.read(dcConsoleProvider.notifier).updateFinanceSettings(updated);
        await Future.delayed(const Duration(milliseconds: 300));
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ Finance & POS Remittance Rules successfully saved and applied.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _resetDefaults() {
    const defaults = DCFinanceSettings();
    ref.read(dcSettingsDraftProvider.notifier).reset(defaults);

    _posFlatRateController.text = '350';
    _posTierAmountController.text = '5,000';
    _posTierFeeController.text = '100';
    _posMaxCapFeeController.text = '1,500';
    _paystackFeePercentController.text = '1.5';
    _paystackFeeCapController.text = '2,000';
    _commissionRateController.text = '1,000';
    _transportAllowanceController.text = '1,500';
    _failedStipendController.text = '500';
    _clientDeliveryFeeController.text = '5,000.00';
    _platformFeeValueController.text = '500.00';
    _failedOrderChargeController.text = '1,000.00';
    _dailyCutoffTimeController.text = defaults.dailySettlementCutoffTime;
    setState(() {
      _platformFeeType = defaults.platformFeeType;
      _paystackFeeAbsorbedBy = defaults.paystackFeeAbsorbedBy;
      _merchantGracePeriod = true;
    });

    ref.read(dcConsoleProvider.notifier).updateFinanceSettings(defaults);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Reset to default NovaXpress standard policies.'),
        backgroundColor: Color(0xFF4F46E5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeHubName = ref.watch(dcConsoleProvider.select((s) => s.activeHubName));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Minimalist Header & Save Actions
              _buildPageHeader(isDark, activeHubName, isMobile),

              const SizedBox(height: 16),

              // Seamless Tab Navigation Bar
              _buildSubTabBar(isDark),

              const SizedBox(height: 16),

              // Responsive Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFinanceAndPosTab(isDark, isMobile),
                    _buildEntitlementsTab(isDark, isMobile),
                    _buildMerchantBillingTab(isDark, isMobile),
                    _buildSettlementBankTab(isDark, isMobile),
                    _buildAutomationTab(isDark, isMobile),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TOP HEADER (Exact UI/UX Match)
  // ==========================================
  Widget _buildPageHeader(bool isDark, String activeHubName, bool isMobile) {
    final headerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Distribution Center Policy & Finance Settings',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActiveConfigBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure standard client delivery tariffs, operational maintenance charges, Paystack payment gateway fee absorption policies, and automated settlement rules for Abuja Central hub.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last modified today, 08:45 AM',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetDefaults,
                        icon: const Icon(Icons.restore_rounded, size: 15, color: Color(0xFF0F172A)),
                        label: Text(
                          'Reset Defaults',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveSettings(isDark),
                        icon: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                        label: Text(
                          'Apply & Save Rules',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Distribution Center Policy & Finance Settings',
                              style: GoogleFonts.inter(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildActiveConfigBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Configure standard client delivery tariffs, operational maintenance charges, Paystack payment gateway fee absorption policies, and automated settlement rules for Abuja Central hub.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Last modified today, 08:45 AM',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.restore_rounded, size: 15, color: Color(0xFF0F172A)),
                  label: Text(
                    'Reset Defaults',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _saveSettings(isDark),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Apply & Save Rules',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveConfigBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4F46E5),
              height: 1.1,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'CONFIGURATION',
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4F46E5),
              height: 1.1,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SEAMLESS SUB-TAB BAR (Exact UI/UX Match)
  // ==========================================
  Widget _buildSubTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFF4F46E5),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF4F46E5),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale_outlined, size: 16),
                SizedBox(width: 8),
                Text('Finance & POS Rules'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 16),
                SizedBox(width: 8),
                Text('Rider Entitlements'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 16),
                SizedBox(width: 8),
                Text('Merchant Billing & Charges'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_outlined, size: 16),
                SizedBox(width: 8),
                Text('Settlement Accounts'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code_rounded, size: 16),
                SizedBox(width: 8),
                Text('Automation & Webhooks'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: FINANCE & POS RULES (Exact UI/UX Match)
  // ==========================================
  Widget _buildFinanceAndPosTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // 1. POS Transfer Fee Strategy Card
        Consumer(
          builder: (context, ref, _) {
            final chargeMode = ref.watch(dcSettingsDraftProvider.select((s) => s.chargeMode));
            final isReimbursable = ref.watch(dcSettingsDraftProvider.select((s) => s.isReimbursable));

            return Container(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Dynamic Active badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POS Transfer Fee Strategy',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Strategy for cash handover transfers and rider reimbursement thresholds.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chargeMode == 'dynamic' ? 'DYNAMIC ACTIVE' : 'FLAT RATE ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Strategy Choice Cards (Dynamic vs Flat Rate)
                  if (isMobile) ...[
                    _buildDynamicStrategyCard(
                      isSelected: chargeMode == 'dynamic',
                      onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('dynamic'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildFlatStrategyCard(
                      isSelected: chargeMode == 'flat',
                      onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('flat'),
                      isDark: isDark,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildDynamicStrategyCard(
                            isSelected: chargeMode == 'dynamic',
                            onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('dynamic'),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildFlatStrategyCard(
                            isSelected: chargeMode == 'flat',
                            onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('flat'),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Tiered Fee Parameters
                  if (chargeMode == 'dynamic') ...[
                    Text(
                      'TIERED FEE PARAMETERS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMobile) ...[
                      _buildStyledCurrencyInput(
                        label: 'Tier Step Amount (₦)',
                        controller: _posTierAmountController,
                        hint: '5,000',
                        helper: 'Bracket increment size in Naira',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildStyledCurrencyInput(
                        label: 'Fee per Tier (₦)',
                        controller: _posTierFeeController,
                        hint: '100',
                        helper: 'Cost charged per bracket increment',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildStyledCurrencyInput(
                        label: 'Maximum Cap Fee (₦)',
                        controller: _posMaxCapFeeController,
                        hint: '1,500',
                        helper: 'Maximum charge ceiling per transfer',
                        isDark: isDark,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildStyledCurrencyInput(
                              label: 'Tier Step Amount (₦)',
                              controller: _posTierAmountController,
                              hint: '5,000',
                              helper: 'Bracket increment size in Naira',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStyledCurrencyInput(
                              label: 'Fee per Tier (₦)',
                              controller: _posTierFeeController,
                              hint: '100',
                              helper: 'Cost charged per bracket increment',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStyledCurrencyInput(
                              label: 'Maximum Cap Fee (₦)',
                              controller: _posMaxCapFeeController,
                              hint: '1,500',
                              helper: 'Maximum charge ceiling per transfer',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    _buildStyledCurrencyInput(
                      label: 'Fixed Flat POS Transfer Fee (₦)',
                      controller: _posFlatRateController,
                      hint: '350',
                      helper: 'Fixed standard flat fee per cash deposit regardless of remittance size',
                      isDark: isDark,
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Reimbursable policy switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Reimburses POS Transfer Fees',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rider retains POS charge from collected cash and it is automatically deducted into daily vault reconciliation.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isReimbursable,
                        activeColor: const Color(0xFF4F46E5),
                        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        onChanged: (val) => ref.read(dcSettingsDraftProvider.notifier).setReimbursable(val),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // 2. LIVE FINANCIAL RECONCILIATION SIMULATOR Card (Exact UI/UX Match)
        Consumer(
          builder: (context, ref, _) {
            final draft = ref.watch(dcSettingsDraftProvider);
            final chargeMode = draft.chargeMode;
            final simAmount = draft.simAmount;
            final isReimbursable = draft.isReimbursable;

            final tierAmount = _parseField(_posTierAmountController, 5000.0);
            final feePerTier = _parseField(_posTierFeeController, 100.0);
            final maxCap = _parseField(_posMaxCapFeeController, 1500.0);
            final flatRate = _parseField(_posFlatRateController, 350.0);

            final tiersCount = tierAmount > 0 ? (simAmount / tierAmount).ceil() : 1;
            final posFee = chargeMode == 'flat'
                ? flatRate
                : (tiersCount * feePerTier).clamp(feePerTier, maxCap);

            final commission = _parseField(_commissionRateController, 1000.0);
            final transport = _parseField(_transportAllowanceController, 1500.0);
            final riderAllowance = commission + transport;
            final netToVault = (simAmount - riderAllowance - (isReimbursable ? posFee : 0.0)).clamp(0.0, double.infinity);

            return Container(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                color: const Color(0xFF131835),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF252D5E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E254E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.calculate_outlined, color: Color(0xFF818CF8), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIVE FINANCIAL RECONCILIATION SIMULATOR',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Interactive payout formula benchmark test for rider Cash-on-Delivery handover',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2245),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2E3868)),
                        ),
                        child: Text(
                          chargeMode == 'dynamic' ? 'Mode: Dynamic Tiered' : 'Mode: Flat Rate',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Content: Left Input + Right 4 KPI Cards
                  if (isMobile) ...[
                    _buildSimSampleInput(isDark),
                    const SizedBox(height: 16),
                    _buildSimKpiCard(
                      label: 'GROSS CASH',
                      value: '₦${_currencyFormat.format(simAmount)}',
                      subtitle: 'Rider Handover',
                      valColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    _buildSimKpiCard(
                      label: 'POS FEE',
                      extraTag: chargeMode == 'dynamic' ? '($tiersCount TIERS)' : null,
                      badgeText: isReimbursable ? 'Reimbursed' : null,
                      value: '-₦${_currencyFormat.format(posFee)}',
                      subtitle: chargeMode == 'dynamic' ? '₦${feePerTier.toInt()} × $tiersCount brackets' : 'Fixed Flat Rate',
                      valColor: const Color(0xFFF87171),
                    ),
                    const SizedBox(height: 10),
                    _buildSimKpiCard(
                      label: 'RIDER ALLOWANCE',
                      value: '-₦${_currencyFormat.format(riderAllowance)}',
                      subtitle: 'Fixed order trip payout',
                      valColor: const Color(0xFFFBBF24),
                    ),
                    const SizedBox(height: 10),
                    _buildSimKpiCard(
                      label: 'NET TO VAULT',
                      hasDot: true,
                      value: '₦${_currencyFormat.format(netToVault)}',
                      subtitle: 'Hub Cash Inflow',
                      valColor: const Color(0xFF34D399),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Input Field Box
                        SizedBox(
                          width: 250,
                          child: _buildSimSampleInput(isDark),
                        ),
                        const SizedBox(width: 16),

                        // Right 4 KPI Cards
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSimKpiCard(
                                  label: 'GROSS CASH',
                                  value: '₦${_currencyFormat.format(simAmount)}',
                                  subtitle: 'Rider Handover',
                                  valColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSimKpiCard(
                                  label: 'POS FEE',
                                  extraTag: chargeMode == 'dynamic' ? '($tiersCount TIERS)' : null,
                                  badgeText: isReimbursable ? 'Reimbursed' : null,
                                  value: '-₦${_currencyFormat.format(posFee)}',
                                  subtitle: chargeMode == 'dynamic' ? '₦${feePerTier.toInt()} × $tiersCount brackets' : 'Fixed Flat Rate',
                                  valColor: const Color(0xFFF87171),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSimKpiCard(
                                  label: 'RIDER ALLOWANCE',
                                  value: '-₦${_currencyFormat.format(riderAllowance)}',
                                  subtitle: 'Fixed order trip payout',
                                  valColor: const Color(0xFFFBBF24),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSimKpiCard(
                                  label: 'NET TO VAULT',
                                  hasDot: true,
                                  value: '₦${_currencyFormat.format(netToVault)}',
                                  subtitle: 'Hub Cash Inflow',
                                  valColor: const Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Dynamic Formula Banner (Exact Match to UI/UX Design)
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F142D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF222B57)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF818CF8), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Formula: ',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                children: [
                                  const TextSpan(text: 'Net Vault = Gross Cash (₦'),
                                  TextSpan(text: _integerFormat.format(simAmount.toInt())),
                                  const TextSpan(text: ') - ['),
                                  if (isReimbursable) ...[
                                    const TextSpan(text: 'POS Reimbursement (₦'),
                                    TextSpan(text: _integerFormat.format(posFee.toInt())),
                                    const TextSpan(text: ') + '),
                                  ],
                                  const TextSpan(text: 'Rider Cut (₦'),
                                  TextSpan(text: _integerFormat.format(riderAllowance.toInt())),
                                  const TextSpan(text: ')]'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF059669)),
                          ),
                          child: Text(
                            'Balanced Ledger',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF34D399),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),
        // 3. Paystack & Direct Gateway Charges Card (Exact UI/UX Match)
        _buildPaystackGatewayChargesCard(cardBg, borderColor, isDark, isMobile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPaystackGatewayChargesCard(
    Color cardBg,
    Color borderColor,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                    Row(
                      children: [
                        Text(
                          'Paystack & Direct Gateway Charges',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            'Automated Webhook',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gateway commission deducted on incoming card, USSD, and virtual account direct merchant collections.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Text(
                  'Channel: Live production',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile) ...[
            _buildStyledCurrencyInput(
              label: 'Direct Paystack Fee (%)',
              controller: _paystackFeePercentController,
              hint: '1.5',
              prefix: '',
              suffix: '%',
              helper: 'Standard Paystack transaction percentage for Nigeria local debit cards.',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _buildStyledCurrencyInput(
              label: 'Paystack Max Fee Cap (₦)',
              controller: _paystackFeeCapController,
              hint: '2,000',
              prefix: '₦',
              helper: 'Fee cap ceiling applied to high volume single checkout orders.',
              isDark: isDark,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildStyledCurrencyInput(
                    label: 'Direct Paystack Fee (%)',
                    controller: _paystackFeePercentController,
                    hint: '1.5',
                    prefix: '',
                    suffix: '%',
                    helper: 'Standard Paystack transaction percentage for Nigeria local debit cards.',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildStyledCurrencyInput(
                    label: 'Paystack Max Fee Cap (₦)',
                    controller: _paystackFeeCapController,
                    hint: '2,000',
                    prefix: '₦',
                    helper: 'Fee cap ceiling applied to high volume single checkout orders.',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFDBEAFE),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated Paystack Split Settlements',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Settlement runs automatically at 23:00 GMT+1 daily. Gateway fees are absorbed in accordance with the Merchant contract profile configured under the Merchant Billing tab.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF3B82F6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDynamicStrategyCard({
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
          color: isSelected ? const Color(0xFFFFFFFF) : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Dynamic Tiered Scaling',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      text: 'Fee scales proportionally with transfer amount ',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      children: [
                        TextSpan(
                          text: '(₦100 per ₦5,000 cash)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatStrategyCard({
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
          color: isSelected ? const Color(0xFFFFFFFF) : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.tag_rounded, color: Color(0xFF64748B), size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flat Rate Fee',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Fixed standard flat fee per cash deposit regardless of remittance size',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimSampleInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sample Collected Cash (₦)',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2245),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E3868)),
          ),
          child: Row(
            children: [
              Text(
                '₦ ',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF818CF8),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _simAmountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text('Min: ₦1,000', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
            Text('Default: ₦35,000', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
            Text('Max: ₦200,000', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildSimKpiCard({
    required String label,
    required String value,
    required String subtitle,
    required Color valColor,
    String? extraTag,
    String? badgeText,
    bool hasDot = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2B335C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              if (extraTag != null)
                Text(
                  extraTag,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF87171),
                    ),
                  ),
                ),
              if (hasDot)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: valColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: MERCHANT BILLING & CHARGES (Exact UI/UX Match)
  // ==========================================
  Widget _buildMerchantBillingTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final currentDeliveryFee = _parseField(_clientDeliveryFeeController, 5000.0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // 1. Standard Logistics Delivery Fee Card
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with AUTOMATED TARIFF badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard Logistics Delivery Fee',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Base tariff deducted from client sales revenue per delivered parcel across Abuja distribution circuits.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AUTOMATED TARIFF',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4F46E5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Inputs Row: Default Delivery Fee + Zone Presets
              if (isMobile) ...[
                _buildStyledCurrencyInput(
                  label: 'Default Delivery Fee (₦)',
                  controller: _clientDeliveryFeeController,
                  hint: '5,000.00',
                  helper: 'Applied when merchant has no custom contractual rate override; standard baseline ₦5,000.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Text(
                  'Standard Hub Delivery Zone Presets',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildZonePresetChip(
                      label: 'Intra-Abuja (Standard): ₦5,000',
                      isSelected: (currentDeliveryFee - 5000.0).abs() < 1.0,
                      onTap: () {
                        _clientDeliveryFeeController.text = '5,000.00';
                        setState(() {});
                      },
                    ),
                    _buildZonePresetChip(
                      label: 'Express Same-Day: ₦7,500',
                      isSelected: (currentDeliveryFee - 7500.0).abs() < 1.0,
                      onTap: () {
                        _clientDeliveryFeeController.text = '7,500.00';
                        setState(() {});
                      },
                    ),
                    _buildZonePresetChip(
                      label: 'Outskirts / Airport: ₦8,500',
                      isSelected: (currentDeliveryFee - 8500.0).abs() < 1.0,
                      onTap: () {
                        _clientDeliveryFeeController.text = '8,500.00';
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Preset rates synchronize automatically with dispatch routing and rider job manifests.',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildStyledCurrencyInput(
                        label: 'Default Delivery Fee (₦)',
                        controller: _clientDeliveryFeeController,
                        hint: '5,000.00',
                        helper: 'Applied when merchant has no custom contractual rate override; standard baseline ₦5,000.',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Standard Hub Delivery Zone Presets',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildZonePresetChip(
                                label: 'Intra-Abuja (Standard): ₦5,000',
                                isSelected: (currentDeliveryFee - 5000.0).abs() < 1.0,
                                onTap: () {
                                  _clientDeliveryFeeController.text = '5,000.00';
                                  setState(() {});
                                },
                              ),
                              _buildZonePresetChip(
                                label: 'Express Same-Day: ₦7,500',
                                isSelected: (currentDeliveryFee - 7500.0).abs() < 1.0,
                                onTap: () {
                                  _clientDeliveryFeeController.text = '7,500.00';
                                  setState(() {});
                                },
                              ),
                              _buildZonePresetChip(
                                label: 'Outskirts / Airport: ₦8,500',
                                isSelected: (currentDeliveryFee - 8500.0).abs() < 1.0,
                                onTap: () {
                                  _clientDeliveryFeeController.text = '8,500.00';
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Preset rates synchronize automatically with dispatch routing and rider job manifests.',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Platform Operational Charges & Surcharges Card
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with SYSTEM BILLING badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Operational Charges & Surcharges',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Operational maintenance deductions, platform infrastructure fees, and reverse logistics surcharges.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SYSTEM BILLING',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Two Inner Cards (Platform Tech Infrastructure Fee & Failed Delivery)
              if (isMobile) ...[
                _buildPlatformFeeCard(isDark),
                const SizedBox(height: 12),
                _buildFailedDeliveryCard(isDark),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPlatformFeeCard(isDark)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildFailedDeliveryCard(isDark)),
                  ],
                ),
              ],

              const SizedBox(height: 18),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Merchant Grace Period Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merchant Grace Period (Failed Deliveries)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exempt first 2 failed delivery attempts per calendar month before assessing reverse logistics penalties.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _merchantGracePeriod,
                    activeColor: const Color(0xFF4F46E5),
                    activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    onChanged: (val) => setState(() => _merchantGracePeriod = val),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlatformFeeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Tech Infrastructure Fee',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              // Segmented toggle pill
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _platformFeeType = 'flat'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: _platformFeeType == 'flat' ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Flat (₦)',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _platformFeeType == 'flat' ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _platformFeeType = 'percent'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: _platformFeeType == 'percent' ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Percentage (%)',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _platformFeeType == 'percent' ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStyledCurrencyInput(
            label: '',
            controller: _platformFeeValueController,
            hint: _platformFeeType == 'flat' ? '500.00' : '2.5',
            prefix: _platformFeeType == 'flat' ? '₦' : '%',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Text(
            'Dedicated platform tech infrastructure & live customer tracking fee charged per order.',
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedDeliveryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Failed Delivery / Reverse Logistics',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  'RTO Penalty',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStyledCurrencyInput(
            label: '',
            controller: _failedOrderChargeController,
            hint: '1,000.00',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Text(
            'Administrative return transit & QC restocking surcharge for customer-rejected or cancelled deliveries.',
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildZonePresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: ENTITLEMENTS & AGREEMENTS
  // ==========================================
  Widget _buildEntitlementsTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Default Rider Delivery Entitlements',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Standard compensation matrix for onboarded delivery agents across hub drop routes.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              if (isMobile) ...[
                _buildStyledCurrencyInput(
                  label: 'Delivery Commission (₦ / drop)',
                  controller: _commissionRateController,
                  hint: '1,000',
                  helper: 'Base delivery fee per drop',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStyledCurrencyInput(
                  label: 'Transport Allowance (₦ / drop)',
                  controller: _transportAllowanceController,
                  hint: '1,500',
                  helper: 'Fuel & transit subsidy per drop',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStyledCurrencyInput(
                  label: 'Failed Attempt Stipend (₦ / drop)',
                  controller: _failedStipendController,
                  hint: '500',
                  helper: 'Compensation for verified dispatch attempt',
                  isDark: isDark,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStyledCurrencyInput(
                        label: 'Delivery Commission (₦ / drop)',
                        controller: _commissionRateController,
                        hint: '1,000',
                        helper: 'Base delivery fee per drop',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStyledCurrencyInput(
                        label: 'Transport Allowance (₦ / drop)',
                        controller: _transportAllowanceController,
                        hint: '1,500',
                        helper: 'Fuel & transit subsidy per drop',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStyledCurrencyInput(
                        label: 'Failed Attempt Stipend (₦ / drop)',
                        controller: _failedStipendController,
                        hint: '500',
                        helper: 'Compensation for verified dispatch attempt',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: SETTLEMENT ACCOUNTS
  // ==========================================
  Widget _buildSettlementBankTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DC Corporate Settlement Bank Account',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Designated corporate bank account for Paystack transfers & POS terminal settlements.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildStyledCurrencyInput(
                label: 'Receiving Bank Name',
                controller: _bankNameController,
                hint: 'Titan Trust Bank',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Settlement Account Number (NUBAN)',
                controller: _accountNumberController,
                hint: '0098234123',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Account Name',
                controller: _accountNameController,
                hint: 'NovaXpress Logistics Limited',
                prefix: '',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 5: AUTOMATION & WEBHOOKS
  // ==========================================
  Widget _buildAutomationTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Consumer(
          builder: (context, ref, _) {
            final autoReconcile = ref.watch(dcSettingsDraftProvider.select((s) => s.autoReconcile));

            return Container(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automated Webhook & Reconciliation',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Paystack Auto-Reconciliation',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Automatically settle transactions and clear rider remittance custody as soon as Paystack webhooks fire without manual clicks.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: autoReconcile,
                        activeColor: const Color(0xFF4F46E5),
                        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        onChanged: (val) => ref.read(dcSettingsDraftProvider.notifier).setAutoReconcile(val),
                      ),
                    ],
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
  Widget _buildStyledCurrencyInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String prefix = '₦',
    String suffix = '',
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (prefix.isNotEmpty) ...[
                Text(
                  prefix,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 5),
          Text(
            helper,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
}