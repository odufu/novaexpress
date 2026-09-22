import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../domain/entities/client_closer.dart';
import '../providers/client_portal_provider.dart';

class ClientDisburseCloserPayoutModal extends ConsumerStatefulWidget {
  final ClientCloser closer;

  const ClientDisburseCloserPayoutModal({
    super.key,
    required this.closer,
  });

  static Future<void> show(BuildContext context, {required ClientCloser closer}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ClientDisburseCloserPayoutModal(closer: closer),
    );
  }

  @override
  ConsumerState<ClientDisburseCloserPayoutModal> createState() => _ClientDisburseCloserPayoutModalState();
}

class _ClientDisburseCloserPayoutModalState extends ConsumerState<ClientDisburseCloserPayoutModal> {
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
    final closer = widget.closer;
    final initialAmount = closer.unpaidCommissionBalance > 0
        ? closer.unpaidCommissionBalance
        : (closer.commissionRate > 0 ? closer.commissionRate * 10 : 5000.0);

    _amountController = TextEditingController(text: initialAmount.toStringAsFixed(0));
    _bankNameController = TextEditingController(text: closer.bankName.isNotEmpty ? closer.bankName : 'Zenith Bank');
    _accountNumberController = TextEditingController(text: closer.accountNumber);
    _accountNameController = TextEditingController(text: closer.accountName.isNotEmpty ? closer.accountName : closer.fullName);
    _refController = TextEditingController(
      text: 'TRF-CLS-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecond.toString().padLeft(3, '0')}',
    );
    _notesController = TextEditingController(text: 'Commission payout for delivered telesales orders.');
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

  Future<void> _handleDisburse() async {
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
    final refCode = _refController.text.trim();
    final notes = _notesController.text.trim();

    if (accountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please enter closer account number.'),
        ),
      );
      return;
    }

    if (refCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please provide the bank transfer reference or transaction ID.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? receiptUrl;
      if (_pickedReceiptBytes != null) {
        receiptUrl = await SignatureStorageService.uploadPayoutReceipt(
          bytes: _pickedReceiptBytes!,
          payoutCode: 'CLS-${widget.closer.closerCode}-${DateTime.now().millisecondsSinceEpoch}',
          extension: _pickedReceiptExt ?? 'pdf',
        );
      }

      await ref.read(clientPortalProvider.notifier).disburseCloserPayout(
        closerId: widget.closer.id,
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
        disbursementRef: refCode,
        proofOfPaymentUrl: receiptUrl,
        notes: notes,
      );

      // If bank info changed, persist it to closer profile
      if (bankName != widget.closer.bankName ||
          accountNumber != widget.closer.accountNumber ||
          accountName != widget.closer.accountName) {
        await ref.read(clientPortalProvider.notifier).updateCloserDetails(
          closerId: widget.closer.id,
          bankName: bankName,
          accountNumber: accountNumber,
          accountName: accountName,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✅ Disbursed ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount)} to ${widget.closer.fullName}! Proof document attached.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disburse Closer Commission',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  '${widget.closer.fullName} • ${widget.closer.closerCode}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance summary card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unpaid Commission Balance', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormatter.format(widget.closer.unpaidCommissionBalance),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Paid to Date', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormatter.format(widget.closer.totalPaidCommission),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bank account card with 1-tap copy
              Text('TRANSFER DESTINATION (CLOSER BANK)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bankNameController,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Bank Name',
                              isDense: true,
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _accountNumberController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Account Number',
                              isDense: true,
                              border: const UnderlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFF37021)),
                                tooltip: 'Copy Account Number',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _accountNumberController.text.trim()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF10B981),
                                      content: Text('Account number copied to clipboard!'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNameController,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Payout Amount & Transfer Reference
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Disburse Amount (₦)',
                        isDense: true,
                        prefixText: '₦ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _refController,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Bank Transfer Ref / Session ID',
                        hintText: 'e.g. OPAY-109238',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Payment Memo / DC Notes',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Proof of payment file dropzone
              Text('TRANSFER RECEIPT / PROOF DOCUMENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5)),
              const SizedBox(height: 6),
              if (_pickedReceiptBytes == null)
                InkWell(
                  onTap: _pickReceiptFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: Color(0xFF10B981), size: 28),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to attach Bank Transfer Receipt',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                        Text(
                          'Upload screenshot, PNG, JPG, or PDF statement proof',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _pickedReceiptExt == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          color: const Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedReceiptName ?? 'Payment_Receipt',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(_pickedReceiptBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB • Attached Ready',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Remove Attachment',
                        onPressed: () {
                          setState(() {
                            _pickedReceiptBytes = null;
                            _pickedReceiptName = null;
                            _pickedReceiptExt = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleDisburse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isSubmitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(
            _isSubmitting ? 'Processing...' : 'Disburse & Save Receipt',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
