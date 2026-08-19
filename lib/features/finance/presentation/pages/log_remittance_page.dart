import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../providers/finance_provider.dart';

class LogRemittancePage extends ConsumerStatefulWidget {
  const LogRemittancePage({super.key});

  @override
  ConsumerState<LogRemittancePage> createState() => _LogRemittancePageState();
}

class _LogRemittancePageState extends ConsumerState<LogRemittancePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _posFeeController = TextEditingController(text: '100');
  final _posAgentNameController = TextEditingController();
  final _dcStaffNameController = TextEditingController(text: 'Supervisor Adekunle');
  final _notesController = TextEditingController();

  final double _grossCollections = 75000.0;
  final double _commissionDeduction = 15000.0;
  final double _transportDeduction = 22500.0;
  late double _expectedAmount;

  String _selectedMethod = 'bank_transfer'; // 'bank_transfer', 'cash_to_dc', 'pos'
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
  void initState() {
    super.initState();
    _expectedAmount = _grossCollections - _commissionDeduction - _transportDeduction;
    _amountController.text = _expectedAmount.toInt().toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _posFeeController.dispose();
    _posAgentNameController.dispose();
    _dcStaffNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final hasDiscrepancy = (enteredAmount - _expectedAmount).abs() > 0.01;
    final discrepancyAmount = enteredAmount - _expectedAmount;

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
              // 1. AUTO-CALCULATED SETTLEMENT FORMULA CARD (PRD Section 12 & 13)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTLEMENT BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gross Customer Collections', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFCBD5E1))),
                        Text(CurrencyFormatter.formatNaira(_grossCollections), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Less: Commission (15 deliveries)', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4ADE80))),
                        Text('-${CurrencyFormatter.formatNaira(_commissionDeduction)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF4ADE80))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Less: Transport Allowance', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF38BDF8))),
                        Text('-${CurrencyFormatter.formatNaira(_transportDeduction)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expected Remittance',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(_expectedAmount),
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. AMOUNT TO REMIT INPUT FIELD
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
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('₦', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                onChanged: (val) {
                  setState(() {});
                },
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter remittance amount';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 3. REALTIME DISCREPANCY FLOW (PRD Section 27 & 28)
              if (hasDiscrepancy) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF331500) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF97316)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            discrepancyAmount < 0 ? 'Remittance Shortage Detected' : 'Excess Remittance Detected',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Difference: ${CurrencyFormatter.formatNaira(discrepancyAmount.abs())} (${discrepancyAmount < 0 ? "Under-remitting" : "Over-remitting"})',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Why is there a difference? (Required)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDiscrepancyReason,
                        hint: Text('Select discrepancy reason', style: GoogleFonts.inter(fontSize: 12)),
                        items: _discrepancyReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedDiscrepancyReason = val),
                        validator: (val) {
                          if (hasDiscrepancy && (val == null || val.isEmpty)) {
                            return 'Please select reason for difference';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 4. PAYMENT METHOD SELECTOR (PRD Section 17-21)
              Text(
                'HOW ARE YOU REMITTING?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodTile(
                      id: 'bank_transfer',
                      icon: Icons.account_balance_rounded,
                      title: 'Bank Transfer',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMethodTile(
                      id: 'cash_to_dc',
                      icon: Icons.storefront_rounded,
                      title: 'Cash to DC',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMethodTile(
                      id: 'pos',
                      icon: Icons.point_of_sale_rounded,
                      title: 'POS Transfer',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 5. METHOD-SPECIFIC INPUT FORMS
              if (_selectedMethod == 'bank_transfer') ...[
                // Bank Account Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NovaExpress GTBank Account', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: '0129849201'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account number copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                      Text('Account No: 0129849201 • GTBank PLC', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      Text('Beneficiary: NovaExpress Logistics Ltd', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Bank Transaction Reference / Session ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    hintText: 'e.g. TRX-829102 or NIP Session ID',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter transaction reference' : null,
                ),
              ] else if (_selectedMethod == 'cash_to_dc') ...[
                Text('Distribution Center Hub', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFEA580C)),
                      const SizedBox(width: 8),
                      Text('Wuse Distribution Center Reception', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('DC Supervisor / Staff Name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dcStaffNameController,
                  decoration: InputDecoration(
                    hintText: 'Name of staff receiving cash',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter receiving staff name' : null,
                ),
              ] else if (_selectedMethod == 'pos') ...[
                // POS Fee Box (Tracked separately per PRD Section 19 & 20)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'POS charge is recorded separately (Pending Approval) and not automatically deducted from required remittance.',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('POS Fee (₦)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _posFeeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('POS Reference', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _referenceController,
                            decoration: InputDecoration(
                              hintText: 'POS-839201',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Enter POS reference' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Proof of Payment Upload Button / Simulation
              InkWell(
                onTap: () {
                  setState(() => _hasProofUploaded = !_hasProofUploaded);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasProofUploaded ? 'Deposit Receipt / Proof Attached' : 'Attach Proof of Payment (Optional)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _hasProofUploaded ? const Color(0xFF10B981) : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _hasProofUploaded ? 'receipt_proof_remittance_829.jpg' : 'Tap to capture photo or select from gallery',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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

              // Submit Remittance Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: financeState.isLoading ? null : () => _handleReviewAndSubmit(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: financeState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Review & Submit Remittance',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    final isSelected = _selectedMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReviewAndSubmit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final posFee = double.tryParse(_posFeeController.text) ?? 0.0;
    final refText = _referenceController.text.isNotEmpty
        ? _referenceController.text
        : (_selectedMethod == 'cash_to_dc' ? 'CASH-${_dcStaffNameController.text}' : 'REM-00482');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Confirm Remittance Submission', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please verify remittance settlement details before final submission:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            _buildConfirmRow('Gross Collections:', CurrencyFormatter.formatNaira(_grossCollections)),
            _buildConfirmRow('Less Commission:', '-${CurrencyFormatter.formatNaira(_commissionDeduction)}'),
            _buildConfirmRow('Less Transport:', '-${CurrencyFormatter.formatNaira(_transportDeduction)}'),
            const Divider(height: 16),
            _buildConfirmRow('Net Amount Remitted:', CurrencyFormatter.formatNaira(enteredAmount), isBold: true),
            _buildConfirmRow('Method:', _selectedMethod.toUpperCase()),
            _buildConfirmRow('Reference:', refText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Edit Details'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref.read(financeProvider.notifier).submitRemittance(
                    amount: enteredAmount,
                    paymentMethod: _selectedMethod,
                    grossCollections: _grossCollections,
                    commissionDeducted: _commissionDeduction,
                    transportAllowanceDeducted: _transportDeduction,
                    posFee: posFee,
                    referenceNumber: refText,
                    discrepancyReason: _selectedDiscrepancyReason,
                    discrepancyAmount: (enteredAmount - _expectedAmount),
                    notes: _notesController.text,
                  );

              if (success && context.mounted) {
                ref.read(notificationsProvider.notifier).emitNotification(
                      title: 'Remittance Logged 💸',
                      message: 'Your cash remittance of ${CurrencyFormatter.formatNaira(enteredAmount)} (Ref: $refText) was logged and sent for DC verification.',
                      category: 'finance',
                      actionRoute: '/cash/history',
                    );
                _showSuccessDialog(context, enteredAmount, refText);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm & Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
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
              'Remittance Submitted',
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
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PENDING VERIFICATION',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: $reference\nSubmitted: 18 Aug 2026 • 6:04 PM',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
