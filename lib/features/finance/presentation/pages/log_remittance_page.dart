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
  bool _isInitialAmountSet = false;

  String? _selectedDiscrepancyReason;

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
    final double transferFeeDeduction = summary.totalTransferFeesRetained;
    final double expectedAmount = summary.pendingRemittanceToDC;
    final int deliveredCount = ordersState.orders.where((o) => o.isDelivered).length;

    if (!_isInitialAmountSet && expectedAmount > 0) {
      _isInitialAmountSet = true;
      _amountController.text = expectedAmount.toInt().toString();
    } else if (_amountController.text.isEmpty && expectedAmount > 0) {
      _amountController.text = expectedAmount.toInt().toString();
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final hasDiscrepancy = (enteredAmount - expectedAmount).abs() > 0.01 && expectedAmount > 0;
    final discrepancyAmount = enteredAmount - expectedAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131D38) : Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. OPTIMIZED SETTLEMENT BREAKDOWN HERO CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SETTLEMENT BREAKDOWN',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A2D3).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$deliveredCount Orders',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gross Collections
                    _buildMetricRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      label: 'Gross Collections',
                      value: CurrencyFormatter.formatNaira(grossCollections),
                      valueColor: Colors.white,
                    ),
                    const SizedBox(height: 10),

                    // Commission Deducted
                    _buildMetricRow(
                      icon: Icons.content_cut_rounded,
                      iconColor: const Color(0xFF4ADE80),
                      label: 'Less: Commission',
                      value: '-${CurrencyFormatter.formatNaira(commissionDeduction)}',
                      valueColor: const Color(0xFF4ADE80),
                    ),
                    const SizedBox(height: 10),

                    // Transport Allowance Deducted
                    _buildMetricRow(
                      icon: Icons.local_gas_station_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      label: 'Less: Fuel/Transport',
                      value: '-${CurrencyFormatter.formatNaira(transportDeduction)}',
                      valueColor: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 10),

                    // Transfer / Transaction Charge Deducted
                    _buildMetricRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Less: Transfer Charge',
                      value: '-${CurrencyFormatter.formatNaira(transferFeeDeduction)}',
                      valueColor: const Color(0xFFF59E0B),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFF334155), height: 1),
                    ),

                    // Expected Remittance Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFF97316), size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Expected Remittance',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(expectedAmount),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 2. AMOUNT INPUT FIELD
              Text(
                'AMOUNT YOU ARE REMITTING (₦)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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

              // 3. DISCREPANCY WARNING BOX (If Applicable)
              if (hasDiscrepancy) ...[
                const SizedBox(height: 14),
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
              ],

              const SizedBox(height: 28),

              // 4. PROCEED TO PAY VIA PAYSTACK BUTTON
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: financeState.isLoading
                      ? null
                      : () => _handleProceedToPaystack(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2D3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  icon: financeState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
                  label: Text(
                    'Proceed to Pay via Paystack ${CurrencyFormatter.formatNaira(enteredAmount > 0 ? enteredAmount : expectedAmount)} ➔',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor),
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

    void onPaymentFailure(String message) {
      if (context.mounted) {
        _showFailureCard(context, message);
      }
    }

    void onPaymentSuccess(String confirmedRef) async {
      final remainingAfterPayment = (expectedAmount - enteredAmount).clamp(0.0, double.infinity);
      final isPartial = enteredAmount < expectedAmount && expectedAmount > 0;

      final success = await ref.read(financeProvider.notifier).submitRemittance(
            amount: enteredAmount,
            paymentMethod: 'paystack',
            agentId: user?.deliveryAgentId,
            companyId: user?.companyId,
            grossCollections: grossCollections,
            commissionDeducted: commissionDeduction,
            transportAllowanceDeducted: transportDeduction,
            referenceNumber: confirmedRef,
            discrepancyReason: _selectedDiscrepancyReason ?? (isPartial ? 'Partial Remittance' : null),
            discrepancyAmount: (enteredAmount - expectedAmount),
            expectedAmount: expectedAmount,
            isPartial: isPartial,
          );

      if (success && context.mounted) {
        setState(() {
          _amountController.text = isPartial ? remainingAfterPayment.toInt().toString() : '0';
          _isInitialAmountSet = true;
        });

        try {
          ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
        } catch (_) {}

        ref.read(notificationsProvider.notifier).emitNotification(
              title: isPartial ? 'Partial Remittance Verified ⚡' : 'Remittance Auto-Verified ⚡',
              message: isPartial
                  ? 'Your partial remittance of ${CurrencyFormatter.formatNaira(enteredAmount)} was verified. Remaining balance: ${CurrencyFormatter.formatNaira(remainingAfterPayment)}.'
                  : 'Your cash remittance of ${CurrencyFormatter.formatNaira(enteredAmount)} was instantly verified via Paystack and cleared from your custody.',
              category: 'finance',
              actionRoute: '/cash/history',
            );

        _showSuccessCard(context, enteredAmount, confirmedRef, remainingAfterPayment, isPartial);
      } else {
        onPaymentFailure('Could not record verified remittance to ledger. Please check network.');
      }
    }

    void showFallbackModal() {
      if (!context.mounted) return;
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
          'expected_amount': expectedAmount,
          'discrepancy_reason': _selectedDiscrepancyReason,
        },
        onSuccess: onPaymentSuccess,
        onClose: () {
          // Closed by user via top-left Close button
        },
        onFallback: showFallbackModal,
      );
    } else {
      showFallbackModal();
    }
  }

  void _showSuccessCard(
    BuildContext context,
    double amount,
    String reference,
    double remainingBalance,
    bool isPartial,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isPartial ? const Color(0xFFF97316) : const Color(0xFF16A34A),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isPartial ? const Color(0xFFF97316) : const Color(0xFF16A34A)).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPartial ? Icons.published_with_changes_rounded : Icons.check_circle_rounded,
                color: isPartial ? const Color(0xFFFB923C) : const Color(0xFF4ADE80),
                size: 54,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isPartial ? 'Partial Remittance Paid' : 'Remittance Reconciled',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.formatNaira(amount),
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isPartial ? const Color(0xFFFB923C) : const Color(0xFF4ADE80),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isPartial ? const Color(0xFFF97316) : const Color(0xFF16A34A)).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPartial
                    ? 'PARTIAL • REMAINING TO REMIT: ${CurrencyFormatter.formatNaira(remainingBalance)}'
                    : 'VERIFIED VIA PAYSTACK ⚡ • BALANCE: ₦0.00',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isPartial ? const Color(0xFFFB923C) : const Color(0xFF4ADE80),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildReceiptItem('Reference', reference),
                  const SizedBox(height: 6),
                  _buildReceiptItem('Hub', 'Wuse Distribution Center'),
                  const SizedBox(height: 6),
                  _buildReceiptItem('Payment Status', 'Verified via Paystack ⚡'),
                  if (isPartial) ...[
                    const SizedBox(height: 6),
                    _buildReceiptItem('Remaining Balance', CurrencyFormatter.formatNaira(remainingBalance)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2D3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done • Back to Dashboard', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailureCard(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Unsuccessful',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
