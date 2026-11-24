import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/client_closer.dart';
import '../providers/client_portal_provider.dart';
import '../providers/sales_supervisor_provider.dart';
import '../../../pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class SupervisorReassignOrderModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final List<ClientCloser> availableClosers;
  final String supervisorName;

  const SupervisorReassignOrderModal({
    super.key,
    required this.order,
    required this.availableClosers,
    required this.supervisorName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrderEntity order,
    required List<ClientCloser> availableClosers,
    required String supervisorName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SupervisorReassignOrderModal(
        order: order,
        availableClosers: availableClosers,
        supervisorName: supervisorName,
      ),
    );
  }

  @override
  ConsumerState<SupervisorReassignOrderModal> createState() =>
      _SupervisorReassignOrderModalState();
}

class _SupervisorReassignOrderModalState
    extends ConsumerState<SupervisorReassignOrderModal> {
  ClientCloser? _selectedCloser;
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReassign() async {
    if (_selectedCloser == null) return;
    setState(() => _isSubmitting = true);

    try {
      final target = _selectedCloser!;
      final prevName = widget.order.closerName ?? 'Previous Agent';
      final now = DateTime.now();
      final reasonText = _reasonCtrl.text.trim();
      final auditNote = '[REASSIGNED BY ${widget.supervisorName.toUpperCase()}] '
          'From $prevName to ${target.fullName} (${target.closerCode}). '
          '${reasonText.isNotEmpty ? "Reason: $reasonText" : ""}';

      final existingNotes = widget.order.deliveryNotes;
      final updatedNotes = existingNotes != null && existingNotes.trim().isNotEmpty
          ? '$existingNotes | $auditNote'
          : auditNote;

      final updatedOrder = widget.order.copyWith(
        closerId: target.id,
        closerName: target.fullName,
        closerCode: target.closerCode,
        closerAvatarUrl: target.avatarUrl,
        assignedAt: now,
        deliveryNotes: updatedNotes,
      );

      // 1. Update order in Supabase & ordersProvider
      await ref.read(ordersProvider.notifier).updateOrder(updatedOrder);

      // 2. Post notification / announcement to pipeline chat
      try {
        final chatMessage = '🔄 Order reassigned from $prevName to ${target.fullName} (${target.closerCode}) '
            'by Supervisor ${widget.supervisorName}.'
            '${reasonText.isNotEmpty ? "\nNote: $reasonText" : ""}';

        await ref.read(pipelineChatProvider.notifier).sendTextMessage(
          chatMessage,
          metadata: {
            'is_internal_note': true,
            'type': 'order_reassigned',
            'previous_closer': prevName,
            'new_closer': target.fullName,
            'supervisor': widget.supervisorName,
          },
        );
      } catch (_) {}

      // 3. Post notification to notifications provider
      try {
        ref.read(notificationsProvider.notifier).emitLocalNotification(
          title: 'Order Reassigned: #${widget.order.orderNumber}',
          message: '#${widget.order.orderNumber} reassigned to closer ${target.fullName} by supervisor ${widget.supervisorName}.',
          category: NotificationCategory.delivery,
          orderId: widget.order.id,
          orderNumber: widget.order.orderNumber,
        );
      } catch (_) {}

      // 4. Refresh supervisor & client portal data
      ref.read(salesSupervisorProvider.notifier).loadSupervisorData();
      ref.read(clientPortalProvider.notifier).loadClientData();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Order #${widget.order.orderNumber} successfully reassigned to ${target.fullName}!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to reassign order: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = const Color(0xFF94A3B8);

    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    final closers = widget.availableClosers.where((c) {
      if (searchQuery.isEmpty) return true;
      return c.fullName.toLowerCase().contains(searchQuery) ||
          c.closerCode.toLowerCase().contains(searchQuery);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reassign Order to Closer',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '#${widget.order.orderNumber} • ${widget.order.customerName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current Closer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  'Current Closer: ',
                  style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                ),
                Text(
                  widget.order.closerName ?? 'Unassigned',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                if (widget.order.closerCode != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.order.closerCode!,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Select Closer Title
          Text(
            'Select Target Closer in Team (${closers.length}):',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Search Field
          if (widget.availableClosers.length > 5) ...[
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Filter by closer name or code...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Closers List
          Expanded(
            child: ListView.separated(
              itemCount: closers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final closer = closers[index];
                final isSelected = _selectedCloser?.id == closer.id;
                final isCurrent = widget.order.closerId == closer.id;

                return InkWell(
                  onTap: () => setState(() => _selectedCloser = closer),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatarWidget(
                          fullName: closer.fullName,
                          avatarUrl: closer.avatarUrl,
                          radius: 17,
                          backgroundColor: const Color(0xFF8B5CF6),
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      closer.fullName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      closer.closerCode,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                  if (closer.phone != null && closer.phone!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      closer.phone!,
                                      style: GoogleFonts.inter(fontSize: 10, color: textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Reassignment Reason / Notes
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Reassignment Reason / Note (Optional)',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: textMuted),
              hintText: 'e.g. Assigned closer unavailable; customer requested immediate callback...',
              hintStyle: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            style: GoogleFonts.inter(fontSize: 12, color: textPrimary),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _selectedCloser == null || _isSubmitting ? null : _handleReassign,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Reassigning...' : 'Confirm Reassignment',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

