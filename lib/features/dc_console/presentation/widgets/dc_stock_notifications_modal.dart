import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/domain/entities/stock_transfer_record.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/dc_console_provider.dart';
import 'dc_notify_merchant_restock_modal.dart';
import 'dc_unified_inbound_modal.dart';

enum StockAlertCategory {
  all,
  restock,
  courier,
  inbound,
  spoilage,
}

class StockNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final StockAlertCategory category;
  final bool isCritical;
  final bool isRead;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData? actionIcon;

  const StockNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isCritical = false,
    this.isRead = false,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
  });
}

class DCStockNotificationsModal extends ConsumerStatefulWidget {
  final int dcMinThreshold;
  final int riderSafetyThreshold;
  final Map<String, int> productThresholds;
  final Map<String, int> riderProductThresholds;
  final VoidCallback? onOpenAllocate;
  final VoidCallback? onOpenRiderBalance;
  final VoidCallback? onOpenRetrieveStock;

  const DCStockNotificationsModal({
    super.key,
    required this.dcMinThreshold,
    required this.riderSafetyThreshold,
    this.productThresholds = const {},
    this.riderProductThresholds = const {},
    this.onOpenAllocate,
    this.onOpenRiderBalance,
    this.onOpenRetrieveStock,
  });

  static Future<void> show({
    required BuildContext context,
    required int dcMinThreshold,
    required int riderSafetyThreshold,
    Map<String, int> productThresholds = const {},
    Map<String, int> riderProductThresholds = const {},
    VoidCallback? onOpenAllocate,
    VoidCallback? onOpenRiderBalance,
    VoidCallback? onOpenRetrieveStock,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
            child: DCStockNotificationsModal(
              dcMinThreshold: dcMinThreshold,
              riderSafetyThreshold: riderSafetyThreshold,
              productThresholds: productThresholds,
              riderProductThresholds: riderProductThresholds,
              onOpenAllocate: onOpenAllocate,
              onOpenRiderBalance: onOpenRiderBalance,
              onOpenRetrieveStock: onOpenRetrieveStock,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: DCStockNotificationsModal(
            dcMinThreshold: dcMinThreshold,
            riderSafetyThreshold: riderSafetyThreshold,
            productThresholds: productThresholds,
            riderProductThresholds: riderProductThresholds,
            onOpenAllocate: onOpenAllocate,
            onOpenRiderBalance: onOpenRiderBalance,
            onOpenRetrieveStock: onOpenRetrieveStock,
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<DCStockNotificationsModal> createState() => _DCStockNotificationsModalState();
}

class _DCStockNotificationsModalState extends ConsumerState<DCStockNotificationsModal> {
  StockAlertCategory _selectedFilter = StockAlertCategory.all;
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final notifState = ref.watch(notificationsProvider);

    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Build synthesized notifications list
    final List<StockNotificationItem> items = _buildStockNotifications(
      stockState.stockItems,
      stockState.riderAllocations,
      stockState.stockTransfers,
      notifState.notifications,
      dcState.activeHubName,
    );

    // Filter by category and dismissals
    final visibleItems = items.where((it) {
      if (_dismissedIds.contains(it.id)) return false;
      if (_selectedFilter == StockAlertCategory.all) return true;
      return it.category == _selectedFilter;
    }).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Modal Handle Bar
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Notifications',
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Station storage, couriers & replenishment alerts',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _dismissedIds.addAll(items.map((e) => e.id));
                        });
                        ref.read(notificationsProvider.notifier).markAllAsRead();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Clear All',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Category Filter Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(
                      label: 'All (${items.where((i) => !_dismissedIds.contains(i.id)).length})',
                      category: StockAlertCategory.all,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Restock Warnings (${items.where((i) => !_dismissedIds.contains(i.id) && i.category == StockAlertCategory.restock).length})',
                      category: StockAlertCategory.restock,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Couriers (${items.where((i) => !_dismissedIds.contains(i.id) && i.category == StockAlertCategory.courier).length})',
                      category: StockAlertCategory.courier,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Inbounds (${items.where((i) => !_dismissedIds.contains(i.id) && i.category == StockAlertCategory.inbound).length})',
                      category: StockAlertCategory.inbound,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'Returns & Spoilage (${items.where((i) => !_dismissedIds.contains(i.id) && i.category == StockAlertCategory.spoilage).length})',
                      category: StockAlertCategory.spoilage,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Notifications List / Empty State
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 44,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'All Clear! No Active Stock Alerts',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Station inventory levels and courier custody buffers are within safe margins.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return _buildNotificationCard(item, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required StockAlertCategory category,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == category;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = category),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(StockNotificationItem item, bool isDark) {
    Color accentColor;
    IconData categoryIcon;
    String badgeText;

    switch (item.category) {
      case StockAlertCategory.restock:
        accentColor = item.isCritical ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
        categoryIcon = Icons.campaign_rounded;
        badgeText = item.isCritical ? 'CRITICAL RESTOCK' : 'LOW STORAGE';
        break;
      case StockAlertCategory.courier:
        accentColor = const Color(0xFF0284C7);
        categoryIcon = Icons.two_wheeler_rounded;
        badgeText = 'COURIER BUFFER';
        break;
      case StockAlertCategory.inbound:
        accentColor = const Color(0xFF059669);
        categoryIcon = Icons.move_to_inbox_rounded;
        badgeText = 'INBOUND CONSIGNMENT';
        break;
      case StockAlertCategory.spoilage:
        accentColor = const Color(0xFFE11D48);
        categoryIcon = Icons.assignment_return_rounded;
        badgeText = 'RETURNS / SPOILAGE';
        break;
      default:
        accentColor = const Color(0xFF64748B);
        categoryIcon = Icons.info_outline_rounded;
        badgeText = 'STOCK NOTICE';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isCritical
              ? const Color(0xFFDC2626).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: item.isCritical ? 1.5 : 1,
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
          // Top Row: Category Badge + Timestamp + Dismiss Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 12, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM d • h:mm a').format(item.timestamp),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() => _dismissedIds.add(item.id));
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // Title
          Text(
            item.title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),

          // Message
          Text(
            item.message,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              height: 1.35,
            ),
          ),

          // Action Button if configured
          if (item.onAction != null && item.actionLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  item.onAction!();
                },
                icon: Icon(item.actionIcon ?? Icons.arrow_forward_rounded, size: 13),
                label: Text(
                  item.actionLabel!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<StockNotificationItem> _buildStockNotifications(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<StockTransferRecord> transfers,
    List<AppNotificationEntity> remoteNotifications,
    String activeHubName,
  ) {
    final List<StockNotificationItem> list = [];

    // 1. DC Facility Low Stock & Critical Restock Warnings
    for (final item in warehouseItems) {
      final customThreshold = widget.productThresholds[item.id] ?? widget.dcMinThreshold;
      if (item.availableCount <= customThreshold) {
        final isCrit = item.availableCount <= (customThreshold ~/ 2);
        list.add(
          StockNotificationItem(
            id: 'dc_restock_${item.id}',
            title: '${isCrit ? "CRITICAL: " : "Restock Warning: "}${item.name}',
            message: 'Station storage at $activeHubName holds only ${item.availableCount} units (threshold: $customThreshold units). Merchant redistribution takes ~2 weeks lead time.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            category: StockAlertCategory.restock,
            isCritical: isCrit,
            actionLabel: 'Requisition Restock',
            actionIcon: Icons.campaign_rounded,
            onAction: () {
              DCNotifyMerchantRestockModal.show(context, item: item, dcName: activeHubName);
            },
          ),
        );
      }
    }

    // 2. Courier Safety Buffer Alerts
    for (final alloc in allocations) {
      if (alloc.inCustodyUnits > 0) {
        final customKey = '${alloc.riderId}_${alloc.productId}';
        final threshold = widget.riderProductThresholds[customKey] ?? widget.riderSafetyThreshold;
        if (alloc.inCustodyUnits <= threshold) {
          list.add(
            StockNotificationItem(
              id: 'courier_buffer_${alloc.riderId}_${alloc.productId}',
              title: 'Courier Low Stock: ${alloc.riderName}',
              message: '${alloc.riderName} has only ${alloc.inCustodyUnits} units of ${alloc.productName} remaining (safety threshold: $threshold units). Restock from station or balance from peer.',
              timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
              category: StockAlertCategory.courier,
              actionLabel: 'Allocate Stock',
              actionIcon: Icons.person_add_alt_1_rounded,
              onAction: () {
                widget.onOpenAllocate?.call();
              },
            ),
          );
        }
      }
    }

    // 3. Pending Inbounds
    final pendingInbounds = transfers.where((t) => t.isPendingReception).toList();
    for (final inb in pendingInbounds) {
      final pName = inb.items.firstOrNull?.productName ?? 'Stock Items';
      final source = inb.sourceDcName.isNotEmpty ? inb.sourceDcName : (inb.clientName ?? 'Supplier');
      list.add(
        StockNotificationItem(
          id: 'inbound_${inb.id}',
          title: 'Pending Inbound Consignment: #${inb.id.substring(0, inb.id.length > 8 ? 8 : inb.id.length)}',
          message: 'Manifest of ${inb.totalQuantityRequested} units ($pName) arriving from $source. Awaiting reception inspection.',
          timestamp: inb.createdAt,
          category: StockAlertCategory.inbound,
          actionLabel: 'Receive Inbound',
          actionIcon: Icons.move_to_inbox_rounded,
          onAction: () {
            DCUnifiedInboundModal.show(context: context);
          },
        ),
      );
    }

    // 4. Damaged / Spoilage Returns
    final damagedItems = warehouseItems.where((i) => i.damagedCount > 0).toList();
    for (final d in damagedItems) {
      list.add(
        StockNotificationItem(
          id: 'damaged_${d.id}',
          title: 'Damaged Stock Quarantine: ${d.name}',
          message: '${d.damagedCount} units reported damaged or defective by couriers awaiting return reconciliation.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          category: StockAlertCategory.spoilage,
        ),
      );
    }

    // 5. Remote App Notifications filtered for stock
    for (final notif in remoteNotifications) {
      if (notif.category == NotificationCategory.stock) {
        list.add(
          StockNotificationItem(
            id: 'remote_${notif.id}',
            title: notif.title,
            message: notif.message,
            timestamp: notif.createdAt,
            category: StockAlertCategory.restock,
            isRead: notif.isRead,
          ),
        );
      }
    }

    // Sort by critical first, then newest
    list.sort((a, b) {
      if (a.isCritical && !b.isCritical) return -1;
      if (!a.isCritical && b.isCritical) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    return list;
  }
}
