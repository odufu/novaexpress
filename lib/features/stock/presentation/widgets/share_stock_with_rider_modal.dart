import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/dc_fleet_driver.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';

class ShareStockWithRiderModal extends ConsumerStatefulWidget {
  final StockItemEntity? initialItem;

  const ShareStockWithRiderModal({
    super.key,
    this.initialItem,
  });

  static Future<void> show(
    BuildContext context, {
    StockItemEntity? initialItem,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: ShareStockWithRiderModal(initialItem: initialItem),
        ),
      ),
    );
  }

  @override
  ConsumerState<ShareStockWithRiderModal> createState() => _ShareStockWithRiderModalState();
}

class _ShareStockWithRiderModalState extends ConsumerState<ShareStockWithRiderModal> {
  StockItemEntity? _selectedItem;
  DCFleetDriver? _selectedRecipientDriver;
  int _transferQuantity = 1;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final stockState = ref.watch(stockProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final currentUser = ref.watch(authProvider).user;
    final currentRiderId = currentUser?.deliveryAgentId ?? currentUser?.id ?? '';

    // Filter available stock items that rider has in custody
    final availableItems = stockState.stockItems.where((i) => i.availableCount > 0 || i.totalInCustody > 0).toList();
    _selectedItem ??= availableItems.isNotEmpty ? availableItems.first : null;

    final maxUnits = _selectedItem != null
        ? (_selectedItem!.availableCount > 0 ? _selectedItem!.availableCount : _selectedItem!.totalInCustody)
        : 0;

    // Filter drivers to other active fleet riders (excluding self)
    final otherDrivers = dcState.drivers.where((d) => d.id != currentRiderId && d.driverCode != currentUser?.closerCode).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Stock with Rider',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Peer-to-peer inventory custody handover',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Select Product from Custody
                  Text(
                    'SELECT PRODUCT FROM YOUR CUSTODY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (availableItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Text('You currently have no stock units in custody to share.'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StockItemEntity>(
                          value: _selectedItem,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: availableItems.map((item) {
                            final units = item.availableCount > 0 ? item.availableCount : item.totalInCustody;
                            return DropdownMenuItem(
                              value: item,
                              child: Text(
                                '${item.name} (${item.sku}) • $units in custody',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedItem = val;
                              _transferQuantity = 1;
                            });
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 2. Select Recipient Rider
                  Text(
                    'RECIPIENT RIDER (PARTY B)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DCFleetDriver>(
                        value: _selectedRecipientDriver,
                        hint: Text('Select recipient rider in fleet', style: GoogleFonts.inter(fontSize: 12.5)),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: otherDrivers.map((driver) {
                          return DropdownMenuItem(
                            value: driver,
                            child: Row(
                              children: [
                                const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(
                                  '${driver.name} (${driver.driverCode})',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRecipientDriver = val),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Quantity to Share
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRANSFER QUANTITY',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'Max available: $maxUnits units',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        onPressed: _transferQuantity > 1 ? () => setState(() => _transferQuantity--) : null,
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2563EB)),
                        ),
                        child: Text(
                          '$_transferQuantity Units',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        onPressed: _transferQuantity < maxUnits ? () => setState(() => _transferQuantity++) : null,
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Notes / Reason
                  Text(
                    'TRANSFER NOTES / LOCATION OF HANDOVER',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Shared at Wuse 2 market junction for express delivery.',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Dual Approval Notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Safe & Sure Handover: Stock will only be deducted from your custody once ${_selectedRecipientDriver?.name ?? "the recipient rider"} verifies and accepts it.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_selectedItem == null || _selectedRecipientDriver == null || maxUnits <= 0 || _isSubmitting)
                    ? null
                    : () async {
                        // Summary confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Stock Transfer Handover'),
                            content: Text(
                              'Are you sure you want to transfer $_transferQuantity units of ${_selectedItem!.name} to ${_selectedRecipientDriver!.name} (${_selectedRecipientDriver!.driverCode})?\n\nThe transfer will remain pending until the recipient physically accepts custody.',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Yes, Send Handover Request'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;

                        setState(() => _isSubmitting = true);

                        final res = await ref.read(stockProvider.notifier).initiateRiderToRiderTransfer(
                              productId: _selectedItem!.id,
                              productName: _selectedItem!.name,
                              sku: _selectedItem!.sku,
                              quantity: _transferQuantity,
                              senderRiderId: currentRiderId,
                              senderRiderName: currentUser?.fullName ?? 'Rider',
                              senderRiderCode: currentUser?.closerCode ?? 'RDR',
                              recipientRiderId: _selectedRecipientDriver!.id,
                              recipientRiderName: _selectedRecipientDriver!.name,
                              recipientRiderCode: _selectedRecipientDriver!.driverCode,
                              notes: _notesCtrl.text.trim(),
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Handover transfer sent to recipient rider.'),
                            ),
                          );
                        }
                      },
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Dispatch Handover Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
