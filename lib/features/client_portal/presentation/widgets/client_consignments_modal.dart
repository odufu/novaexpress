import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../stock/domain/entities/stock_transfer_record.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientConsignmentsModal extends ConsumerStatefulWidget {
  const ClientConsignmentsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ClientConsignmentsModal(),
    );
  }

  @override
  ConsumerState<ClientConsignmentsModal> createState() =>
      _ClientConsignmentsModalState();
}

class _ClientConsignmentsModalState
    extends ConsumerState<ClientConsignmentsModal> {
  String _selectedFilter = 'all'; // all, dispatched, completed, discrepancy

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clientId = ref.read(clientPortalProvider).clientProfile.id;
      ref.read(stockProvider.notifier).fetchStockTransfers(
            clientId: clientId.isNotEmpty ? clientId : null,
            transferType: 'client_to_dc',
          );
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'pending_dc_acceptance':
      case 'dispatched':
      case 'in_transit':
        return const Color(0xFFF59E0B);
      case 'discrepancy_reported':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Received & Stock Balanced';
      case 'pending_dc_acceptance':
      case 'dispatched':
      case 'in_transit':
        return 'Awaiting Receipt & Approval';
      case 'discrepancy_reported':
        return 'Discrepancy Reported';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  void _showTransferDetail(StockTransferRecord transfer, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          padding: EdgeInsets.all(MediaQuery.of(ctx).size.width < 500 ? 14 : 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transfer.transferNumber,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Two-Way Consignment Verification & Custody Audit Trail',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Products Shipped Breakdown
                Text(
                  'Consignment Items',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: transfer.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName.isNotEmpty ? item.productName : 'Product Item',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  if (item.sku.isNotEmpty)
                                    Text(
                                      'SKU: ${item.sku}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Shipped: ${item.quantity}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                                if (transfer.isCompleted || transfer.isDiscrepancyReported) ...[
                                  Text(
                                    'Received: ${item.quantityReceived}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  if (item.quantityDamaged > 0)
                                    Text(
                                      'Damaged: ${item.quantityDamaged}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  if (item.quantityMissing > 0)
                                    Text(
                                      'Missing: ${item.quantityMissing}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Two-Way Custody Verification Handshake (Party A & Party B)
                Text(
                  'Two-Way Custody Verification Handshake',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, sigConstraints) {
                    final isNarrow = sigConstraints.maxWidth < 460;

                    final partyACard = Container(
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
                            children: [
                              const Icon(Icons.outbox_rounded, size: 16, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Giver: Merchant Dispatch',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            transfer.senderName ?? 'Client Admin',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            transfer.dispatchedAt != null
                                ? 'Dispatched: ${transfer.dispatchedAt!.toLocal().toString().substring(0, 16)}'
                                : 'Consignment Logged',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quantity Dispatched: ${transfer.totalQuantityRequested} units',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 6),
                                Text(
                                  'Consignment Logged & Sent',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    final isReceived = transfer.isCompleted;
                    final isDiscrepancy = transfer.isDiscrepancyReported;

                    final partyBCard = Container(
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
                            children: [
                              Icon(
                                Icons.warehouse_rounded,
                                size: 16,
                                color: isReceived
                                    ? const Color(0xFF10B981)
                                    : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Receiver: DC Intake',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isReceived
                                        ? const Color(0xFF10B981)
                                        : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            transfer.receiverName ?? (isReceived ? 'DC Supervisor' : 'Pending DC Intake'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            transfer.receivedAt != null
                                ? 'Verified: ${transfer.receivedAt!.toLocal().toString().substring(0, 16)}'
                                : 'Pending physical count',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isReceived
                                ? 'Quantity Accepted: ${transfer.totalQuantityReceived} units'
                                : 'Expected Intake: ${transfer.totalQuantityRequested} units',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isReceived
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isReceived
                                      ? const Color(0xFF10B981)
                                      : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)))
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isReceived
                                        ? const Color(0xFF10B981)
                                        : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)))
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isReceived
                                      ? Icons.check_circle_rounded
                                      : (isDiscrepancy ? Icons.warning_amber_rounded : Icons.hourglass_empty_rounded),
                                  size: 14,
                                  color: isReceived
                                      ? const Color(0xFF10B981)
                                      : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isReceived
                                      ? 'Received & Stock Balanced'
                                      : (isDiscrepancy ? 'Discrepancy Logged' : 'Awaiting Receipt & Approval'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isReceived
                                        ? const Color(0xFF10B981)
                                        : (isDiscrepancy ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          partyACard,
                          const SizedBox(height: 12),
                          partyBCard,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: partyACard),
                        const SizedBox(width: 12),
                        Expanded(child: partyBCard),
                      ],
                    );
                  },
                ),

                if (transfer.hasDiscrepancy &&
                    transfer.discrepancyNotes != null &&
                    transfer.discrepancyNotes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'DC Discrepancy Note',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transfer.discrepancyNotes!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);

    final transfers = stockState.stockTransfers.where((t) {
      if (!t.isClientSupply) return false;
      if (_selectedFilter == 'dispatched') return t.isDispatched;
      if (_selectedFilter == 'completed') return t.isCompleted;
      if (_selectedFilter == 'discrepancy') return t.hasDiscrepancy;
      return true;
    }).toList();

    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 550;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 16 : 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 850,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        padding: EdgeInsets.all(isCompact ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inbound Stock Consignments',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 16 : 20,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Two-way verified custody handshake between Merchant and Distribution Center',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Consignments (${transfers.length})', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('dispatched', 'In Transit (${stockState.pendingClientSupplies.length})', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Received & Verified', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('discrepancy', 'Discrepancies', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Consignments List
            Expanded(
              child: stockState.isTransfersLoading
                  ? const Center(child: CircularProgressIndicator())
                  : transfers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_rounded, size: 48, color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                              const SizedBox(height: 12),
                              Text(
                                'No consignments found for this filter.',
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: transfers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final trf = transfers[index];
                            final statusColor = _getStatusColor(trf.status);

                            return Container(
                              padding: EdgeInsets.all(isCompact ? 12 : 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, itemConstraints) {
                                  final isItemNarrow = itemConstraints.maxWidth < 480;

                                  final detailsColumn = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            trf.transferNumber,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getStatusLabel(trf.status),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Destination Hub: ${trf.destinationWarehouseName ?? 'DC Station'} • Created: ${trf.createdAt.toLocal().toString().substring(0, 10)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Total Units: ${trf.totalQuantityRequested}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          if (trf.isCompleted || trf.isDiscrepancyReported) ...[
                                            Text(
                                              'Received: ${trf.totalQuantityReceived}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                            if (trf.totalQuantityDamaged > 0) ...[
                                              Text(
                                                'Damaged: ${trf.totalQuantityDamaged}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ],
                                  );

                                  final actionBtn = OutlinedButton.icon(
                                    onPressed: () => _showTransferDetail(trf, isDark),
                                    icon: const Icon(Icons.verified_rounded, size: 16),
                                    label: const Text('Verification Audit'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF10B981),
                                      side: const BorderSide(color: Color(0xFF10B981)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );

                                  if (isItemNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        detailsColumn,
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: actionBtn,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: detailsColumn),
                                      actionBtn,
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
          ),
        ),
      ),
    );
  }
}
