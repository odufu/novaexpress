import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/map_launcher_helper.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../providers/dc_console_provider.dart';

class DCNotifyMerchantRestockModal extends ConsumerStatefulWidget {
  final StockItemEntity item;
  final String dcName;

  const DCNotifyMerchantRestockModal({
    super.key,
    required this.item,
    required this.dcName,
  });

  static Future<void> show(
    BuildContext context, {
    required StockItemEntity item,
    required String dcName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: DCNotifyMerchantRestockModal(
            item: item,
            dcName: dcName,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<DCNotifyMerchantRestockModal> createState() => _DCNotifyMerchantRestockModalState();
}

class _DCNotifyMerchantRestockModalState extends ConsumerState<DCNotifyMerchantRestockModal> {
  late TextEditingController _unitsController;
  late TextEditingController _messageController;
  String _selectedUrgency = 'CRITICAL'; // 'CRITICAL' | 'URGENT' | 'STANDARD'
  bool _isBroadcasting = false;
  bool _alreadySentInApp = false;

  @override
  void initState() {
    super.initState();
    final defaultBatch = widget.item.reorderLevel > 0
        ? widget.item.reorderLevel
        : (widget.item.lowStockThreshold > 0 ? widget.item.lowStockThreshold * 3 : 100);
    _unitsController = TextEditingController(text: '$defaultBatch');
    _messageController = TextEditingController();
    _updateGeneratedMessage();
  }

  @override
  void dispose() {
    _unitsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _updateGeneratedMessage() {
    final units = _unitsController.text.trim().isEmpty ? '100' : _unitsController.text.trim();
    final merchantName = widget.item.ownerName.isNotEmpty ? widget.item.ownerName : 'Merchant Partner';
    final dcName = widget.dcName.isNotEmpty ? widget.dcName : 'Wuse Grand Central Distribution Center';

    String urgencyTag;
    if (_selectedUrgency == 'CRITICAL') {
      urgencyTag = '🚨 [CRITICAL ALERT: ZERO SHELF INVENTORY]';
    } else if (_selectedUrgency == 'URGENT') {
      urgencyTag = '⚠️ [URGENT RESTOCK WARNING]';
    } else {
      urgencyTag = '📦 [INVENTORY REPLENISHMENT ADVISORY]';
    }

    _messageController.text = '''$urgencyTag
Dear $merchantName,

Warehouse shelf inventory for "${widget.item.name}" (SKU: ${widget.item.sku}) at our $dcName facility is currently at ${widget.item.availableCount} UNITS.

📊 Current Status:
• Shelf Balance (Available for Picking): ${widget.item.availableCount} Units
• Active Fleet / Courier Custody: ${widget.item.assignedCount} Units
• Delivered to Date: ${widget.item.deliveredCount} Units

⚠️ Impact: New customer order dispatches from this hub are halted once couriers exhaust their current stock.

Action Required:
Please dispatch an inbound replenishment consignment of at least $units Units to $dcName immediately to maintain fulfillment continuity.

Log into your merchant portal to raise a consignment:
https://novaxpress.ng/client/inventory

— NovaXpress DC Operations Command''';
  }

  Future<void> _broadcastInAppAlert() async {
    setState(() => _isBroadcasting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final notifRepo = ref.read(notificationsRepositoryProvider);
      final clientTargetId = widget.item.clientId ?? '';

      final title = _selectedUrgency == 'CRITICAL'
          ? '🚨 CRITICAL: ${widget.item.name} is OUT OF STOCK at ${widget.dcName}!'
          : '⚠️ Restock Alert: ${widget.item.name} (${widget.item.availableCount} left) at ${widget.dcName}';

      await notifRepo.emitNotification(
        title: title,
        message: 'Warehouse shelf balance is ${widget.item.availableCount} units. Couriers hold ${widget.item.assignedCount} units in field transit. Please dispatch an inbound consignment of at least ${_unitsController.text.trim()} units immediately.',
        category: 'stock',
        agentId: clientTargetId.isNotEmpty ? clientTargetId : null,
        actionRoute: '/client/inventory',
      );

      if (mounted) {
        setState(() {
          _isBroadcasting = false;
          _alreadySentInApp = true;
        });
        messenger.showSnackBar(
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
                    '✅ Restock alert broadcasted directly to ${widget.item.ownerName}\'s Merchant Portal!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBroadcasting = false);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('⚠️ Failed to dispatch in-app notification: $e'),
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsAppAlert() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _messageController.text.trim();

    // Try finding client phone if available from DC console state or fallback
    final dcState = ref.read(dcConsoleProvider);
    String? clientPhone;
    try {
      final clients = dcState.clients;
      final matched = clients.where((c) => c.id == widget.item.clientId || c.name.toLowerCase() == widget.item.ownerName.toLowerCase()).firstOrNull;
      clientPhone = matched?.phone;
    } catch (_) {}

    await MapLauncherHelper.launchWhatsApp(
      context: context,
      customerPhone: clientPhone ?? '',
      message: text,
      fallbackUri: Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
    );

    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'WhatsApp message formatted & ready to send to ${widget.item.ownerName}!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _copyToClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _messageController.text.trim()));
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📋 Restock notice copied to clipboard. Ready to paste in SMS, Email or Slack!',
                  style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZeroStock = widget.item.availableCount <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER WITH CRITICAL CALLOUT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
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
                            'Notify Merchant for Restock',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isZeroStock ? 'OUT OF STOCK' : 'LOW STOCK',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dispatch an immediate replenishment advisory to the merchant client across in-app, WhatsApp, and formal channels.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. PRODUCT & DC REAL-TIME TELEMETRY CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isZeroStock
                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${widget.item.sku} • Merchant: ${widget.item.ownerName}',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warehouse_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 5),
                          Text(
                            widget.dcName,
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTelemetryMiniBlock(
                        title: 'Warehouse Shelves',
                        value: '${widget.item.availableCount} Units',
                        color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                        sub: isZeroStock ? 'Depleted' : 'Low',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTelemetryMiniBlock(
                        title: 'In Rider Custody',
                        value: '${widget.item.assignedCount} Units',
                        color: const Color(0xFF8B5CF6),
                        sub: 'Field transit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTelemetryMiniBlock(
                        title: 'Total Delivered',
                        value: '${widget.item.deliveredCount} Units',
                        color: const Color(0xFF10B981),
                        sub: 'Completed',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. URGENCY & RECOMMENDED BATCH SIZE SELECTORS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Urgency Level
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Urgency Level',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedUrgency,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CRITICAL',
                          child: Text('🔴 Critical (Zero Stock - Order Stalled)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'URGENT',
                          child: Text('🟠 Urgent (High Run-Rate)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'STANDARD',
                          child: Text('🟡 Standard Re-order Notice', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedUrgency = val);
                          _updateGeneratedMessage();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Recommended Batch Size
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requested Restock Qty',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _unitsController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateGeneratedMessage(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixText: 'Units',
                        suffixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Qty Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBatchPresetChip(50),
              _buildBatchPresetChip(100),
              _buildBatchPresetChip(250),
              _buildBatchPresetChip(500),
            ],
          ),

          const SizedBox(height: 16),

          // 4. PRE-FORMED EDITABLE DISPATCH MESSAGE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Urgent Restock Dispatch Notice',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: _updateGeneratedMessage,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Reset Message',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 11.5, height: 1.4),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              filled: true,
            ),
          ),

          const SizedBox(height: 20),

          // 5. DISPATCH ACTION CHANNELS
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary 1: Broadcast In-App Alert to Merchant Portal
              ElevatedButton.icon(
                onPressed: (_isBroadcasting || _alreadySentInApp) ? null : _broadcastInAppAlert,
                icon: _isBroadcasting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_alreadySentInApp ? Icons.check_circle_rounded : Icons.notifications_active_rounded, size: 18, color: Colors.white),
                label: Text(
                  _alreadySentInApp
                      ? 'Alert Broadcasted to Merchant Portal ✓'
                      : (_isBroadcasting ? 'Broadcasting to Portal...' : '🚨 Send Instant In-App Alert to Merchant Portal'),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _alreadySentInApp ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),

              const SizedBox(height: 10),

              // Secondary Row: Direct WhatsApp + Copy Notice
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchWhatsAppAlert,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF25D366)),
                      label: Text(
                        'Send via WhatsApp',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF25D366)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Copy Full Notice',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMiniBlock({
    required String title,
    required String value,
    required Color color,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 9.5, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchPresetChip(int qty) {
    return InkWell(
      onTap: () {
        setState(() => _unitsController.text = '$qty');
        _updateGeneratedMessage();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF64748B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '+$qty Units',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}
