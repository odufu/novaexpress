import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stock/domain/entities/stock_transfer_record.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/dc_console_provider.dart';

class DcReceiveSupplyModal extends ConsumerStatefulWidget {
  final StockTransferRecord transfer;
  final VoidCallback? onReceived;

  const DcReceiveSupplyModal({
    super.key,
    required this.transfer,
    this.onReceived,
  });

  static Future<void> show({
    required BuildContext context,
    required StockTransferRecord transfer,
    VoidCallback? onReceived,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DcReceiveSupplyModal(
        transfer: transfer,
        onReceived: onReceived,
      ),
    );
  }

  @override
  ConsumerState<DcReceiveSupplyModal> createState() =>
      _DcReceiveSupplyModalState();
}

class _DcReceiveSupplyModalState extends ConsumerState<DcReceiveSupplyModal> {
  final Map<String, TextEditingController> _receivedControllers = {};
  final Map<String, TextEditingController> _damagedControllers = {};
  final Map<String, TextEditingController> _missingControllers = {};
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.transfer.items) {
      _receivedControllers[item.id] =
          TextEditingController(text: item.quantity.toString());
      _damagedControllers[item.id] = TextEditingController(text: '0');
      _missingControllers[item.id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in _receivedControllers.values) {
      c.dispose();
    }
    for (final c in _damagedControllers.values) {
      c.dispose();
    }
    for (final c in _missingControllers.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmReceipt() async {
    final authState = ref.read(authProvider);
    final supervisorName = authState.user?.fullName ?? 'DC Station Supervisor';
    final rawSupervisorId = authState.user?.id ?? '';
    final supervisorId = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(rawSupervisorId)
        ? rawSupervisorId
        : '88defe3b-3d7b-4616-a897-3e848caaecf1';
    final dcId = ref.read(dcConsoleProvider).activeHubId;

    setState(() => _isSubmitting = true);

    try {
      // 1. Build verified items payload
      final verifiedItems = <Map<String, dynamic>>[];
      for (final item in widget.transfer.items) {
        final rawRec = int.tryParse(_receivedControllers[item.id]?.text.trim() ?? '');
        final shipped = item.quantityShipped > 0 ? item.quantityShipped : item.quantity;
        final rec = (rawRec != null && rawRec >= 0) ? rawRec : shipped;
        final dam = int.tryParse(_damagedControllers[item.id]?.text.trim() ?? '') ?? 0;
        final mis = int.tryParse(_missingControllers[item.id]?.text.trim() ?? '') ?? 0;

        verifiedItems.add({
          'item_id': item.id,
          'product_id': item.productId,
          'quantity_received': rec,
          'quantity_damaged': dam,
          'quantity_missing': mis,
          'notes': item.itemNotes,
        });
      }

      final res = await ref.read(stockProvider.notifier).receiveClientSupply(
            transferId: widget.transfer.id,
            receiverId: supervisorId,
            receiverName: supervisorName,
            receiverSignatureUrl: '',
            verifiedItems: verifiedItems,
            notes: _notesCtrl.text.trim(),
            dcId: dcId,
          );

      if (!mounted) return;

      Navigator.of(context).pop();

      final hasDisc = res['has_discrepancy'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: hasDisc ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                hasDisc ? Icons.warning_amber_rounded : Icons.verified_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasDisc
                    ? 'Inbound supply recorded with discrepancies flagged. Stock units credited.'
                    : 'Inbound consignment verified & signed! Stock credited to DC warehouse bins.',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

      widget.onReceived?.call();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Receipt intake error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: Container(
        constraints: BoxConstraints(maxWidth: 750, maxHeight: screenHeight * 0.92),
        width: double.infinity,
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 500 ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inspect & Receive Inbound Supply',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Waybill: ${widget.transfer.transferNumber} • Sender: ${widget.transfer.senderName ?? 'Merchant'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Merchant Consignment Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.outbox_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incoming Merchant Consignment Manifest',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dispatched by ${widget.transfer.senderName ?? 'Merchant'} on ${widget.transfer.dispatchedAt?.toLocal().toString().substring(0, 16) ?? 'Arrival'}. Verify physical count against manifest before accepting custody.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Items Verification Grid
              Text(
                'Physical Item Verification Table',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),

              Column(
                children: widget.transfer.items.map((item) {
                  final recCtrl = _receivedControllers[item.id]!;
                  final damCtrl = _damagedControllers[item.id]!;
                  final misCtrl = _missingControllers[item.id]!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.productName.isNotEmpty ? item.productName : 'Product Item',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Manifest: ${item.quantity} units',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.sku.isNotEmpty)
                          Text(
                            'SKU: ${item.sku}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Verified Units Count
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: recCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Good Units Received *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Damaged Units Count
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: damCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Damaged',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Missing Units Count
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: misCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Missing',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Discrepancy / Intake Notes (Optional)',
                  hintText: 'e.g. 2 boxes crushed during transit by third-party hauler',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirmReceipt,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Verifying & Crediting DC...' : 'Verify & Accept Stock Receipt',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
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
