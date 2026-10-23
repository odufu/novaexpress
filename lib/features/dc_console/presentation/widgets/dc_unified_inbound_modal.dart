import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/domain/entities/stock_transfer_record.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/dc_console_provider.dart';
import 'dc_receive_supply_modal.dart';

class DCUnifiedInboundModal extends ConsumerStatefulWidget {
  final int initialTab;
  final VoidCallback? onComplete;

  const DCUnifiedInboundModal({
    super.key,
    this.initialTab = 0,
    this.onComplete,
  });

  static Future<void> show({
    required BuildContext context,
    int initialTab = 0,
    VoidCallback? onComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DCUnifiedInboundModal(
        initialTab: initialTab,
        onComplete: onComplete,
      ),
    );
  }

  @override
  ConsumerState<DCUnifiedInboundModal> createState() => _DCUnifiedInboundModalState();
}

class _DCUnifiedInboundModalState extends ConsumerState<DCUnifiedInboundModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final activeHubId = dcState.activeHubId;

    // Filter incoming transfers by source
    final transfers = stockState.stockTransfers;

    // 1. Merchant Supplies (client_supply / inward supplier consignments)
    final merchantSupplies = transfers.where((t) {
      final isDestMatch = t.destinationDcId == null || t.destinationDcId == activeHubId;
      final isPending = t.status != 'completed' && t.status != 'rejected';
      return (t.isClientSupply || t.transferType == 'client_supply') && isDestMatch && isPending;
    }).toList();

    // 2. Inter-DC Transfers (from other DCs to this DC)
    final interDcTransfers = transfers.where((t) {
      final isDestMatch = t.destinationDcId == activeHubId;
      final isPending = t.status != 'completed' && t.status != 'rejected';
      return (t.isInterDc || t.transferType == 'dc_to_dc') && isDestMatch && isPending;
    }).toList();

    // 3. Rider Returns (from delivery agents returning unsold/damaged items)
    final riderReturns = transfers.where((t) {
      final isDestMatch = t.destinationDcId == null || t.destinationDcId == activeHubId;
      final isPending = t.status != 'completed' && t.status != 'rejected';
      return (t.isRiderReturn || t.transferType == 'rider_return') && isDestMatch && isPending;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.move_to_inbox_rounded, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inbound Stock Intake & Reception',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${dcState.activeHubName} • Physical Handover & Bin Crediting',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar Switcher for 3 Channels
            Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0284C7),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0284C7),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Merchants'),
                        if (merchantSupplies.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          _buildBadge(merchantSupplies.length, const Color(0xFF0284C7)),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Other DCs'),
                        if (interDcTransfers.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          _buildBadge(interDcTransfers.length, const Color(0xFF2563EB)),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.motorcycle_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Riders'),
                        if (riderReturns.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          _buildBadge(riderReturns.length, const Color(0xFFEA580C)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Direct Ad-Hoc Supply Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Goods Inward Staging Area',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  TextButton.icon(
                    onPressed: () => _openDirectSupplyModal(context, isDark, stockState.stockItems, activeHubId),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF0284C7)),
                    label: Text(
                      '+ Log Direct Merchant Supply',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Merchants
                  _buildInboundList(
                    items: merchantSupplies,
                    emptyMessage: 'No pending merchant supplies awaiting intake.',
                    emptyIcon: Icons.storefront_rounded,
                    channelColor: const Color(0xFF0284C7),
                    isDark: isDark,
                    onAccept: (trf) => _acceptMerchantSupply(trf),
                  ),

                  // Tab 1: Other DCs
                  _buildInboundList(
                    items: interDcTransfers,
                    emptyMessage: 'No incoming transfers from other Distribution Centers.',
                    emptyIcon: Icons.local_shipping_rounded,
                    channelColor: const Color(0xFF2563EB),
                    isDark: isDark,
                    onAccept: (trf) => _acceptInterDcTransfer(trf, activeHubId),
                  ),

                  // Tab 2: Riders
                  _buildInboundList(
                    items: riderReturns,
                    emptyMessage: 'No pending rider returns awaiting check-in.',
                    emptyIcon: Icons.motorcycle_rounded,
                    channelColor: const Color(0xFFEA580C),
                    isDark: isDark,
                    onAccept: (trf) => _acceptRiderReturn(trf, activeHubId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildInboundList({
    required List<StockTransferRecord> items,
    required String emptyMessage,
    required IconData emptyIcon,
    required Color channelColor,
    required bool isDark,
    required Function(StockTransferRecord) onAccept,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 44, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                emptyMessage,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final trf = items[index];
        final totalQty = trf.totalQuantityRequested;
        final itemsDesc = trf.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: channelColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: channelColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trf.transferNumber,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: channelColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trf.status.toUpperCase().replaceAll('_', ' '),
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: channelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$totalQty Units',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: channelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Sender / Originator details
              Row(
                children: [
                  Icon(emptyIcon, size: 14, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'From: ${trf.senderName ?? "External Supplier / DC"}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Items summary
              Text(
                'Cargo: ${itemsDesc.isNotEmpty ? itemsDesc : "$totalQty incoming units"}',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (trf.carrierDriverName != null && trf.carrierDriverName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Driver: ${trf.carrierDriverName}${trf.carrierPhone != null ? " (${trf.carrierPhone})" : ""}${trf.carrierLicensePlate != null ? " • Plate: ${trf.carrierLicensePlate}" : ""}',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // Action button to accept
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 15),
                  label: Text(
                    'Verify & Accept into DC Inventory',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessing ? null : () => onAccept(trf),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Action: Accept Merchant Supply (via DcReceiveSupplyModal)
  void _acceptMerchantSupply(StockTransferRecord trf) {
    DcReceiveSupplyModal.show(
      context: context,
      transfer: trf,
      onReceived: () {
        ref.read(stockProvider.notifier).fetchStockItems(null, ref.read(dcConsoleProvider).activeHubId);
        ref.read(stockProvider.notifier).fetchStockTransfers(dcId: ref.read(dcConsoleProvider).activeHubId);
        widget.onComplete?.call();
      },
    );
  }

  // Action: Accept Inter-DC Transfer
  Future<void> _acceptInterDcTransfer(StockTransferRecord trf, String activeHubId) async {
    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final totalExpected = trf.totalQuantityRequested;
        final ctrl = TextEditingController(text: '$totalExpected');
        final notesCtrl = TextEditingController();

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accept Inter-DC Transfer',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arriving from: ${trf.senderName ?? "Regional DC"} (${trf.transferNumber})',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Items: ${trf.items.map((i) => "${i.quantity}x ${i.productName}").join(", ")}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Verified Units Counted',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reception Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final count = int.tryParse(ctrl.text.trim()) ?? totalExpected;
                Navigator.pop(ctx, count);
              },
              child: const Text('Confirm Reception'),
            ),
          ],
        );
      },
    );

    if (confirmed != null) {
      setState(() => _isProcessing = true);
      try {
        final user = ref.read(authProvider).user;
        await ref.read(stockProvider.notifier).receiveInterDcTransfer(
              transferId: trf.id,
              receiverId: user?.id ?? '',
              receiverName: user?.fullName ?? 'DC Station Supervisor',
              quantityReceived: confirmed,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('✅ Inter-DC stock intake verified! $confirmed units credited to DC shelves.'),
            ),
          );
        }

        ref.read(stockProvider.notifier).fetchStockItems(null, activeHubId);
        ref.read(stockProvider.notifier).fetchStockTransfers(dcId: activeHubId);
        widget.onComplete?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Error receiving transfer: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // Action: Accept Rider Return
  Future<void> _acceptRiderReturn(StockTransferRecord trf, String activeHubId) async {
    final totalExpected = trf.totalQuantityRequested;
    String selectedCondition = 'good';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '$totalExpected');
        final notesCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.motorcycle_rounded, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accept Rider Stock Return',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Returning Rider: ${trf.senderName ?? "Delivery Agent"} (${trf.transferNumber})',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Returned Items: ${trf.items.map((i) => "${i.quantity}x ${i.productName}").join(", ")}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Verified Quantity Received',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCondition,
                    decoration: const InputDecoration(
                      labelText: 'Physical Condition',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'good',
                        child: Text('Good (Restock to Active Warehouse Shelf)'),
                      ),
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text('Damaged / Spoilage (Send to Quarantine)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedCondition = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Inspection Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final qty = int.tryParse(ctrl.text.trim()) ?? totalExpected;
                    Navigator.pop(ctx, {
                      'qty': qty,
                      'condition': selectedCondition,
                      'notes': notesCtrl.text.trim(),
                    });
                  },
                  child: const Text('Confirm & Restock'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _isProcessing = true);
      try {
        final user = ref.read(authProvider).user;
        final int qty = result['qty'] as int;
        final String cond = result['condition'] as String;
        final String n = result['notes'] as String;

        await ref.read(stockProvider.notifier).receiveRiderReturn(
              returnId: trf.id,
              dcId: activeHubId,
              receiverId: user?.id ?? '',
              verifiedQuantity: qty,
              condition: cond,
              notes: n,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text(
                cond == 'good'
                    ? '✅ Return checked in! $qty units restocked to DC warehouse.'
                    : '⚠️ Return flagged as damaged: $qty units quarantined.',
              ),
            ),
          );
        }

        ref.read(stockProvider.notifier).fetchStockItems(null, activeHubId);
        ref.read(stockProvider.notifier).fetchStockTransfers(dcId: activeHubId);
        widget.onComplete?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Error receiving return: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // Modal: Log Direct Inbound Supply on the Fly
  void _openDirectSupplyModal(
    BuildContext context,
    bool isDark,
    List<StockItemEntity> products,
    String activeHubId,
  ) {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available in catalog.')),
      );
      return;
    }

    String selectedProdId = products.first.id;
    final qtyCtrl = TextEditingController(text: '100');
    final merchantCtrl = TextEditingController(text: 'Novacare Pharmaceuticals Ltd');
    final driverCtrl = TextEditingController(text: 'Musa Ibrahim');
    final plateCtrl = TextEditingController(text: 'ABJ-892-KT');
    final binCtrl = TextEditingController(text: 'Bay A-01');
    final notesCtrl = TextEditingController(text: 'Direct factory consignment drop-off');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_business_rounded, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log Direct Merchant Supply',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProdId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
                    items: products.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.sku})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedProdId = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: merchantCtrl,
                    decoration: const InputDecoration(labelText: 'Merchant / Manufacturer Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity Received', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: driverCtrl,
                    decoration: const InputDecoration(labelText: 'Delivery Driver Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle Plate Number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: binCtrl,
                    decoration: const InputDecoration(labelText: 'Target Warehouse Bin Location', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Intake Notes', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  if (qty <= 0) return;

                  Navigator.pop(ctx);
                  setState(() => _isProcessing = true);
                  try {
                    final user = ref.read(authProvider).user;
                    final waybill = 'WB-INWARD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                    // Issue intake via repository
                    await ref.read(stockProvider.notifier).receiveClientSupply(
                          transferId: 'direct_${DateTime.now().millisecondsSinceEpoch}',
                          receiverId: user?.id ?? '',
                          receiverName: user?.fullName ?? 'DC Supervisor',
                          verifiedItems: [
                            {
                              'product_id': selectedProdId,
                              'quantity_received': qty,
                              'quantity_shipped': qty,
                            }
                          ],
                          notes: '${notesCtrl.text.trim()} • Merchant: ${merchantCtrl.text.trim()} • Waybill: $waybill • Bin: ${binCtrl.text.trim()}',
                        );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF16A34A),
                          content: Text('✅ Inbound supply recorded! $qty units credited to warehouse.'),
                        ),
                      );
                    }

                    ref.read(stockProvider.notifier).fetchStockItems(null, activeHubId);
                    ref.read(stockProvider.notifier).fetchStockTransfers(dcId: activeHubId);
                    widget.onComplete?.call();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Error recording intake: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
                child: const Text('Record & Stock In'),
              ),
            ],
          );
        },
      ),
    );
  }
}
