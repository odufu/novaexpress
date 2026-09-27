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
  final Map<String, TextEditingController> _itemNoteControllers = {};

  final TextEditingController _carrierDriverCtrl = TextEditingController();
  final TextEditingController _carrierPhoneCtrl = TextEditingController();
  final TextEditingController _carrierPlateCtrl = TextEditingController();
  final TextEditingController _destinationBinCtrl = TextEditingController();
  final TextEditingController _generalNotesCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _carrierDriverCtrl.text = widget.transfer.carrierDriverName ?? '';
    _carrierPhoneCtrl.text = widget.transfer.carrierPhone ?? '';
    _carrierPlateCtrl.text = widget.transfer.carrierLicensePlate ?? '';
    _destinationBinCtrl.text = widget.transfer.destinationBin ?? 'Main Staging Bay A';

    for (final item in widget.transfer.items) {
      final initialQty = item.quantityShipped > 0 ? item.quantityShipped : item.quantity;
      _receivedControllers[item.id] =
          TextEditingController(text: initialQty > 0 ? initialQty.toString() : '0');
      _damagedControllers[item.id] = TextEditingController(text: '0');
      _missingControllers[item.id] = TextEditingController(text: '0');
      _itemNoteControllers[item.id] = TextEditingController(text: '');

      _receivedControllers[item.id]!.addListener(() => setState(() {}));
      _damagedControllers[item.id]!.addListener(() => setState(() {}));
      _missingControllers[item.id]!.addListener(() => setState(() {}));
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
    for (final c in _itemNoteControllers.values) {
      c.dispose();
    }
    _carrierDriverCtrl.dispose();
    _carrierPhoneCtrl.dispose();
    _carrierPlateCtrl.dispose();
    _destinationBinCtrl.dispose();
    _generalNotesCtrl.dispose();
    super.dispose();
  }

  int get _calcTotalExpected =>
      widget.transfer.items.fold(0, (sum, i) => sum + (i.quantityShipped > 0 ? i.quantityShipped : i.quantity));

  int get _calcTotalReceived =>
      widget.transfer.items.fold(0, (sum, i) => sum + (int.tryParse(_receivedControllers[i.id]?.text.trim() ?? '') ?? 0));

  int get _calcTotalDamaged =>
      widget.transfer.items.fold(0, (sum, i) => sum + (int.tryParse(_damagedControllers[i.id]?.text.trim() ?? '') ?? 0));

  int get _calcTotalMissing =>
      widget.transfer.items.fold(0, (sum, i) => sum + (int.tryParse(_missingControllers[i.id]?.text.trim() ?? '') ?? 0));

  bool get _hasDiscrepancy {
    if (_calcTotalDamaged > 0 || _calcTotalMissing > 0) return true;
    if (_calcTotalReceived != _calcTotalExpected) return true;
    return false;
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
      // Build itemized verification payload
      final verifiedItems = <Map<String, dynamic>>[];
      for (final item in widget.transfer.items) {
        final rawRec = int.tryParse(_receivedControllers[item.id]?.text.trim() ?? '');
        final shipped = item.quantityShipped > 0 ? item.quantityShipped : item.quantity;
        final dam = int.tryParse(_damagedControllers[item.id]?.text.trim() ?? '') ?? 0;
        final mis = int.tryParse(_missingControllers[item.id]?.text.trim() ?? '') ?? 0;
        final rec = (rawRec != null && rawRec >= 0) ? rawRec : ((dam == 0 && mis == 0) ? shipped : (rawRec ?? shipped));
        final note = _itemNoteControllers[item.id]?.text.trim() ?? '';

        verifiedItems.add({
          'item_id': item.id,
          'product_id': item.productId,
          'quantity_received': rec,
          'quantity_damaged': dam,
          'quantity_missing': mis,
          'notes': note.isNotEmpty ? note : item.itemNotes,
        });
      }

      final res = await ref.read(stockProvider.notifier).receiveSupplyConsignmentHandshake(
            transferId: widget.transfer.id,
            receiverId: supervisorId,
            receiverName: supervisorName,
            receiverRole: 'dc_supervisor',
            receiverSignatureUrl: '',
            carrierDriverName: _carrierDriverCtrl.text.trim(),
            carrierPhone: _carrierPhoneCtrl.text.trim(),
            carrierLicensePlate: _carrierPlateCtrl.text.trim(),
            waybillSlipUrl: '',
            destinationBin: _destinationBinCtrl.text.trim(),
            verifiedItems: verifiedItems,
            notes: _generalNotesCtrl.text.trim(),
            dcId: dcId,
          );

      if (!mounted) return;

      Navigator.of(context).pop();

      final hasDisc = res['has_discrepancy'] == true;
      final totalRec = res['total_received'] ?? _calcTotalReceived;

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
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasDisc
                      ? 'Inbound consignment received with discrepancies flagged! $totalRec physical units credited to DC shelves.'
                      : 'Consignment verified & sealed! $totalRec units balanced into DC warehouse bins.',
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
          content: Text('Consignment reception handshake error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isInterDc = widget.transfer.isInterDc;

    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: screenHeight * 0.94),
        width: double.infinity,
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 550 ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header with Badge & Waybill Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isInterDc ? const Color(0xFF2563EB) : const Color(0xFF10B981)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isInterDc ? Icons.swap_horiz_rounded : Icons.local_shipping_rounded,
                      color: isInterDc ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isInterDc ? 'Inter-DC Stock Reception Handshake' : 'Inbound Supply Consignment Handshake',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isInterDc ? const Color(0xFF2563EB) : const Color(0xFF10B981)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isInterDc ? 'INTER-DC FREIGHT' : 'SUPPLY INTAKE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isInterDc ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Waybill: ${widget.transfer.transferNumber} • Origin: ${widget.transfer.sourceWarehouseName ?? widget.transfer.senderName ?? 'Merchant Consignment'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // 2. Industrial Overview & Discrepancy KPI Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasDiscrepancy
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasDiscrepancy ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                              size: 18,
                              color: _hasDiscrepancy ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hasDiscrepancy ? 'DISCREPANCY DETECTED' : 'CLEAN MANIFEST MATCH',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _hasDiscrepancy ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Target: ${widget.transfer.destinationWarehouseName ?? 'Current Hub'}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildKpiCell('Expected Manifest', '$_calcTotalExpected', const Color(0xFF2563EB), isDark),
                        const SizedBox(width: 8),
                        _buildKpiCell('Good Received', '$_calcTotalReceived', const Color(0xFF10B981), isDark),
                        const SizedBox(width: 8),
                        _buildKpiCell('Damaged', '$_calcTotalDamaged', const Color(0xFFEF4444), isDark),
                        const SizedBox(width: 8),
                        _buildKpiCell('Missing / Shortage', '$_calcTotalMissing', const Color(0xFFF59E0B), isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Carrier & Dock Staging Details
              Text(
                'Carrier & Dock Intake Details',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _carrierDriverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Carrier / Driver Name',
                        hintText: 'e.g. Ibrahim Musa (Kano Haulage)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _carrierPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Driver Phone',
                        hintText: '080...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _destinationBinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Staging Shelf / Bin *',
                        hintText: 'Bay A-04',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Physical Itemized Inspection Grid
              Text(
                'Physical Item Verification Table',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Verify counted cartons against manifest. Flag any broken seals, leaks, or transit shortages.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),

              Column(
                children: widget.transfer.items.map((item) {
                  final recCtrl = _receivedControllers[item.id]!;
                  final damCtrl = _damagedControllers[item.id]!;
                  final misCtrl = _missingControllers[item.id]!;
                  final noteCtrl = _itemNoteControllers[item.id]!;

                  final expected = item.quantityShipped > 0 ? item.quantityShipped : item.quantity;
                  final currentRec = int.tryParse(recCtrl.text.trim()) ?? 0;
                  final currentDam = int.tryParse(damCtrl.text.trim()) ?? 0;
                  final currentMis = int.tryParse(misCtrl.text.trim()) ?? 0;
                  final hasItemDisc = currentDam > 0 || currentMis > 0 || currentRec != expected;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasItemDisc
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.productName.isNotEmpty ? item.productName : 'Product Item',
                                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.sku.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${item.sku})',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Manifest: $expected units',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: recCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Good Received *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          decoration: InputDecoration(
                            labelText: 'Condition / QC Note for ${item.productName}',
                            hintText: 'e.g. Batch # verified, inner seal unbroken',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 5. Supervisor Official Inspection Notes
              TextField(
                controller: _generalNotesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'DC Supervisor Reception & Acceptance Notes',
                  hintText: 'e.g. Carrier arrived on schedule. Visual inspection completed with seal intact.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // 6. Action Footer
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
                      backgroundColor: _hasDiscrepancy ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirmReceipt,
                    icon: Icon(_hasDiscrepancy ? Icons.warning_rounded : Icons.verified_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Verifying & Balancing Stock...'
                          : (_hasDiscrepancy ? 'Accept with Discrepancy Flag' : 'Verify & Credit DC Stock'),
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

  Widget _buildKpiCell(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
