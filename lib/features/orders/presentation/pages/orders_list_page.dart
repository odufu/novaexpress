import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';

class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({super.key});

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? user.firstName : 'Emeka';

    final allOrders = ordersState.orders;

    final assignedCount = allOrders.where((o) => o.status == 'accepted').length;
    final collectedCount = allOrders.where((o) => o.status == 'delivered').length;
    final outForDeliveryCount = allOrders.where((o) => o.status == 'in_transit').length;

    final filteredOrders = allOrders.where((o) {
      if (_selectedFilter == 'Assigned') {
        return o.status == 'accepted';
      } else if (_selectedFilter == 'Collected') {
        return o.status == 'delivered';
      } else if (_selectedFilter == 'Out for Delivery') {
        return o.status == 'in_transit';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leadingWidth: 140,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: AppLogoWidget(
            variant: AppLogoVariant.landscape,
            height: 24,
          ),
        ),
        title: Text(
          'ORDERS',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => ref.read(ordersProvider.notifier).fetchOrders(),
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  agentName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).fetchOrders(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Pills Row matching orders_list/screen.png
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All Orders (${allOrders.length})',
                      isSelected: _selectedFilter == 'All',
                      onTap: () => setState(() => _selectedFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Assigned ($assignedCount)',
                      isSelected: _selectedFilter == 'Assigned',
                      onTap: () => setState(() => _selectedFilter = 'Assigned'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Collected ($collectedCount)',
                      isSelected: _selectedFilter == 'Collected',
                      onTap: () => setState(() => _selectedFilter = 'Collected'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Out for Delivery ($outForDeliveryCount)',
                      isSelected: _selectedFilter == 'Out for Delivery',
                      onTap: () => setState(() => _selectedFilter = 'Out for Delivery'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Skeletal Shimmer Loading vs Filtered Orders List
              if (ordersState.isLoading) ...[
                const OrderCardSkeleton(),
                const OrderCardSkeleton(),
                const OrderCardSkeleton(),
              ] else if (filteredOrders.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No orders found for this filter.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ] else ...[
                Column(
                  children: filteredOrders.map((order) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderListItemCard(order: order),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _OrderListItemCard extends StatelessWidget {
  final OrderEntity order;

  const _OrderListItemCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displayNo = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;

    Color badgeColor;
    IconData statusIcon;
    String statusLabel = order.status.toUpperCase().replaceAll('_', ' ');

    if (order.status == 'delivered') {
      badgeColor = const Color(0xFF00522A);
      statusIcon = Icons.inventory;
      statusLabel = 'COLLECTED';
    } else if (order.status == 'in_transit') {
      badgeColor = AppColors.orange;
      statusIcon = Icons.local_shipping_outlined;
      statusLabel = 'IN TRANSIT';
    } else if (order.status == 'accepted') {
      badgeColor = const Color(0xFF1A2B48);
      statusIcon = Icons.pending_actions_rounded;
      statusLabel = 'ASSIGNED';
    } else {
      badgeColor = const Color(0xFF44474D);
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: #NEX-8821 + Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$displayNo',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer Name
              Text(
                order.customerName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),

              // Address with Icon matching screen.png
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Items breakdown with Icon matching screen.png
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${order.quantity}x Herbal Tonic Package',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.isPod ? 'POD' : 'PREPAID',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Footer Row: Amount to Collect + Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.isPod ? 'Amount to Collect:' : 'Prepaid Amount:',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatNaira(order.totalAmount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                  if (order.status == 'in_transit')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.navigation_outlined, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Start Navigation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (order.status == 'accepted')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Confirm Pickup',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.jetBrainsMono(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
