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
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/providers/navigation_provider.dart';
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
  final _referenceController = TextEditingController();
  String _selectedPaymentMethod = 'bank_transfer';
  String? _receiptFileName;
  String? _receiptUrl;
  bool _isUploadingReceipt = false;

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
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );
      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _receiptFileName = file.name;
            _isUploadingReceipt = true;
          });

          final ext = file.extension?.toLowerCase() ?? 'jpg';
          final user = ref.read(authProvider).user;
          final agentId = user?.deliveryAgentId ?? user?.id ?? 'rider';
          final cleanAgent = agentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          final remTag = 'rmt_${cleanAgent}_${DateTime.now().millisecondsSinceEpoch}';

          final url = await SignatureStorageService.uploadRemittanceReceipt(
            imageBytes: bytes,
            remittanceId: remTag,
            ext: ext,
          );

          if (mounted) {
            setState(() {
              _receiptUrl = url;
              _isUploadingReceipt = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt proof uploaded successfully!'),
                backgroundColor: Color(0xFF16A34A),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingReceipt = false);
        _onPaymentFailure('Error selecting receipt: $e');
      }
    }
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
    final unremittedDeliveredOrders = deliveredOrders
        .where((o) => !o.isRemitted && o.paymentStatus.toLowerCase() != 'remitted')
        .toList();
    final unremittedCashOrders = unremittedDeliveredOrders.where((o) => o.isCashPod).toList();
    final failedOrders = ordersState.orders.where((o) => o.status == 'failed' || o.status == 'failed_attempt').toList();

    final double batchGrossCash = unremittedCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double batchCommission = unremittedCashOrders.fold(
      0.0,
      (acc, o) => acc + ((user?.commissionRate != null && user!.commissionRate > 0)
          ? user.commissionRate
          : (o.agentEntitlement > 0 && o.agentEntitlement != 2500.0 ? o.agentEntitlement : commissionRate)),
    );
    final double batchTransport = unremittedCashOrders.fold(
      0.0,
      (acc, o) => acc + ((user?.transportAllowance != null && user!.transportAllowance > 0)
          ? user.transportAllowance
          : (o.transportFee > 0 && o.transportFee != 1500.0 ? o.transportFee : transportPerOrder)),
    );
    final double failedStipendsDeduction = failedOrders.length * failedStipendRate;
    final double posFeeDeduction = (batchGrossCash > 0 && dcFinanceSettings.isPosFeeReimbursable)
        ? dcFinanceSettings.computePosFee(batchGrossCash)
        : 0.0;

    final double grossCollections = batchGrossCash;
    final double commissionDeduction = batchCommission;
    final double transportDeduction = batchTransport;
    final double transferFeeDeduction = posFeeDeduction;
    final double expectedAmount = (grossCollections - commissionDeduction - transportDeduction - failedStipendsDeduction - transferFeeDeduction).clamp(0.0, double.infinity);
    final int deliveredCount = unremittedDeliveredOrders.length;
    final int failedCount = failedOrders.length;

    // Snapshot of orders contributing to this remittance with itemized breakdown (collections - commission - transport - POS fee)
    final List<RemittanceOrderItem> associatedOrderItems = [
      ...unremittedDeliveredOrders.map((o) {
        final cash = o.isCashPod ? o.totalAmount : 0.0;
        final comm = (user?.commissionRate != null && user!.commissionRate > 0)
            ? user.commissionRate
            : (o.agentEntitlement > 0 && o.agentEntitlement != 2500.0 ? o.agentEntitlement : commissionRate);
        final trans = (user?.transportAllowance != null && user!.transportAllowance > 0)
            ? user.transportAllowance
            : (o.transportFee > 0 && o.transportFee != 1500.0 ? o.transportFee : transportPerOrder);
        final orderPosFee = (batchGrossCash > 0 && cash > 0)
            ? (cash / batchGrossCash) * posFeeDeduction
            : 0.0;
        return RemittanceOrderItem(
          orderId: o.id,
          orderNumber: o.orderNumber,
          customerName: o.customerName,
          status: o.status,
          paymentType: o.paymentType,
          cashCollected: cash,
          riderCommission: comm,
          transportAllowance: trans,
          failedStipend: 0.0,
          posFee: orderPosFee,
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
          onPressed: () {
            ref.read(bottomNavIndexProvider.notifier).state = 3;
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
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
              'Manual Submission & DC Approval 📋',
              style: GoogleFonts.inter(
                color: const Color(0xFF00522A),
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

              // 4. PAYMENT METHOD SELECTOR
              Text(
                'Remittance Method',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = 'bank_transfer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 'bank_transfer'
                              ? const Color(0xFF00522A)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPaymentMethod == 'bank_transfer'
                                ? const Color(0xFF00522A)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '🏦 Bank Transfer',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedPaymentMethod == 'bank_transfer' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = 'cash_to_dc'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 'cash_to_dc'
                              ? const Color(0xFF00522A)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPaymentMethod == 'cash_to_dc'
                                ? const Color(0xFF00522A)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '💵 Cash Handover',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedPaymentMethod == 'cash_to_dc' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = 'pos_deposit'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 'pos_deposit'
                              ? const Color(0xFF00522A)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPaymentMethod == 'pos_deposit'
                                ? const Color(0xFF00522A)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '💳 POS Machine',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedPaymentMethod == 'pos_deposit' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. STATION / COMPANY BANK DETAILS (Visible for Bank Transfer)
              if (_selectedPaymentMethod == 'bank_transfer') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_rounded, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'OFFICIAL REMITTANCE ACCOUNT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF16A34A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: '1023456789'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account number copied to clipboard!'), duration: Duration(seconds: 2)),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy NUBAN',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bank Name:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          Text('First Bank of Nigeria', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Account Number:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          Text('1023456789', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF00522A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Account Name:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          Text('NovaXpress Logistics Ltd', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6. BANK RECEIPT PHOTO / DOCUMENT UPLOAD SECTION
              Text(
                'Deposit / Transfer Receipt Proof',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploadingReceipt ? null : _pickReceipt,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _receiptUrl != null
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: _receiptUrl != null ? 1.5 : 1,
                    ),
                  ),
                  child: _isUploadingReceipt
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Uploading receipt to secure storage...'),
                              ],
                            ),
                          ),
                        )
                      : (_receiptUrl != null
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _receiptFileName ?? 'Remittance Receipt Attached',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Verified & ready for DC Finance audit ✓',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A)),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _pickReceipt,
                                  child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF64748B)),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to Upload Deposit Slip or Transfer Screenshot',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supports PNG, JPG, or PDF receipt confirmations',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            )),
                ),
              ),
              const SizedBox(height: 16),

              // 7. TRANSACTION REFERENCE OR DEPOSITOR NAME
              Text(
                'Payment Reference / Bank Narration (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  hintText: 'e.g., TRF-GTB-829103 or Cashier Slip #',
                  hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // 8. SUBMIT REMITTANCE ACTION BUTTON
              (() {
                final isButtonDisabled = financeState.isLoading || _isUploadingReceipt;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isButtonDisabled
                        ? null
                        : () => _handleSubmitRemittance(
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
                      backgroundColor: const Color(0xFF00522A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: isButtonDisabled
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                    label: financeState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Submit Remittance (${CurrencyFormatter.formatNaira(enteredAmount > 0 ? enteredAmount : expectedAmount)})',
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                  ),
                );
              }()),              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmitRemittance(
    double enteredAmount,
    dynamic user,
    double grossCollections,
    double commissionDeduction,
    double transportDeduction,
    double failedStipendsDeduction,
    double posFeeDeduction,
    double expectedAmount,
    List<RemittanceOrderItem> associatedOrders,
  ) async {
    final rawText = _amountController.text.replaceAll(',', '').replaceAll('₦', '').trim();
    final parsed = double.tryParse(rawText);
    final finalAmount = (parsed != null && parsed > 0)
        ? parsed
        : (enteredAmount > 0 ? enteredAmount : expectedAmount);

    if (finalAmount <= 0) {
      _onPaymentFailure('Please enter a valid amount to remit.');
      return;
    }

    final isPartial = finalAmount < (expectedAmount - 1.0);
    final remainingAfterPayment = (expectedAmount - finalAmount).clamp(0.0, double.infinity);
    final hasDiscrepancy = (finalAmount - expectedAmount).abs() > 1.0 && expectedAmount > 0;
    final selectedDiscrepancyReason = ref.read(logRemittanceDiscrepancyReasonProvider);

    if (hasDiscrepancy && selectedDiscrepancyReason == null) {
      ref.read(logRemittanceDiscrepancyReasonProvider.notifier).state =
          isPartial ? 'Partial Remittance' : 'Variance Adjustment';
    }

    final riderCode = user?.deliveryAgentCode ?? user?.riderCode ?? user?.deliveryAgentId ?? 'RDR';
    final cleanCode = riderCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final customRef = _referenceController.text.trim();
    final paymentRef = customRef.isNotEmpty ? customRef : 'REM-${cleanCode.isNotEmpty ? cleanCode : "RDR"}-$timestamp';

    final reason = ref.read(logRemittanceDiscrepancyReasonProvider) ??
        (isPartial ? 'Partial Remittance' : null);

    final success = await ref.read(financeProvider.notifier).submitRemittance(
          amount: finalAmount,
          paymentMethod: _selectedPaymentMethod,
          agentId: user?.deliveryAgentId ?? user?.id,
          companyId: user?.companyId,
          grossCollections: grossCollections,
          commissionDeducted: commissionDeduction,
          transportAllowanceDeducted: transportDeduction,
          failedStipendsDeducted: failedStipendsDeduction,
          posFee: posFeeDeduction,
          depositReceiptUrl: _receiptUrl,
          referenceNumber: paymentRef,
          discrepancyReason: reason,
          discrepancyAmount: (finalAmount - expectedAmount),
          expectedAmount: expectedAmount,
          isPartial: isPartial,
          associatedOrders: associatedOrders,
        );

    if (!mounted) return;

    if (success) {
      _amountController.text = isPartial ? remainingAfterPayment.toInt().toString() : '0';
      _referenceController.clear();
      setState(() {
        _receiptFileName = null;
        _receiptUrl = null;
      });
      ref.read(logRemittanceEnteredAmountProvider.notifier).state = isPartial ? remainingAfterPayment : 0.0;
      ref.read(logRemittanceInitialSetProvider.notifier).state = true;

      try {
        ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
      } catch (_) {}

      ref.read(notificationsProvider.notifier).emitNotification(
            title: isPartial ? 'Partial Remittance Submitted 📋' : 'Remittance Submitted for DC Approval 📋',
            message: isPartial
                ? 'Your partial remittance of ${CurrencyFormatter.formatNaira(finalAmount)} was submitted. DC Finance Admin will verify your receipt and credit alert.'
                : 'Your cash remittance of ${CurrencyFormatter.formatNaira(finalAmount)} was submitted. Awaiting DC Finance Admin verification.',
            category: 'finance',
            actionRoute: '/cash/history',
          );

      if (!mounted) return;
      _showSuccessCard(finalAmount, paymentRef, remainingAfterPayment, isPartial);
    } else {
      if (!mounted) return;
      _onPaymentFailure('Could not submit remittance to ledger. Please check network.');
    }
  }

  void _onPaymentFailure(String message) {
    if (!mounted) return;
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
    double amountPaid,
    String reference,
    double remainingBalance,
    bool isPartial,
  ) {
    if (!mounted) return;
    bool navigatedToReceipt = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
              isPartial ? 'Partial Remittance Submitted!' : 'Remittance Submitted for DC Approval!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${CurrencyFormatter.formatNaira(amountPaid)} has been submitted. The DC Finance Admin will verify your receipt and credit alert before clearing custody.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00522A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reference:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(
                    reference,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00522A)),
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
                  navigatedToReceipt = true;
                  Navigator.of(ctx, rootNavigator: true).pop();
                  if (mounted) {
                    ref.read(bottomNavIndexProvider.notifier).state = 3;
                    context.pushReplacement('/remittance/receipt/$reference');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('View Official Receipt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  if (mounted) {
                    ref.read(bottomNavIndexProvider.notifier).state = 3;
                    final user = ref.read(authProvider).user;
                    final agentId = user?.deliveryAgentId ?? user?.id;
                    if (agentId != null) {
                      ref.read(financeProvider.notifier).loadRemittances(agentId);
                      ref.read(ordersProvider.notifier).loadOrders(agentId);
                    }
                    context.go('/');
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00A2D3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done & Return to Remittance Tab', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF00522A))),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (!navigatedToReceipt && mounted) {
        ref.read(bottomNavIndexProvider.notifier).state = 3;
        final user = ref.read(authProvider).user;
        final agentId = user?.deliveryAgentId ?? user?.id;
        if (agentId != null) {
          ref.read(financeProvider.notifier).loadRemittances(agentId);
          ref.read(ordersProvider.notifier).loadOrders(agentId);
        }
        context.go('/');
      }
    });
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
