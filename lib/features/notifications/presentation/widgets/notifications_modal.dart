import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../client_portal/presentation/providers/client_portal_provider.dart';
import '../../../client_portal/presentation/providers/sales_supervisor_provider.dart';
import '../../../client_portal/presentation/widgets/client_order_tracking_modal.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsModal extends ConsumerStatefulWidget {
  const NotificationsModal({super.key});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationsModal(),
    );
  }

  @override
  ConsumerState<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends ConsumerState<NotificationsModal> {
  String _selectedCategory = 'all';

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  void _handleNotificationTap(BuildContext context, AppNotificationEntity notif) {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);

    final orderId = notif.metadata?['order_id'] ??
        (notif.actionRoute != null && notif.actionRoute!.startsWith('order:')
            ? notif.actionRoute!.substring(6)
            : null);
    final orderNumber = notif.metadata?['order_number'] ??
        (notif.actionRoute != null && notif.actionRoute!.startsWith('orderNumber:')
            ? notif.actionRoute!.substring(12)
            : null);

    if (orderId != null || orderNumber != null) {
      final orders = <OrderEntity>[];
      try {
        orders.addAll(ref.read(ordersProvider).orders);
      } catch (_) {}
      try {
        orders.addAll(ref.read(salesSupervisorProvider).orders);
      } catch (_) {}
      try {
        orders.addAll(ref.read(clientPortalProvider).orders);
      } catch (_) {}

      final matchedOrder = orders.where((o) =>
          (orderId != null && o.id == orderId) ||
          (orderNumber != null && o.orderNumber == orderNumber)).firstOrNull;

      if (matchedOrder != null) {
        Navigator.of(context).pop();
        ClientOrderTrackingModal.show(context, matchedOrder);
        return;
      } else {
        final fallbackOrder = OrderEntity(
          id: orderId ?? 'ord_${DateTime.now().millisecondsSinceEpoch}',
          orderNumber: orderNumber ?? (orderId ?? 'ORD'),
          customerName: notif.metadata?['customer_name'] ?? 'Customer',
          customerPhone: notif.metadata?['customer_phone'] ?? '',
          deliveryAddress: notif.metadata?['delivery_address'] ?? 'Customer Delivery Address',
          deliveryCity: notif.metadata?['delivery_city'] ?? 'City',
          deliveryState: notif.metadata?['delivery_state'] ?? 'State',
          productName: notif.metadata?['product_name'] ?? 'Product',
          quantity: 1,
          basePrice: 0.0,
          upsellAmount: 0.0,
          totalAmount: 0.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          status: 'booked',
          createdAt: notif.createdAt,
        );
        Navigator.of(context).pop();
        ClientOrderTrackingModal.show(context, fallbackOrder);
        return;
      }
    }

    // Default: Show notification details alert
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(notif.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(notif.message, style: GoogleFonts.inter(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationsState = ref.watch(notificationsProvider);
    final allNotifications = notificationsState.notifications;
    final unreadCount = notificationsState.unreadCount;

    final filtered = _selectedCategory == 'all'
        ? allNotifications
        : allNotifications.where((n) {
            switch (_selectedCategory) {
              case 'delivery':
                return n.category == NotificationCategory.delivery;
              case 'finance':
                return n.category == NotificationCategory.finance;
              case 'stock':
                return n.category == NotificationCategory.stock;
              default:
                return n.category == NotificationCategory.system;
            }
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFFF37021)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Notifications & Alerts',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount new',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Live operational updates for orders, chats & assignments',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Text(
                      'Mark read',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Category Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All (${allNotifications.length})', 'all', isDark),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Orders (${allNotifications.where((n) => n.category == NotificationCategory.delivery).length})',
                  'delivery',
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Finance (${allNotifications.where((n) => n.category == NotificationCategory.finance).length})',
                  'finance',
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Stock (${allNotifications.where((n) => n.category == NotificationCategory.stock).length})',
                  'stock',
                  isDark,
                ),
              ],
            ),
          ),
          const Divider(height: 12),

          // Notifications List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications here',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You will be notified whenever order statuses change or actions require attention.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return _buildNotificationTile(context, notif, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, AppNotificationEntity notif, bool isDark) {
    Color iconBg;
    Color iconColor;
    IconData iconData;

    switch (notif.category) {
      case NotificationCategory.delivery:
        iconBg = const Color(0xFF10B981).withValues(alpha: 0.12);
        iconColor = const Color(0xFF10B981);
        iconData = Icons.local_shipping_rounded;
        break;
      case NotificationCategory.finance:
        iconBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.account_balance_wallet_rounded;
        break;
      case NotificationCategory.stock:
        iconBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.inventory_2_rounded;
        break;
      default:
        iconBg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        iconColor = const Color(0xFF8B5CF6);
        iconData = Icons.info_outline_rounded;
    }

    final isOrderRelated = notif.category == NotificationCategory.delivery ||
        notif.metadata?['order_id'] != null ||
        notif.metadata?['order_number'] != null ||
        (notif.actionRoute != null && notif.actionRoute!.contains('order'));

    return InkWell(
      onTap: () => _handleNotificationTap(context, notif),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? (notif.isRead ? const Color(0xFF1E293B) : const Color(0xFF26334D))
              : (notif.isRead ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                : const Color(0xFF10B981).withValues(alpha: 0.4),
            width: notif.isRead ? 0.8 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimeAgo(notif.createdAt),
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  if (isOrderRelated) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 11, color: Color(0xFF10B981)),
                              const SizedBox(width: 3),
                              Text(
                                'Tap to open Order Tracking',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 6),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF37021),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
