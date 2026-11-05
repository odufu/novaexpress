import '../../../../core/services/web_notification_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/widgets/notification_sound_settings_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/presentation/widgets/client_confirm_order_modal.dart';
import '../../../dc_console/presentation/widgets/dc_assign_order_modal.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';
import 'reschedule_callback_modal.dart';

/// Active Floating Follow-up Reminder Banner
/// Surfaces prominently in Rider, DC Dispatch Ops, and Closer consoles
/// when a scheduled order follow-up is due.
class ActiveFollowUpReminderBanner extends ConsumerStatefulWidget {
  final String role; // 'rider', 'dc_operations', or 'closer'
  final String? dcId;
  final String? agentId;
  final String? closerId;
  final VoidCallback? onViewAllRescheduled;

  const ActiveFollowUpReminderBanner({
    super.key,
    required this.role,
    this.dcId,
    this.agentId,
    this.closerId,
    this.onViewAllRescheduled,
  });

  @override
  ConsumerState<ActiveFollowUpReminderBanner> createState() =>
      _ActiveFollowUpReminderBannerState();
}

class _ActiveFollowUpReminderBannerState
    extends ConsumerState<ActiveFollowUpReminderBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _tickerTimer;
  int _currentIndex = 0;
  DateTime? _lastAlertSoundTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Periodic 30s ticker to re-evaluate real-time due status and update labels
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    // Request web notification permissions for background reminders
    WebNotificationService.instance.requestPermission();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _checkAndPlaySound(List<OrderEntity> dueOrders) {
    if (dueOrders.isEmpty) return;
    final now = DateTime.now();
    if (_lastAlertSoundTime == null ||
        now.difference(_lastAlertSoundTime!).inSeconds >= 45) {
      _lastAlertSoundTime = now;
      AudioService().playFollowUpReminderChime();
      final first = dueOrders.first;
      WebNotificationService.instance.showNotification(
        title: '⏰ Follow-up Due: #${first.orderNumber}',
        body: 'Customer ${first.customerName} (${first.customerPhone}) is scheduled for follow-up right now.',
        tag: 'order-${first.id}',
      );
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSnoozeMenu(BuildContext context, OrderEntity order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.snooze_rounded, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Text(
                  'Snooze Follow-up Alert',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.music_note_rounded, size: 20, color: Color(0xFFEA580C)),
                  tooltip: 'Change Ringing Chime',
                  onPressed: () {
                    Navigator.pop(ctx);
                    NotificationSoundSettingsModal.show(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Order #${order.orderNumber} • ${order.customerName}',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSnoozeChip(ctx, order, '5 mins', const Duration(minutes: 5)),
                _buildSnoozeChip(ctx, order, '15 mins', const Duration(minutes: 15)),
                _buildSnoozeChip(ctx, order, '30 mins', const Duration(minutes: 30)),
                _buildSnoozeChip(ctx, order, '1 hour', const Duration(hours: 1)),
                _buildSnoozeChip(ctx, order, 'Tomorrow 9am', _calcTomorrowMorning()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Duration _calcTomorrowMorning() {
    final now = DateTime.now();
    final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);
    return tomorrow9am.difference(now);
  }

  Widget _buildSnoozeChip(
    BuildContext ctx,
    OrderEntity order,
    String label,
    Duration duration,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFEA580C)),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.08),
      side: const BorderSide(color: Color(0xFFEA580C)),
      onPressed: () async {
        Navigator.pop(ctx);
        await ref
            .read(ordersProvider.notifier)
            .snoozeOrderReminder(order.id, duration);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEA580C),
              content: Text(
                'Reminder for #${order.orderNumber} snoozed by $label.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final ordersState = ref.watch(ordersProvider);

    // Filter due orders matching this specific console role
    final dueOrders = ordersState.orders.where((o) {
      if (o.isDelivered || o.isCancelled) return false;
      if (!o.isFollowUpReminderDue) return false;

      final currentUserId = authUser?.id ?? '';

      // Account & Role Isolation: Reschedules set by one role/account are ONLY visible to that account!
      if (widget.role == 'rider') {
        if (o.rescheduledByRole != null && o.rescheduledByRole != 'rider') return false;
        final currentRiderId = widget.agentId ?? authUser?.deliveryAgentId ?? currentUserId;
        final matchesUser = (o.rescheduledByUserId != null && o.rescheduledByUserId == currentUserId) ||
            (o.deliveryAgentId != null && o.deliveryAgentId == currentRiderId);
        return matchesUser;
      } else if (widget.role == 'dc_operations') {
        if (o.rescheduledByRole != null && o.rescheduledByRole != 'dc_operations') return false;
        final matchesUser = (o.rescheduledByUserId != null && o.rescheduledByUserId == currentUserId) ||
            (o.logisticsRepId != null && o.logisticsRepId == currentUserId);
        return matchesUser;
      } else if (widget.role == 'closer') {
        if (o.rescheduledByRole != null && o.rescheduledByRole != 'closer') return false;
        final currentCloserId = widget.closerId ?? authUser?.closerId ?? currentUserId;
        final matchesUser = (o.rescheduledByUserId != null && o.rescheduledByUserId == currentUserId) ||
            (o.closerId != null && o.closerId == currentCloserId);
        return matchesUser;
      }
      return true;
    }).toList();

    if (dueOrders.isEmpty) return const SizedBox.shrink();

    // Trigger audible chime once per active interval
    _checkAndPlaySound(dueOrders);

    if (_currentIndex >= dueOrders.length) {
      _currentIndex = 0;
    }
    final activeOrder = dueOrders[_currentIndex];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF271B11) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF97316),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Ringing Bell Alert + Due Status + Multi-Order Indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FOLLOW-UP DUE NOW',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                  ),
                  child: Text(
                    activeOrder.followUpTimingLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                if (dueOrders.length > 1) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${_currentIndex + 1}/${dueOrders.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _currentIndex = (_currentIndex + 1) % dueOrders.length;
                      });
                    },
                  ),
                ],
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => NotificationSoundSettingsModal.show(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 12, color: Color(0xFFEA580C)),
                        SizedBox(width: 3),
                        Text(
                          'Sound',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle: Customer Name, Phone, and Product
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeOrder.customerName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${activeOrder.orderNumber} • ${activeOrder.productName} • ${activeOrder.deliveryCity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Action Buttons: Call, Snooze, Update Next Status, View All
            Row(
              children: [
                // 1. Call Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _makeCall(activeOrder.customerPhone),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                  label: const Text(
                    'Call',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Snooze Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFEA580C)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showSnoozeMenu(context, activeOrder),
                  icon: const Icon(Icons.snooze_rounded, size: 14),
                  label: const Text(
                    'Snooze',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Update Status Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      FollowUpStatusDialog.show(
                        context: context,
                        ref: ref,
                        order: activeOrder,
                        role: widget.role,
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                    label: const Text(
                      'Decide Status',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Follow-up Decision Dialog allowing Closer, DC Ops, or Rider to decide the next status
class FollowUpStatusDialog {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required OrderEntity order,
    required String role, // 'closer', 'dc_operations', 'rider'
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FollowUpStatusSheet(
        order: order,
        role: role,
      ),
    );
  }
}

class _FollowUpStatusSheet extends ConsumerWidget {
  final OrderEntity order;
  final String role;

  const _FollowUpStatusSheet({
    required this.order,
    required this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.offline_bolt_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Text(
                'Decide Next Pipeline Status',
                style: GoogleFonts.inter(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Order #${order.orderNumber} • ${order.customerName}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 18),

          // Role-specific action tiles
          if (role == 'closer') ...[
            _buildActionTile(
              context,
              ref,
              title: 'Confirm Ready (Customer Ready)',
              subtitle: 'Assign handling DC & place order in DC intake queue',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16A34A),
              onTap: () {
                Navigator.pop(context);
                ClientConfirmOrderModal.show(context, order);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Not Picking (No Response)',
              subtitle: 'Customer did not pick call. Mark as not picking',
              icon: Icons.phone_missed_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'not_picking',
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[CALL RESULT] Customer not picking during follow-up.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Reschedule Again',
              subtitle: 'Customer requested a different date or time',
              icon: Icons.event_repeat_rounded,
              color: const Color(0xFFEA580C),
              onTap: () {
                Navigator.pop(context);
                RescheduleCallbackModal.show(
                  context: context,
                  orderId: order.id,
                  customerName: order.customerName,
                  onRescheduleConfirmed: (dt, note) async {
                    final auth = ref.read(authProvider).user;
                    final updated = order.copyWith(
                      status: 'rescheduled',
                                            rescheduledDeliveryDate: dt,
                      rescheduledByUserId: auth?.id,
                      rescheduledByRole: 'closer',
                      clearReminderSnooze: true,
                      deliveryNotes: '${order.deliveryNotes ?? ""}\n[CLOSER RESCHEDULED] $note',
                    );
                    await ref.read(ordersProvider.notifier).updateOrder(updated);
                  },
                );
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Call Back Later',
              subtitle: 'Needs another call attempt',
              icon: Icons.phone_callback_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'call_back',
                  assignedAt: DateTime.now(),
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[CALL BACK] Flagged for follow-up call.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Cancel Order',
              subtitle: 'Customer rejected or cancelled deal',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'cancelled',
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[CANCELLED] Customer cancelled during follow-up.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
          ] else if (role == 'dc_operations') ...[
            _buildActionTile(
              context,
              ref,
              title: 'Dispatch to Rider',
              subtitle: 'Customer confirmed readiness. Assign available DC rider',
              icon: Icons.two_wheeler_rounded,
              color: const Color(0xFF16A34A),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => DCAssignOrderModal(order: order),
                );
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Not Picking',
              subtitle: 'Customer not answering DC dispatch verification',
              icon: Icons.phone_missed_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'not_picking',
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[DC OPS] Customer not answering dispatch check.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Reschedule Delivery',
              subtitle: 'Pick another delivery window',
              icon: Icons.event_repeat_rounded,
              color: const Color(0xFFEA580C),
              onTap: () {
                Navigator.pop(context);
                RescheduleCallbackModal.show(
                  context: context,
                  orderId: order.id,
                  customerName: order.customerName,
                  onRescheduleConfirmed: (dt, note) async {
                    final auth = ref.read(authProvider).user;
                    final updated = order.copyWith(
                      status: 'rescheduled',
                                            rescheduledDeliveryDate: dt,
                      rescheduledByUserId: auth?.id,
                      rescheduledByRole: 'dc_operations',
                      clearReminderSnooze: true,
                      deliveryNotes: '${order.deliveryNotes ?? ""}\n[DISPATCH OPS RESCHEDULED] $note',
                    );
                    await ref.read(ordersProvider.notifier).updateOrder(updated);
                  },
                );
              },
            ),
          ] else if (role == 'rider') ...[
            _buildActionTile(
              context,
              ref,
              title: 'Start Delivery Trip',
              subtitle: 'Customer confirmed readiness. Begin transit trip',
              icon: Icons.directions_bike_rounded,
              color: const Color(0xFF16A34A),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'in_transit',
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[RIDER] Transit trip started after rescheduled window.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Not Picking',
              subtitle: 'Customer did not pick rider phone call',
              icon: Icons.phone_missed_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () async {
                Navigator.pop(context);
                final updated = order.copyWith(
                  status: 'not_picking',
                  deliveryNotes: '${order.deliveryNotes ?? ""}\n[RIDER] Customer not answering delivery call.',
                );
                await ref.read(ordersProvider.notifier).updateOrder(updated);
              },
            ),
            _buildActionTile(
              context,
              ref,
              title: 'Reschedule Again',
              subtitle: 'Customer asked rider to deliver at another date',
              icon: Icons.event_repeat_rounded,
              color: const Color(0xFFEA580C),
              onTap: () {
                Navigator.pop(context);
                RescheduleCallbackModal.show(
                  context: context,
                  orderId: order.id,
                  customerName: order.customerName,
                  onRescheduleConfirmed: (dt, note) async {
                    final auth = ref.read(authProvider).user;
                    final updated = order.copyWith(
                      status: 'rescheduled',
                                            rescheduledDeliveryDate: dt,
                      rescheduledByUserId: auth?.id,
                      rescheduledByRole: 'rider',
                      clearReminderSnooze: true,
                      deliveryNotes: '${order.deliveryNotes ?? ""}\n[RIDER RESCHEDULED] $note',
                    );
                    await ref.read(ordersProvider.notifier).updateOrder(updated);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
      ),
    );
  }
}

