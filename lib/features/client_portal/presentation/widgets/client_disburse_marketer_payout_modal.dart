import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../domain/entities/client_marketer.dart';
import '../providers/client_portal_provider.dart';

class ClientDisburseMarketerPayoutModal extends ConsumerStatefulWidget {
  final ClientMarketer marketer;

  const ClientDisburseMarketerPayoutModal({
    super.key,
    required this.marketer,
  });

  static Future<void> show(BuildContext context, {required ClientMarketer marketer}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ClientDisburseMarketerPayoutModal(marketer: marketer),
    );
  }

  @override
  ConsumerState<ClientDisburseMarketerPayoutModal> createState() => _ClientDisburseMarketerPayoutModalState();
}

class _ClientDisburseMarketerPayoutModalState extends ConsumerState<ClientDisburseMarketerPayoutModal> {
  late final TextEditingController _amountController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _refController;
  late final TextEditingController _notesController;

  Uint8List? _pickedReceiptBytes;
  String? _pickedReceiptName;
  String? _pickedReceiptExt;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final marketer = widget.marketer;
    final initialAmount = marketer.unpaidCommissionBalance > 0
        ? marketer.unpaidCommissionBalance
        : (marketer.effectiveCommissionPerDelivery > 0
            ? marketer.effectiveCommissionPerDelivery * 5
            : (marketer.effectiveCommissionPerSubmission > 0
                ? marketer.effectiveCommissionPerSubmission * 10
                : 10000.0));

    _amountController = TextEditingController(text: initialAmount.toStringAsFixed(0));
    _bankNameController = TextEditingController(text: marketer.bankName.isNotEmpty ? marketer.bankName : 'Zenith Bank');
    _accountNumberController = TextEditingController(text: marketer.accountNumber);
    _accountNameController = TextEditingController(text: marketer.accountName.isNotEmpty ? marketer.accountName : marketer.fullName);
    _refController = TextEditingController(
      text: 'TRF-MKT-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecond.toString().padLeft(3, '0')}',
    );
    _notesController = TextEditingController(text: 'Commission payout for digital marketing ad campaigns.');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (result.isNotEmpty) {
        final pickedFile = result.first;
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _pickedReceiptBytes = bytes;
            _pickedReceiptName = pickedFile.name;
            _pickedReceiptExt = pickedFile.extension?.toLowerCase() ?? 'pdf';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Could not attach file: $e'),
          ),
        );
      }
    }
  }

  Future<void> _submitDisbursement() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please enter a valid disbursement amount greater than ₦0.'),
        ),
      );
      return;
    }

    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountName = _accountNameController.text.trim();

    if (bankName.isEmpty || accountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please supply Bank Name and Account Number.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? proofUrl;
      if (_pickedReceiptBytes != null) {
        try {
          proofUrl = await SignatureStorageService.uploadPayoutReceipt(
            bytes: _pickedReceiptBytes!,
            payoutCode: 'MKT-${widget.marketer.marketerCode}-${DateTime.now().millisecondsSinceEpoch}',
            extension: _pickedReceiptExt ?? 'pdf',
          );
        } catch (uploadErr) {
          debugPrint('[MARKETER_PAYOUT] ⚠️ Cloud storage upload warning: $uploadErr');
        }
      }

      await ref.read(clientPortalProvider.notifier).disburseMarketerPayout(
        marketerId: widget.marketer.id,
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName.isNotEmpty ? accountName : widget.marketer.fullName,
        disbursementRef: _refController.text.trim(),
        proofOfPaymentUrl: proofUrl,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Disbursement of ₦${NumberFormat('#,##0').format(amount)} to ${widget.marketer.fullName} remitted successfully!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Disbursement failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final unpaid = widget.marketer.unpaidCommissionBalance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disburse Marketer Payout',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.marketer.fullName} • ${widget.marketer.marketerCode}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unpaid Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accrued Unpaid Commission',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
                        ),
                        Text(
                          currencyFormatter.format(unpaid),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _amountController.text = unpaid.toStringAsFixed(0),
                      child: Text('Pay Full Balance', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Amount Field
              Text(
                'Disbursement Amount (₦) *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                  hintText: 'e.g. 50000',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 16),

              // Bank Fields
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bank Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _bankNameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.account_balance_outlined, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Number *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: InputDecoration(
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text('Account Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Reference
              Text('Transfer Reference / Session ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _refController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Attach Receipt
              Text('Payment Receipt / Proof of Transfer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickReceiptFile,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickedReceiptBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                        color: _pickedReceiptBytes != null ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedReceiptName ?? 'Click to attach payment slip (PDF/PNG/JPG)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _pickedReceiptBytes != null ? FontWeight.w700 : FontWeight.w500,
                            color: _pickedReceiptBytes != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_pickedReceiptBytes != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          onPressed: () => setState(() {
                            _pickedReceiptBytes = null;
                            _pickedReceiptName = null;
                            _pickedReceiptExt = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : _submitDisbursement,
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            children: [
                              const Icon(Icons.send_rounded, size: 16),
                              const SizedBox(width: 8),
                              Text('Confirm & Disburse', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
