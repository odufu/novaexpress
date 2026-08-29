import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../../core/services/paystack_gateway_launcher.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/remittance.dart';
import '../providers/finance_provider.dart';

final logRemittanceEnteredAmountProvider = StateProvider.autoDispose<double>((ref) => 0.0);
final logRemittanceDiscrepancyReasonProvider = StateProvider.autoDispose<String?>((ref) => null);
final logRemittanceInitialSetProvider = StateProvider.autoDispose<bool>((ref) => false);

class LogRemittancePage extends ConsumerStatefulWidget {
  const LogRemittancePage({super.key});

  @override
  ConsumerState<LogRemittancePage> createState() => _LogRemittancePageState();
}

class _LogRemittancePageState extends ConsumerState<LogRemittancePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

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

    final isInitialAmountSet = ref.watch(logRemittanceInitialSetProvider);
    final selectedDiscrepancyReason = ref.watch(logRemittanceDiscrepancyReasonProvider);

    final dcFinanceSettings = ref.watch(dcConsoleProvider).financeSettings;
    final commissionRate = user?.commissionRate ?? 1000.0;
    final transportPerOrder = user?.isPda == false
        ? (user?.fuelAllowance ?? 800.0)
        : (user?.transportAllowance ?? 1500.0);
    final failedStipendRate = user?.failedDeliveryAllowance ?? (user?.isPda == true ? 500.0 : 300.0);

    final deliveredOrders = ordersState.orders.where((o) => o.isDelivered).toList();
    final deliveredCashOrders = deliveredOrders.where((o) => o.isCashPod).toList();
    final failedOrders = ordersState.orders.where((o) => o.status == 'failed' || o.status == 'failed_attempt').toList();
    final double failedStipendsDeduction = failedOrders.length * failedStipendRate;

    final double grossCash = deliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double posFeeDeduction = (grossCash > 0 && dcFinanceSettings.isPosFeeReimbursable)
        ? dcFinanceSettings.computePosFee(grossCash)
        : 0.0;

    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
      transactions: financeState.transactions,
      posFee: posFeeDeduction,
    );

    final double grossCollections = summary.cashCollectedAllTime;
    final double commissionDeduction = summary.totalCommissionRetained;
    final double transportDeduction = summary.totalTransportRetained;
    final double transferFeeDeduction = posFeeDeduction;
    final double expectedAmount = summary.pendingRemittanceToDC;
    final int deliveredCount = deliveredOrders.length;
    final int failedCount = failedOrders.length;

    final unremittedDeliveredOrders = deliveredOrders
        .where((o) => !o.isRemitted && o.paymentStatus.toLowerCase() != 'remitted')
        .toList();

    // Snapshot of orders contributing to this remittance with itemized breakdown (collections - commission - transport)
    final List<RemittanceOrderItem> associatedOrderItems = [
      ...unremittedDeliveredOrders.map((o) {
        final cash = o.isCashPod ? o.totalAmount : 0.0;
        final comm = o.agentEntitlement > 0 ? o.agentEntitlement : commissionRate;
        return RemittanceOrderItem(
          orderId: o.id,
          orderNumber: o.orderNumber,
          customerName: o.customerName,
          status: o.status,
          paymentType: o.paymentType,
          cashCollected: cash,
          riderCommission: comm,
          transportAllowance: transportPerOrder,
          failedStipend: 0.0,
          posFee: 0.0,
          date: o.createdAt,
        );
      }),
      ...failedOrders.map((o) {
        return RemittanceOrderItem(
          orderId: o.id,
          orderNumber: o.orderNumber,
          customerName: o.customerName,
          status: o.status,
          paymentType: o.paymentType,
          cashCollected: 0.0,
          riderCommission: 0.0,
          transportAllowance: 0.0,
          failedStipend: failedStipendRate,
          posFee: 0.0,
          date: o.createdAt,
        );
      }),
    ];

    if (!isInitialAmountSet && expectedAmount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(logRemittanceInitialSetProvider.notifier).state = true;
        _amountController.text = expectedAmount.toInt().toString();
        ref.read(logRemittanceEnteredAmountProvider.notifier).state = expectedAmount;
      });
    } else if (_amountController.text.isEmpty && expectedAmount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _amountController.text = expectedAmount.toInt().toString();
        ref.read(logRemittanceEnteredAmountProvider.notifier).state = expectedAmount;
      });
    }

    final enteredAmount = ref.watch(logRemittanceEnteredAmountProvider);
    final hasDiscrepancy = (enteredAmount - expectedAmount).abs() > 0.01 && expectedAmount > 0;
    final discrepancyAmount = enteredAmount - expectedAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remit Cash to DC',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Automatic Paystack Verification ⚡',
              style: GoogleFonts.inter(
                color: const Color(0xFF16A34A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
              // 1. RECONCILIATION AUDIT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'CASH BREAKDOWN & RETENTIONS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            failedCount > 0 ? '$deliveredCount Deliveries • $failedCount Failed' : '$deliveredCount Deliveries',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildAuditRow('Total Cash Collected (POD):', CurrencyFormatter.formatNaira(grossCollections), isDark),
                    const Divider(height: 16),
                    _buildAuditRow('Less: Delivery Commissions Retained:', '-${CurrencyFormatter.formatNaira(commissionDeduction)}', isDark, valueColor: const Color(0xFF16A34A)),
                    const Divider(height: 16),
                    _buildAuditRow('Less: Transport Allowance Retained:', '-${CurrencyFormatter.formatNaira(transportDeduction)}', isDark, valueColor: const Color(0xFF2563EB)),
                    if (failedStipendsDeduction > 0) ...[
                      const Divider(height: 16),
                      _buildAuditRow('Less: Failed Attempt Stipends ($failedCount Drops):', '-${CurrencyFormatter.formatNaira(failedStipendsDeduction)}', isDark, valueColor: const Color(0xFFD97706)),
                    ],
                    if (transferFeeDeduction > 0) ...[
                      const Divider(height: 16),
                      _buildAuditRow('Less: POS / Transfer Fees Retained:', '-${CurrencyFormatter.formatNaira(transferFeeDeduction)}', isDark, valueColor: const Color(0xFF0284C7)),
                    ],
                    const Divider(height: 16),

                    // Expected Net Remittance
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Net Due for Remittance:',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                                Text(
                                  'Must be paid to clear custody',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.formatNaira(expectedAmount),
                              style: GoogleFonts.inter(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  ref.read(logRemittanceEnteredAmountProvider.notifier).state = double.tryParse(val) ?? 0.0;
                },
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
                          Expanded(
                            child: Text(
                              discrepancyAmount < 0
                                  ? 'Shortage Discrepancy: ${CurrencyFormatter.formatNaira(discrepancyAmount.abs())}'
                                  : 'Overpayment Discrepancy: +${CurrencyFormatter.formatNaira(discrepancyAmount)}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEA580C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedDiscrepancyReason,
                        hint: Text('Select Reason for Discrepancy', style: GoogleFonts.inter(fontSize: 12)),
                        items: _discrepancyReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          ref.read(logRemittanceDiscrepancyReasonProvider.notifier).state = val;
                        },
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
              const SizedBox(height: 18),

              // 4. INSTANT AUTO-VERIFICATION BANNER (PAYSTACK ONLY)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF00A2D3), size: 24),
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
                                  'Paystack Remittance Portal',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AUTO-SETTLE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Remit easily via Card, Dedicated Virtual NUBAN Account, or USSD (*737#). Once paid, NovaExpress automatically updates your cash in custody without manual DC receipts.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. MAIN REMIT CTA BUTTON (TRIGGER PAYSTACK POPUP DIRECTLY)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: financeState.isLoading
                      ? null
                      : () => _handlePaystackRemit(
                          context,
                          enteredAmount,
                          user,
                          grossCollections,
                          commissionDeduction,
                          transportDeduction,
                          failedStipendsDeduction,
                          transferFeeDeduction,
                          expectedAmount,
                          associatedOrderItems,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2D3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: financeState.isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                  label: financeState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Remit ${CurrencyFormatter.formatNaira(enteredAmount > 0 ? enteredAmount : expectedAmount)} via Paystack ⚡',
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePaystackRemit(
    BuildContext context,
    double enteredAmount,
    dynamic user,
    double grossCollections,
    double commissionDeduction,
    double transportDeduction,
    double failedStipendsDeduction,
    double posFeeDeduction,
    double expectedAmount,
    List<RemittanceOrderItem> associatedOrders,
  ) {
    final rawText = _amountController.text.replaceAll(',', '').replaceAll('₦', '').trim();
    final parsed = double.tryParse(rawText);
    final finalAmount = (parsed != null && parsed > 0)
        ? parsed
        : (enteredAmount > 0 ? enteredAmount : expectedAmount);

    if (finalAmount <= 0) {
      _onPaymentFailure(context, 'Please enter a valid amount to remit.');
      return;
    }

    final isPartial = finalAmount < expectedAmount;
    final remainingAfterPayment = (expectedAmount - finalAmount).clamp(0.0, double.infinity);
    final hasDiscrepancy = (finalAmount - expectedAmount).abs() > 0.01 && expectedAmount > 0;
    final selectedDiscrepancyReason = ref.read(logRemittanceDiscrepancyReasonProvider);

    if (hasDiscrepancy && selectedDiscrepancyReason == null) {
      ref.read(logRemittanceDiscrepancyReasonProvider.notifier).state =
          isPartial ? 'Partial Remittance' : 'Variance Adjustment';
    }

    final riderCode = user?.deliveryAgentCode ?? user?.riderCode ?? user?.deliveryAgentId ?? 'RDR';
    final riderEmail = (user?.email != null && user!.email.isNotEmpty)
        ? user.email
        : 'rider.${riderCode.toLowerCase()}@novaexpress.ng';

    void onPaymentConfirmed(String confirmedRef) async {
      final reason = ref.read(logRemittanceDiscrepancyReasonProvider) ??
          (isPartial ? 'Partial Remittance' : null);

      final success = await ref.read(financeProvider.notifier).submitRemittance(
            amount: finalAmount,
            paymentMethod: 'paystack',
            agentId: user?.deliveryAgentId ?? user?.id,
            companyId: user?.companyId,
            grossCollections: grossCollections,
            commissionDeducted: commissionDeduction,
            transportAllowanceDeducted: transportDeduction,
            failedStipendsDeducted: failedStipendsDeduction,
            posFee: posFeeDeduction,
            referenceNumber: confirmedRef,
            discrepancyReason: reason,
            discrepancyAmount: (finalAmount - expectedAmount),
            expectedAmount: expectedAmount,
            isPartial: isPartial,
            associatedOrders: associatedOrders,
          );

      if (success && context.mounted) {
        _amountController.text = isPartial ? remainingAfterPayment.toInt().toString() : '0';
        ref.read(logRemittanceEnteredAmountProvider.notifier).state = isPartial ? remainingAfterPayment : 0.0;
        ref.read(logRemittanceInitialSetProvider.notifier).state = true;

        try {
          ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
        } catch (_) {}

        ref.read(notificationsProvider.notifier).emitNotification(
              title: isPartial ? 'Partial Remittance Verified ⚡' : 'Remittance Auto-Verified ⚡',
              message: isPartial
                  ? 'Your partial remittance of ${CurrencyFormatter.formatNaira(finalAmount)} was verified. Remaining balance: ${CurrencyFormatter.formatNaira(remainingAfterPayment)}.'
                  : 'Your cash remittance of ${CurrencyFormatter.formatNaira(finalAmount)} was instantly verified via Paystack and cleared from your custody.',
              category: 'finance',
              actionRoute: '/cash/history',
            );

        if (!context.mounted) return;
        _showSuccessCard(context, finalAmount, confirmedRef, remainingAfterPayment, isPartial);
      } else {
        if (!context.mounted) return;
        _onPaymentFailure(context, 'Could not record verified remittance to ledger. Please check network.');
      }
    }

    final cleanCode = riderCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final paymentRef = 'PSTK-RMT-${cleanCode.isNotEmpty ? cleanCode : 'RDR'}-$timestamp';

    if (!context.mounted) return;
    PaystackGatewayLauncher.openPayment(
      context: context,
      amount: finalAmount,
      email: riderEmail,
      reference: paymentRef,
      title: 'Paystack Remittance Portal',
      payerName: user != null ? '${user.firstName} ${user.lastName}'.trim() : 'Field Agent',
      payerCode: cleanCode.isNotEmpty ? cleanCode : 'RDR',
      agentId: user?.deliveryAgentId ?? user?.id,
      transactionType: 'remittance',
      onSuccess: onPaymentConfirmed,
    );
  }

  void _onPaymentFailure(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccessCard(
    BuildContext context,
    double amountPaid,
    String reference,
    double remainingBalance,
    bool isPartial,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              isPartial ? 'Partial Remittance Verified!' : 'Full Remittance Settled!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${CurrencyFormatter.formatNaira(amountPaid)} was auto-reconciled via Paystack and cleared from your cash custody.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00A2D3).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00A2D3).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reference:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(
                    reference,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3)),
                  ),
                ],
              ),
            ),
            if (isPartial) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF97316)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Remaining Balance Due:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFEA580C))),
                    Text(
                      CurrencyFormatter.formatNaira(remainingBalance),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFEA580C)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/remittance/receipt/$reference');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2D3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('View Official Receipt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: Text('Done & Return to Finance', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
