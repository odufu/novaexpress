import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/paystack_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/paystack_web_interop.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/financial_summary.dart';
import '../providers/finance_provider.dart';
import '../widgets/paystack_remittance_modal.dart';

class LogRemittancePage extends ConsumerStatefulWidget {
  const LogRemittancePage({super.key});

  @override
  ConsumerState<LogRemittancePage> createState() => _LogRemittancePageState();
}

class _LogRemittancePageState extends ConsumerState<LogRemittancePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isInitialAmountSet = false;

  String? _selectedDiscrepancyReason;
  bool _hasProofUploaded = false;

  final List<String> _discrepancyReasons = [
    'Cash shortage',
    'Customer payment discrepancy',
    'Approved expense',
    'Previous adjustment',
    'POS/transaction issue',
    'Other',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);
    final user = authState.user;

    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
    );

    final double grossCollections = summary.cashCollectedAllTime;
    final double commissionDeduction = summary.totalCommissionRetained;
    final double transportDeduction = summary.totalTransportRetained;
    final double expectedAmount = summary.pendingRemittanceToDC;

    if (!_isInitialAmountSet && expectedAmount > 0) {
      _isInitialAmountSet = true;
      _amountController.text = expectedAmount.toInt().toString();
    } else if (_amountController.text.isEmpty && expectedAmount > 0) {
      _amountController.text = expectedAmount.toInt().toString();
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final hasDiscrepancy = (enteredAmount - expectedAmount).abs() > 0.01;
    final discrepancyAmount = enteredAmount - expectedAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Remittance',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Settlement & Accountability',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. FINANCIAL SUMMARY HERO CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B192C), Color(0xFF1E3E62)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B192C).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTLEMENT BREAKDOWN',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Gross Customer Collections', CurrencyFormatter.formatNaira(grossCollections), Colors.white),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Less: Commission (${ordersState.orders.where((o) => o.isDelivered).length} deliveries)',
                      '-${CurrencyFormatter.formatNaira(commissionDeduction)}',
                      const Color(0xFF4ADE80),
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Less: Transport Allowance (${ordersState.orders.where((o) => o.isDelivered).length} orders)',
                      '-${CurrencyFormatter.formatNaira(transportDeduction)}',
                      const Color(0xFF38BDF8),
                    ),
                    const Divider(color: Color(0xFF334155), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expected Remittance',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(expectedAmount),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF37021),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. AMOUNT INPUT FIELD
              Text(
                'AMOUNT YOU ARE REMITTING (₦)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_pound, color: AppColors.primary),
                  hintText: 'Enter amount to remit',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter amount to remit';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // 3. DISCREPANCY WARNING BOX (If Applicable)
              if (hasDiscrepancy) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C1C11) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF97316)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            discrepancyAmount < 0
                                ? 'Shortage Discrepancy: ${CurrencyFormatter.formatNaira(discrepancyAmount.abs())}'
                                : 'Overpayment Discrepancy: +${CurrencyFormatter.formatNaira(discrepancyAmount)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEA580C),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select the reason for this variance to log in the financial discrepancy ledger:',
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFFED7AA) : const Color(0xFF9A3412)),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedDiscrepancyReason,
                        hint: Text('Select Reason for Discrepancy', style: GoogleFonts.inter(fontSize: 12)),
                        items: _discrepancyReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                        onChanged: (val) => setState(() => _selectedDiscrepancyReason = val),
                        validator: (val) => hasDiscrepancy && val == null ? 'Reason required for amount variance' : null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 4. PAYSTACK INTERACTIVE GATEWAY PORTAL
              Text(
                'SETTLEMENT METHOD',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00C3F7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A2D3).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Color(0xFF00A2D3), size: 20),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PAYSTACK SECURE GATEWAY',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFF00A2D3),
                                  ),
                                ),
                                Text(
                                  'Official Company Remittance Channel',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: Text('INSTANT ⚡', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Supported Channels Pills
                    Text(
                      'AVAILABLE INTERACTIVE PAYMENT CHANNELS:',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChannelPill(Icons.credit_card_rounded, 'Card (Mastercard/Visa)', isDark),
                        _buildChannelPill(Icons.account_balance_rounded, 'Bank Transfer (Nuban)', isDark),
                        _buildChannelPill(Icons.phone_android_rounded, 'USSD Banking', isDark),
                        _buildChannelPill(Icons.qr_code_2_rounded, 'QR / Apple Pay', isDark),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Info Note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Proceeding will immediately launch the Paystack interactive payment screen. Upon completion, funds are credited instantly and your cash liability resets to ₦0.00.',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. OPTIONAL PROOF & NOTES
              InkWell(
                onTap: () {
                  setState(() => _hasProofUploaded = !_hasProofUploaded);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasProofUploaded
                        ? (isDark ? const Color(0xFF0F274A) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasProofUploaded ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasProofUploaded ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                        color: _hasProofUploaded ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasProofUploaded ? 'Deposit Receipt / Proof Attached' : 'Attach Proof of Payment (Optional)',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _hasProofUploaded ? const Color(0xFF10B981) : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _hasProofUploaded ? 'receipt_proof_remittance_829.jpg' : 'Tap to capture photo or select from gallery',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Additional Operational Notes
              Text('Additional Notes (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any extra remarks for finance team...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              // 6. PROCEED TO REMIT WITH PAYSTACK BUTTON
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: financeState.isLoading ? null : () => _handleProceedToPaystack(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2D3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
                  label: financeState.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Proceed to Pay via Paystack ${CurrencyFormatter.formatNaira(enteredAmount > 0 ? enteredAmount : expectedAmount)} ➔',
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelPill(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00A2D3)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  void _handleProceedToPaystack(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final ordersState = ref.read(ordersProvider);
    final financeState = ref.read(financeProvider);
    final user = authState.user;

    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
    );

    final grossCollections = summary.cashCollectedAllTime;
    final commissionDeduction = summary.totalCommissionRetained;
    final transportDeduction = summary.totalTransportRetained;
    final expectedAmount = summary.pendingRemittanceToDC;
    final enteredAmount = double.tryParse(_amountController.text) ?? expectedAmount;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final riderCodeClean = (user?.deliveryAgentCode ?? 'PDA-7000').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final refCode = 'PSTK-RMT-$riderCodeClean-$timestamp';
    final riderEmail = user?.email ?? 'rider.${riderCodeClean.toLowerCase()}@novaexpress.ng';
    final amountKobo = (enteredAmount * 100).toInt();

    void onPaymentSuccess(String confirmedRef) async {
      final success = await ref.read(financeProvider.notifier).submitRemittance(
            amount: enteredAmount,
            paymentMethod: 'paystack',
            agentId: user?.deliveryAgentId,
            companyId: user?.companyId,
            grossCollections: grossCollections,
            commissionDeducted: commissionDeduction,
            transportAllowanceDeducted: transportDeduction,
            referenceNumber: confirmedRef,
            discrepancyReason: _selectedDiscrepancyReason,
            discrepancyAmount: (enteredAmount - expectedAmount),
            notes: _notesController.text,
          );

      if (success && context.mounted) {
        // Reset entered amount to zero
        setState(() {
          _amountController.text = '0';
          _isInitialAmountSet = true;
        });

        // Trigger DC Console transactions reload
        try {
          ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
        } catch (_) {}

        // Emit notification
        ref.read(notificationsProvider.notifier).emitNotification(
              title: 'Remittance Auto-Verified ⚡',
              message: 'Your cash remittance of ${CurrencyFormatter.formatNaira(enteredAmount)} was instantly verified via Paystack and cleared from your custody.',
              category: 'finance',
              actionRoute: '/cash/history',
            );

        _showSuccessDialog(context, enteredAmount, confirmedRef);
      }
    }

    if (kIsWeb) {
      launchPaystackInlineJs(
        publicKey: PaystackConstants.publicKey,
        email: riderEmail,
        amountKobo: amountKobo,
        reference: refCode,
        metadata: {
          'type': 'remittance',
          'rider_name': '${user?.firstName ?? "Joel"} ${user?.lastName ?? "Rider"}'.trim(),
          'rider_code': user?.deliveryAgentCode ?? 'PDA-7000',
          'agent_id': user?.deliveryAgentId,
        },
        onSuccess: onPaymentSuccess,
        onClose: () {
          // Closed by user via Paystack's official popup close button (x)
        },
      );
    } else {
      // Trigger the interactive Paystack Checkout Screen Modal on mobile / fallback
      PaystackRemittanceModal.show(
        context: context,
        amount: enteredAmount,
        riderName: '${user?.firstName ?? "Joel"} ${user?.lastName ?? "Rider"}'.trim(),
        riderCode: user?.deliveryAgentCode ?? 'PDA-7000',
        riderEmail: user?.email,
        agentId: user?.deliveryAgentId,
        onRemittanceConfirmed: onPaymentSuccess,
      );
    }
  }

  void _showSuccessDialog(BuildContext context, double amount, String reference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Remittance Reconciled',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.formatNaira(amount),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'INSTANTLY VERIFIED ⚡ • REMITTANCE ZEROED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: $reference\nDC Hub: Wuse Distribution Center\nTimestamp: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
