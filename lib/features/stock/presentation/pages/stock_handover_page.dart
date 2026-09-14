import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/stock_transfer_record.dart';
import '../providers/stock_provider.dart';

class StockHandoverPage extends ConsumerStatefulWidget {
  final String requestId;

  const StockHandoverPage({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<StockHandoverPage> createState() => _StockHandoverPageState();
}

class _StockHandoverPageState extends ConsumerState<StockHandoverPage> {
  StockTransferRecord? _transfer;
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, int> _verifiedCounts = {};
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTransfer();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTransfer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(stockRepositoryProvider);
      StockTransferRecord? record = await repo.getStockTransferById(widget.requestId);

      // If not found by primary key, try finding in already loaded transfers
      if (record == null) {
        final allTransfers = ref.read(stockProvider).stockTransfers;
        record = allTransfers.where((t) =>
            t.id == widget.requestId ||
            t.transferNumber == widget.requestId).firstOrNull;
      }

      if (record != null) {
        for (final item in record.items) {
          _verifiedCounts[item.id] = item.quantity;
        }
      }

      setState(() {
        _transfer = record;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _increment(String itemId) {
    setState(() {
      _verifiedCounts[itemId] = (_verifiedCounts[itemId] ?? 0) + 1;
    });
  }

  void _decrement(String itemId) {
    setState(() {
      final current = _verifiedCounts[itemId] ?? 0;
      if (current > 0) {
        _verifiedCounts[itemId] = current - 1;
      }
    });
  }

  Future<void> _handleAccept() async {
    if (_transfer == null) return;

    final user = ref.read(authProvider).user;
    final riderName = user != null && user.firstName.isNotEmpty
        ? '${user.firstName} ${user.lastName}'.trim()
        : 'Rider Agent';
    final riderId = user?.deliveryAgentId ?? user?.id ?? '';
    setState(() => _isSubmitting = true);

    try {
      final verifiedPayload = _transfer!.items.map((item) {
        return {
          'item_id': item.id,
          'quantity_received': _verifiedCounts[item.id] ?? item.quantity,
        };
      }).toList();

      final res = await ref.read(stockProvider.notifier).acceptRiderStockHandover(
            transferId: _transfer!.id,
            riderId: riderId,
            riderName: riderName,
            riderSignatureUrl: '',
            verifiedItems: verifiedPayload,
            notes: _notesCtrl.text.trim(),
          );

      if (!mounted) return;

      final hasDisc = res['has_discrepancy'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: hasDisc ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                hasDisc ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasDisc
                      ? 'Stock accepted with discrepancies flagged! Committed to vehicle custody.'
                      : 'Stock Handover Accepted & Signed! Units added to your vehicle custody.',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

      context.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Handover acceptance error: $e'),
        ),
      );
    }
  }

  Future<void> _handleReject() async {
    if (_transfer == null) return;

    final reasonCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            const Text('Reject Stock Handover'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to decline custody of this stock transfer? The reserved units will be immediately refunded back to the DC warehouse shelf.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection *',
                hintText: 'e.g. Broken packages, vehicle space full',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider).user;
      final riderId = user?.deliveryAgentId ?? user?.id ?? '';

      await ref.read(stockProvider.notifier).rejectRiderStockHandover(
            transferId: _transfer!.id,
            riderId: riderId,
            reason: reasonCtrl.text.trim(),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Stock handover declined. Units refunded back to DC shelf.'),
        ),
      );

      context.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Rejection error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final agentName = user != null && user.firstName.isNotEmpty
        ? '${user.firstName} ${user.lastName}'.trim()
        : 'Delivery Agent';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Stock Handover Acceptance',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load handover details',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadTransfer,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _transfer == null
                  ? _buildFallbackStaticView(isDark, agentName)
                  : _buildDynamicTransferView(isDark, agentName),
    );
  }

  Widget _buildDynamicTransferView(bool isDark, String agentName) {
    final trf = _transfer!;
    final hasDiscrepancy = trf.items.any((item) => (_verifiedCounts[item.id] ?? item.quantity) != item.quantity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Handover Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STOCK HANDOVER WAYBILL',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trf.status.toUpperCase().replaceAll('_', ' '),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trf.transferNumber,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Source DC: ${trf.sourceWarehouseName ?? 'Distribution Center'}',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Assigned Rider: $agentName',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Supervisor Dispatch Allocation Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Supervisor Dispatch Allocation',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trf.senderName ?? 'DC Station Supervisor',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dispatched: ${trf.dispatchedAt?.toLocal().toString().substring(0, 16) ?? 'Pending handover'}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    if (trf.notes != null && trf.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        trf.notes!,
                        style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Discrepancy Alert Banner
          if (hasDiscrepancy) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF97316)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Count in hand differs from DC allocation. Any unaccepted units will be refunded immediately back to warehouse shelf.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9A3412)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. Physical Count Verification Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Verify Units in Hand',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Adjust count if physical differs',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Item Cards
          ...trf.items.map((item) {
            final expectedQty = item.quantity;
            final verifiedQty = _verifiedCounts[item.id] ?? expectedQty;
            final isMatch = verifiedQty == expectedQty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMatch
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                        : const Color(0xFFF43F5E),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A2D3).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF00A2D3), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName.isNotEmpty ? item.productName : 'Product Item',
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Allocated: $expectedQty units by DC Supervisor',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    // Counter Controls
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE11D48), size: 22),
                          onPressed: () => _decrement(item.id),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 28),
                          alignment: Alignment.center,
                          child: Text(
                            '$verifiedQty',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isMatch ? null : const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
                          onPressed: () => _increment(item.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // Notes field
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Handover / Condition Notes (Optional)',
              hintText: 'e.g. All 10 seals intact and counted in hand',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // 6. Action Buttons: Accept with Signature or Decline
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _handleReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline Handover', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _isSubmitting ? 'Accepting Custody...' : 'Accept Stock Custody',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackStaticView(bool isDark, String agentName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'Handover request ${widget.requestId} not found in live ledger.',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return to Inventory'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
