import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/stock_provider.dart';

final stockHistoryFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

class StockHistoryPage extends ConsumerWidget {
  const StockHistoryPage({super.key});

  static const List<String> _filters = [
    'All',
    'Received',
    'Delivered',
    'Returned',
    'Damaged',
    'Adjusted',
  ];

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hrs ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final ordersState = ref.watch(ordersProvider);
    final selectedFilter = ref.watch(stockHistoryFilterProvider);

    final List<Map<String, dynamic>> movements = [];

    // 1. Inbound stock transfers and receptions
    for (final transfer in stockState.stockTransfers) {
      final isCompletedOrDispatched = transfer.isCompleted || transfer.isDispatched || transfer.isPendingReception;
      final sourceName = transfer.sourceWarehouseName?.isNotEmpty == true
          ? transfer.sourceWarehouseName!
          : (transfer.clientName?.isNotEmpty == true ? transfer.clientName! : 'Central DC');
      final destName = transfer.destinationWarehouseName?.isNotEmpty == true
          ? transfer.destinationWarehouseName!
          : 'Distribution Hub';

      for (final item in transfer.items) {
        if (item.quantityReceived > 0 || isCompletedOrDispatched) {
          movements.add({
            'type': 'RECEIVED',
            'category': 'Received',
            'productName': item.productName.isNotEmpty ? item.productName : item.sku,
            'quantityText': '+${item.quantityReceived > 0 ? item.quantityReceived : item.quantity} Units',
            'isPositive': true,
            'source': '$sourceName → $destName',
            'reference': transfer.transferNumber,
            'timestamp': _formatRelative(transfer.createdAt),
            'badgeColor': const Color(0xFF16A34A),
            'icon': Icons.move_to_inbox_rounded,
          });
        }
        if (item.quantityDamaged > 0) {
          movements.add({
            'type': 'DAMAGED',
            'category': 'Damaged',
            'productName': item.productName.isNotEmpty ? item.productName : item.sku,
            'quantityText': '-${item.quantityDamaged} Units',
            'isPositive': false,
            'source': 'Damaged during transfer to $destName',
            'reference': transfer.transferNumber,
            'timestamp': _formatRelative(transfer.createdAt),
            'badgeColor': const Color(0xFFDC2626),
            'icon': Icons.broken_image_rounded,
          });
        }
      }
    }

    // 2. Customer deliveries and returns from live orders
    for (final order in ordersState.orders) {
      final pName = order.productName.isNotEmpty ? order.productName : (order.productSku ?? 'Product Item');
      final statusLower = order.status.toLowerCase();

      if (statusLower == 'delivered') {
        movements.add({
          'type': 'DELIVERED',
          'category': 'Delivered',
          'productName': pName,
          'quantityText': '-1 Unit',
          'isPositive': false,
          'source': 'Order ${order.orderNumber} • ${order.customerName}',
          'reference': order.orderNumber,
          'timestamp': order.updatedAt != null ? _formatRelative(order.updatedAt!) : 'Delivered',
          'badgeColor': const Color(0xFFE11D48),
          'icon': Icons.local_shipping_rounded,
        });
      } else if (statusLower == 'cancelled' || statusLower == 'returned') {
        movements.add({
          'type': 'RETURNED',
          'category': 'Returned',
          'productName': pName,
          'quantityText': '+1 Unit',
          'isPositive': true,
          'source': 'Order ${order.orderNumber} • ${order.customerName}',
          'reference': order.orderNumber,
          'timestamp': order.updatedAt != null ? _formatRelative(order.updatedAt!) : 'Returned',
          'badgeColor': const Color(0xFFEA580C),
          'icon': Icons.replay_rounded,
        });
      }
    }

    // 3. Dynamic fallback from live catalog stock items
    if (movements.isEmpty && stockState.stockItems.isNotEmpty) {
      for (final item in stockState.stockItems) {
        if (item.assignedCount > 0) {
          movements.add({
            'type': 'RECEIVED',
            'category': 'Received',
            'productName': item.name,
            'quantityText': '+${item.assignedCount} Units',
            'isPositive': true,
            'source': '${item.ownerName.isNotEmpty ? item.ownerName : "DC"} Inbound Allocation',
            'reference': 'ALLOC-${item.sku}',
            'timestamp': 'Initial Allocation',
            'badgeColor': const Color(0xFF16A34A),
            'icon': Icons.move_to_inbox_rounded,
          });
        }
        if (item.deliveredCount > 0) {
          movements.add({
            'type': 'DELIVERED',
            'category': 'Delivered',
            'productName': item.name,
            'quantityText': '-${item.deliveredCount} Units',
            'isPositive': false,
            'source': 'Customer Fulfillment',
            'reference': 'DISP-${item.sku}',
            'timestamp': 'Completed Dispatch',
            'badgeColor': const Color(0xFFE11D48),
            'icon': Icons.local_shipping_rounded,
          });
        }
        if (item.returnedCount > 0) {
          movements.add({
            'type': 'RETURNED',
            'category': 'Returned',
            'productName': item.name,
            'quantityText': '+${item.returnedCount} Units',
            'isPositive': true,
            'source': 'DC Depot Return',
            'reference': 'RET-${item.sku}',
            'timestamp': 'Reversed Inventory',
            'badgeColor': const Color(0xFFEA580C),
            'icon': Icons.replay_rounded,
          });
        }
      }
    }

    final filteredMovements = movements.where((m) {
      if (selectedFilter == 'All') return true;
      return (m['category'] as String).toLowerCase() == selectedFilter.toLowerCase();
    }).toList();

    final totalReceived = movements.where((m) => m['category'] == 'Received').length;
    final totalDelivered = movements.where((m) => m['category'] == 'Delivered').length;
    final totalReturned = movements.where((m) => m['category'] == 'Returned').length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Stock Movement History'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(stockProvider.notifier).fetchStockItems();
          await ref.read(ordersProvider.notifier).fetchOrders();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // KPI Overview Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Received',
                      count: totalReceived.toString(),
                      color: const Color(0xFF16A34A),
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Delivered',
                      count: totalDelivered.toString(),
                      color: const Color(0xFFE11D48),
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                  Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Returned',
                      count: totalReturned.toString(),
                      color: const Color(0xFFEA580C),
                      icon: Icons.replay_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (val) {
                        if (val) {
                          ref.read(stockHistoryFilterProvider.notifier).state = filter;
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Movements Header
            Text(
              'Stock Movement Audit Log',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Audit trail of inventory receipts, customer deliveries, DC returns, and adjustments.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Movement Audit Cards
            if (stockState.isLoading) ...[
              const AppSkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
              const SizedBox(height: 12),
              const AppSkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
            ] else if (filteredMovements.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Text(
                    'No movements recorded for "$selectedFilter"',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                ),
              ),
            ] else ...[
              ...filteredMovements.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (m['badgeColor'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m['icon'] as IconData, color: m['badgeColor'] as Color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m['type'] as String,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: m['badgeColor'] as Color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    m['timestamp'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['productName'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['source'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          m['quantityText'] as String,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: (m['isPositive'] as bool) ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
