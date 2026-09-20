import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../providers/client_portal_provider.dart';

class ClientStockInvoiceDetailModal extends ConsumerStatefulWidget {
  final ClientStockInvoice invoice;

  const ClientStockInvoiceDetailModal({
    super.key,
    required this.invoice,
  });

  static Future<void> show(BuildContext context, {required ClientStockInvoice invoice}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientStockInvoiceDetailModal(invoice: invoice),
    );
  }

  @override
  ConsumerState<ClientStockInvoiceDetailModal> createState() => _ClientStockInvoiceDetailModalState();
}

class _ClientStockInvoiceDetailModalState extends ConsumerState<ClientStockInvoiceDetailModal> {
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');

  late ClientStockInvoice _currentInvoice;
  bool _isUploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
  }

  Future<void> _pickAndUploadReceipt() async {
    try {
      setState(() => _isUploadingReceipt = true);
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (result.isNotEmpty) {
        final pickedFile = result.first;
        final bytes = await pickedFile.readAsBytes();

        if (bytes.isNotEmpty) {
          final ext = pickedFile.extension?.toLowerCase() ?? 'png';
          final uploadedUrl = await SignatureStorageService.uploadReceiptDocument(
            bytes: bytes,
            invoiceNumber: _currentInvoice.invoiceNumber,
            extension: ext,
          );

          if (_currentInvoice.id.isNotEmpty) {
            await ref.read(clientPortalProvider.notifier).attachPaymentReceipt(
              invoiceId: _currentInvoice.id,
              receiptUrl: uploadedUrl,
            );
          }

          if (mounted) {
            setState(() {
              _currentInvoice = _currentInvoice.copyWith(paymentReceiptUrl: uploadedUrl);
              _isUploadingReceipt = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment receipt attached to invoice ${_currentInvoice.invoiceNumber}!',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          if (mounted) setState(() => _isUploadingReceipt = false);
        }
      } else {
        if (mounted) setState(() => _isUploadingReceipt = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingReceipt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to upload receipt document: $e'),
          ),
        );
      }
    }
  }

  void _openReceiptUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _previewImageModal(url);
      }
    } else {
      _previewImageModal(url);
    }
  }

  void _previewImageModal(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: url.startsWith('data:')
                    ? Image.memory(
                        Uri.parse(url).data!.contentAsBytes(),
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(24),
                          color: const Color(0xFF1E293B),
                          child: const Text('Unable to load receipt preview', style: TextStyle(color: Colors.white)),
                        ),
                      ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.of(context).size.width < 720;
    final inv = _currentInvoice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 960,
        constraints: const BoxConstraints(maxHeight: 860),
        child: Column(
          children: [
            // Modal Header Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              inv.invoiceNumber,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    inv.isProcessed ? 'Ledger Posted' : 'Draft Intake',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: inv.paymentStatus == 'paid'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                inv.paymentStatus.toUpperCase().replaceAll('_', ' '),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: inv.paymentStatus == 'paid'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Procured from ${inv.supplierName} • Destination: ${inv.destinationWarehouse} • Date: ${_dateFormat.format(inv.entryDate)}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Breakdown Cards
                    _buildFinancialSummaryBar(inv, isDark, isCompact),
                    const SizedBox(height: 24),

                    // Payment Receipt Attachment Banner
                    _buildPaymentReceiptSection(inv, isDark, isCompact),
                    const SizedBox(height: 24),

                    // Itemized Line Items Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consignment Line Items & Landed Cost Breakdown',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unit economics per SKU calculated into live inventory valuation rates',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${inv.items.length} Line Item${inv.items.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Spreadsheet Style Items Table
                    _buildItemsTable(inv, isDark, isCompact),

                    if (inv.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF0D9488)),
                                const SizedBox(width: 6),
                                Text(
                                  'Intake Notes & Quality Control',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              inv.notes,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Audit Ledger Reference: ${inv.invoiceNumber}',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryBar(ClientStockInvoice inv, bool isDark, bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF042F2E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2DD4BF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Landed Cost Valuation Breakdown',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${NumberFormat('#,###').format(inv.totalUnits)} Total Units',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF115E59), height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetricItem('1. Raw Supplier Cost', '₦${_currencyFormat.format(inv.subtotalRawProductCost)}'),
              _buildMetricItem('2. Packaging & Bottling', '₦${_currencyFormat.format(inv.totalPackagingCost)}'),
              _buildMetricItem('3. Haulage & Freight', '₦${_currencyFormat.format(inv.totalTransportationCost)}'),
              _buildMetricItem('4. Handling & Port', '₦${_currencyFormat.format(inv.totalHandlingClearingCost)}'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2DD4BF), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL LANDED VALUATION',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5EEAD4),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_currencyFormat.format(inv.grandTotalLandedCost)}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF99F6E4),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentReceiptSection(ClientStockInvoice inv, bool isDark, bool isCompact) {
    final hasReceipt = inv.hasPaymentReceipt;
    final receiptUrl = inv.paymentReceiptUrl ?? '';
    final isPdf = receiptUrl.toLowerCase().contains('.pdf');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file_rounded, color: Color(0xFF0D9488), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank Payment Proof & Supplier Receipt',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      hasReceipt
                          ? 'Audit document attached and archived for accounting reference'
                          : 'No proof document attached yet. Upload invoice or transfer slip.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUploadingReceipt)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                )
              else
                ElevatedButton.icon(
                  onPressed: _pickAndUploadReceipt,
                  icon: Icon(hasReceipt ? Icons.refresh_rounded : Icons.upload_file_rounded, size: 16),
                  label: Text(
                    hasReceipt ? 'Replace Receipt' : 'Upload Receipt File',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          if (hasReceipt) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: isPdf
                        ? const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 28)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: receiptUrl.startsWith('data:')
                                ? Image.memory(
                                    Uri.parse(receiptUrl).data!.contentAsBytes(),
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    receiptUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.receipt_rounded, size: 24),
                                  ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPdf ? 'PDF DOCUMENT' : 'IMAGE RECEIPT',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Receipt Document: ${inv.invoiceNumber}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receiptUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openReceiptUrl(receiptUrl),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: Text('View Document', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsTable(ClientStockInvoice inv, bool isDark, bool isCompact) {
    if (inv.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'No line items found for this stock intake invoice.',
          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columnSpacing: 18,
          horizontalMargin: 16,
          columns: [
            DataColumn(label: Text('#', style: _headerStyle(isDark))),
            DataColumn(label: Text('Product & SKU', style: _headerStyle(isDark))),
            DataColumn(label: Text('Qty', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Base Price', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Packaging', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Haulage', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Handling', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Landed / Unit', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Line Total Landed', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Target Retail', style: _headerStyle(isDark)), numeric: true),
            DataColumn(label: Text('Projected Margin', style: _headerStyle(isDark)), numeric: true),
          ],
          rows: inv.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final marginPositive = item.projectedMarginPercent >= 0;

            return DataRow(
              cells: [
                DataCell(Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)))),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        item.productSku,
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat('#,###').format(item.quantity),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text('₦${_currencyFormat.format(item.supplierUnitPrice)}', style: _cellStyle(isDark))),
                DataCell(Text('₦${_currencyFormat.format(item.packagingCostPerUnit)}', style: _cellStyle(isDark))),
                DataCell(Text('₦${_currencyFormat.format(item.transportationCostPerUnit)}', style: _cellStyle(isDark))),
                DataCell(Text('₦${_currencyFormat.format(item.handlingCostPerUnit)}', style: _cellStyle(isDark))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '₦${_currencyFormat.format(item.effectiveLandedCostPerUnit)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '₦${_currencyFormat.format(item.totalLandedCost)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    item.targetRetailPrice > 0
                        ? '₦${_currencyFormat.format(item.targetRetailPrice)}'
                        : '—',
                    style: _cellStyle(isDark),
                  ),
                ),
                DataCell(
                  item.targetRetailPrice > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: marginPositive
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${marginPositive ? '+' : ''}${item.projectedMarginPercent.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: marginPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        )
                      : Text('—', style: _cellStyle(isDark)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return GoogleFonts.inter(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
    );
  }

  TextStyle _cellStyle(bool isDark) {
    return GoogleFonts.inter(
      fontSize: 12.5,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
    );
  }
}
