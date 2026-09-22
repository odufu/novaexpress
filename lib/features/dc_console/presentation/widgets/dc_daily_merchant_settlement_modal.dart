import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
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
  final TextEditingController _referenceController = TextEditingController();

  Uint8List? _receiptBytes;
  String? _receiptFileName;

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
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _receiptBytes = bytes;
            _receiptFileName = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('[SETTLEMENT_MODAL] Error picking receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking receipt file: $e')),
        );
      }
    }
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
    final platformFeeType = widget.client.customPlatformFeeType ?? dcSettings.platformFeeType;
    final platformFeeValue = widget.client.customPlatformFeeValue ?? dcSettings.platformFeeValue;
    double totalPlatformFees = 0.0;
    if (platformFeeType == 'percent') {
      totalPlatformFees = grossCollections * (platformFeeValue / 100.0);
    } else {
      totalPlatformFees = activeOrders.length * platformFeeValue;
    }

    // Gateway fees calculation
    final paystackFeeAbsorbedBy = widget.client.customPaystackFeeAbsorbedBy ?? dcSettings.paystackFeeAbsorbedBy;
    double totalGatewayFees = 0.0;
    if (paystackFeeAbsorbedBy == 'merchant' || paystackFeeAbsorbedBy == 'shared') {
      final directOrders = activeOrders.where((o) => o.isDirectTransfer);
      for (final d in directOrders) {
        final calculatedFee = d.totalAmount * (dcSettings.paystackDirectFeePercent / 100.0);
        final cappedFee = calculatedFee > dcSettings.paystackFeeCap ? dcSettings.paystackFeeCap : calculatedFee;
        totalGatewayFees += paystackFeeAbsorbedBy == 'shared' ? (cappedFee / 2.0) : cappedFee;
      }
    }

    final double otherCharges = double.tryParse(_otherChargesController.text) ?? 0.0;
    final double totalDeductions = totalDeliveryFees + totalPlatformFees + totalGatewayFees + otherCharges;
    final double netPayout = grossCollections - totalDeductions;

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: screenHeight * 0.92,
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 740;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Manual Client Settlement Remittance',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Manual Bank Transfer',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF37021),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${widget.client.companyName} • ${widget.client.bankName.isNotEmpty ? widget.client.bankName : "No Bank Assigned"} • ${widget.client.accountNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  child: isMobile
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOrdersChecklistSection(isDark, currency, activeOrders),
                              const SizedBox(height: 16),
                              _buildSettlementCard(
                                isDark: isDark,
                                currency: currency,
                                grossCollections: grossCollections,
                                totalDeliveryFees: totalDeliveryFees,
                                totalPlatformFees: totalPlatformFees,
                                totalGatewayFees: totalGatewayFees,
                                otherCharges: otherCharges,
                                netPayout: netPayout,
                                activeOrders: activeOrders,
                                activeDcId: activeDcId,
                              ),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Order Checklist
                            Expanded(
                              flex: 3,
                              child: _buildOrdersChecklistSection(isDark, currency, activeOrders),
                            ),
                            const SizedBox(width: 24),
                            // Right: Itemized Charges Breakdown & Bank Details & Receipt Attachment
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(
                                child: _buildSettlementCard(
                                  isDark: isDark,
                                  currency: currency,
                                  grossCollections: grossCollections,
                                  totalDeliveryFees: totalDeliveryFees,
                                  totalPlatformFees: totalPlatformFees,
                                  totalGatewayFees: totalGatewayFees,
                                  otherCharges: otherCharges,
                                  netPayout: netPayout,
                                  activeOrders: activeOrders,
                                  activeDcId: activeDcId,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersChecklistSection(bool isDark, NumberFormat currency, List<OrderEntity> activeOrders) {
    return Column(
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
              child: Text(
                _selectedOrderIds.length == widget.eligibleOrders.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: widget.eligibleOrders.isEmpty
              ? Center(child: Text('No eligible delivered orders found', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.eligibleOrders.length,
                  itemBuilder: (context, idx) {
                    final o = widget.eligibleOrders[idx];
                    final isSelected = _selectedOrderIds.contains(o.id);
                    return CheckboxListTile(
                      dense: true,
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
                      title: Text(
                        '${o.orderNumber} - ${o.customerName}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${o.paymentType.toUpperCase()} | Delivered: ${o.deliveredAt?.toLocal().toString().split('.')[0] ?? "Today"}',
                        style: GoogleFonts.inter(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: Text(
                        currency.format(o.totalAmount),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0D9488)),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),

        // Auxiliary deductions & notes
        Text(
          'Settlement Adjustments & Memo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _otherChargesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Auxiliary Deductions (₦)',
                  labelStyle: GoogleFonts.inter(fontSize: 12),
                  hintText: '0.00',
                  prefixText: '₦ ',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Internal Memo / Settlement Notes (Optional)',
            labelStyle: GoogleFonts.inter(fontSize: 12),
            hintText: 'e.g. Cleared via Access Bank transfer',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSettlementCard({
    required bool isDark,
    required NumberFormat currency,
    required double grossCollections,
    required double totalDeliveryFees,
    required double totalPlatformFees,
    required double totalGatewayFees,
    required double otherCharges,
    required double netPayout,
    required List<OrderEntity> activeOrders,
    required String activeDcId,
  }) {
    final effectiveNet = netPayout > 0 ? netPayout : 0.0;

    return Container(
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
          const Divider(height: 14),
          _buildCalculationRow('Logistics Delivery Fees', '- ${currency.format(totalDeliveryFees)}', isNegative: true),
          _buildCalculationRow('Platform Commission Fees', '- ${currency.format(totalPlatformFees)}', isNegative: true),
          _buildCalculationRow('Paystack Gateway Fees', '- ${currency.format(totalGatewayFees)}', isNegative: true),
          if (otherCharges > 0)
            _buildCalculationRow('Auxiliary Charges', '- ${currency.format(otherCharges)}', isNegative: true),
          const Divider(height: 16),
          _buildCalculationRow('Net Liquid Payout', currency.format(effectiveNet), isBold: true, isHighlight: true),
          const SizedBox(height: 16),

          // Merchant Bank Details Card with 1-tap Copy
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      'MERCHANT PAYOUT BANK ACCOUNT',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.client.bankName.isNotEmpty ? widget.client.bankName : 'Bank Not Provided',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            widget.client.accountNumber.isNotEmpty ? widget.client.accountNumber : 'No Account Number',
                            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0D9488)),
                          ),
                          Text(
                            widget.client.accountName.isNotEmpty ? widget.client.accountName : widget.client.companyName,
                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (widget.client.accountNumber.isNotEmpty)
                      IconButton.filledTonal(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: 'Copy Account Number',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.client.accountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Account number ${widget.client.accountNumber} copied!'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '⚡ Central DC physically sends ₦${currency.format(effectiveNet).replaceAll('₦', '')} to this account and attaches the receipt below.',
                  style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payout Reference input
          TextFormField(
            controller: _referenceController,
            decoration: InputDecoration(
              labelText: 'Transfer Reference / Session ID',
              labelStyle: GoogleFonts.inter(fontSize: 12),
              hintText: 'e.g. TRF/ACCESS/20260920/123456',
              prefixIcon: const Icon(Icons.tag_rounded, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),

          // Receipt Attachment Card
          Text(
            'Proof of Transfer Receipt',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (_receiptBytes == null) ...[
            InkWell(
              onTap: _pickReceiptFile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0D9488), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Attach Transfer Receipt (PDF or Image)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0D9488)),
              ),
              child: Row(
                children: [
                  Icon(
                    _receiptFileName?.endsWith('.pdf') == true ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: const Color(0xFF0D9488),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _receiptFileName ?? 'receipt_file',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${((_receiptBytes?.lengthInBytes ?? 0) / 1024).toStringAsFixed(1)} KB • Attached for Merchant',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                    tooltip: 'Remove Receipt',
                    onPressed: () {
                      setState(() {
                        _receiptBytes = null;
                        _receiptFileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Execution Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: activeOrders.isEmpty
                  ? null
                  : () async {
                      try {
                        await showAppLoadingDialog(
                          context: context,
                          message: 'Remitting Settlement...',
                          subMessage: 'Uploading transfer receipt & locking ${activeOrders.length} orders...',
                          isDark: isDark,
                          task: () async {
                            final now = DateTime.now();
                            final selectedIds = activeOrders.map((o) => o.id).toList();

                            // 1. Upload receipt file if attached
                            String? receiptUrl;
                            if (_receiptBytes != null) {
                              final ext = _receiptFileName?.split('.').last ?? 'pdf';
                              receiptUrl = await SignatureStorageService.uploadSettlementReceipt(
                                bytes: _receiptBytes!,
                                settlementNumber: widget.client.companyName,
                                extension: ext,
                              );
                            }

                            // 2. Execute manual settlement batch
                            final result = await ref.read(dcConsoleProvider.notifier).executeDailyMerchantSettlement(
                              clientId: widget.client.id,
                              dcId: activeDcId,
                              periodStart: now.subtract(const Duration(days: 60)),
                              periodEnd: now,
                              customDeductions: {
                                'other_charges': otherCharges,
                                'notes': _notesController.text.isNotEmpty
                                    ? _notesController.text
                                    : 'Manual Bank Transfer Settlement Fulfilled by Central DC',
                              },
                              orderIds: selectedIds,
                              proofOfPaymentUrl: receiptUrl,
                              payoutReference: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
                              notes: _notesController.text.trim().isNotEmpty
                                  ? _notesController.text.trim()
                                  : 'Manual Bank Transfer Settlement Fulfilled by Central DC',
                              grossCollections: grossCollections,
                              logisticsFeesDeducted: totalDeliveryFees,
                              platformFeesDeducted: totalPlatformFees,
                              gatewayFeesDeducted: totalGatewayFees,
                              failedAttemptFeesDeducted: 0.0,
                              otherChargesDeducted: otherCharges,
                              netPayoutAmount: effectiveNet,
                              destinationBankName: widget.client.bankName,
                              destinationAccountNumber: widget.client.accountNumber,
                              destinationAccountName: widget.client.accountName.isNotEmpty ? widget.client.accountName : widget.client.companyName,
                            );

                            // 3. Refresh live orders list
                            await ref.read(ordersProvider.notifier).fetchOrders();
                            return result;
                          },
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Settlement remitted successfully! Merchant has been notified with the transfer receipt.'),
                              backgroundColor: Color(0xFF0D9488),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (err) {
                        debugPrint('[SETTLEMENT_MODAL] Finalize error: $err');
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Settlement Failed'),
                                ],
                              ),
                              content: Text('Could not finalize settlement batch:\n\n$err'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: Text(
                'Remit Payout & Notify Merchant',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
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
