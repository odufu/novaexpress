import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/map_launcher_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';

final pdaOrdersSelectedTabProvider = StateProvider.autoDispose<String>((ref) => 'All');
final pdaOrdersSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final pdaOrdersIsSearchVisibleProvider = StateProvider.autoDispose<bool>((ref) => false);
final pdaOrdersFilterPaymentTypeProvider = StateProvider.autoDispose<String>((ref) => 'All');
final pdaOrdersFilterDeliveryTypeProvider = StateProvider.autoDispose<String>((ref) => 'All');
final pdaOrdersFilterClientProvider = StateProvider.autoDispose<String>((ref) => 'All');

class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({super.key});

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final agentId = user?.deliveryAgentId ?? user?.id ?? '';
      ref.read(ordersProvider.notifier).loadOrders(agentId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final notifState = ref.watch(notificationsProvider);
    final user = authState.user;
    final agentName = user?.firstName ?? '';

    final selectedTab = ref.watch(pdaOrdersSelectedTabProvider);
    final searchQuery = ref.watch(pdaOrdersSearchQueryProvider);
    final isSearchVisible = ref.watch(pdaOrdersIsSearchVisibleProvider);
    final filterPaymentType = ref.watch(pdaOrdersFilterPaymentTypeProvider);
    final filterDeliveryType = ref.watch(pdaOrdersFilterDeliveryTypeProvider);
    final filterClient = ref.watch(pdaOrdersFilterClientProvider);

    final allOrders = ordersState.orders;

    // Real-time metrics matching DOCUMENTATION/PDA/delivery and orders.md
    final assignedCount = allOrders.where((o) => o.status == 'assigned' || o.status == 'accepted' || o.status == 'pending').length;
    final inProgressCount = allOrders.where((o) => o.status == 'in_transit' || o.status == 'picked_up').length;
    final deliveredCount = allOrders.where((o) => o.status == 'delivered').length;
    final failedCount = allOrders.where((o) => o.status == 'failed' || o.status == 'call_back' || o.status == 'cancelled').length;
    final returnsCount = allOrders.where((o) => o.status == 'returned' || o.status == 'failed' || o.status == 'call_back').length;

    // Filter Logic matching PRD
    final filteredOrders = allOrders.where((o) {
      // 1. Tab Filter
      if (selectedTab == 'Pending' && (o.status != 'assigned' && o.status != 'accepted' && o.status != 'pending')) return false;
      if (selectedTab == 'In Progress' && (o.status != 'in_transit' && o.status != 'picked_up')) return false;
      if (selectedTab == 'Delivered' && o.status != 'delivered') return false;
      if (selectedTab == 'Failed' && (o.status != 'failed' && o.status != 'call_back' && o.status != 'cancelled')) return false;
      if (selectedTab == 'Returns' && (o.status != 'returned' && o.status != 'failed' && o.status != 'call_back')) return false;

      // 2. Modal Sheet Filters
      if (filterPaymentType == 'POD' && !o.isPod) return false;
      if (filterPaymentType == 'Prepaid' && o.isPod) return false;
      if (filterDeliveryType == 'Distributed Inventory' && !o.isDistributedInventory) return false;
      if (filterDeliveryType == 'Client Package' && !o.isClientPackage) return false;
      if (filterClient != 'All' && !o.clientName.toLowerCase().contains(filterClient.toLowerCase())) return false;

      // 3. Search Query Filter (Order ID, Customer, Phone, Product, Address)
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchId = o.orderNumber.toLowerCase().contains(query);
        final matchCustomer = o.customerName.toLowerCase().contains(query);
        final matchPhone = o.customerPhone.toLowerCase().contains(query);
        final matchProduct = o.productName.toLowerCase().contains(query);
        final matchAddress = o.deliveryAddress.toLowerCase().contains(query);
        if (!matchId && !matchCustomer && !matchPhone && !matchProduct && !matchAddress) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort: Active / Undelivered orders at the top, Delivered orders moved down to bottom
    filteredOrders.sort((a, b) {
      int getStatusPriority(String status) {
        switch (status.toLowerCase()) {
          case 'in_transit':
          case 'picked_up':
            return 0; // Top: Active in progress
          case 'pending':
          case 'assigned':
          case 'accepted':
          case 'new':
            return 1; // Next: Pending dispatch
          case 'call_back':
          case 'contacting':
          case 'upsell_pending':
            return 2; // Next: Call back / Follow-up
          case 'delivered':
            return 3; // Moved down: Delivered (WhatsApp green)
          case 'failed':
          case 'cancelled':
          case 'returned':
            return 4; // Bottom: Failed / Cancelled
          default:
            return 2;
        }
      }

      final pA = getStatusPriority(a.status);
      final pB = getStatusPriority(b.status);
      if (pA != pB) {
        return pA.compareTo(pB);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    final isDark = theme.brightness == Brightness.dark;
    final headerBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: headerBgColor,
        elevation: 0,
        leadingWidth: 44,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogoWidget(
            variant: AppLogoVariant.square,
            height: 26,
          ),
        ),
        title: Text(
          'DELIVERIES',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              final newVisible = !isSearchVisible;
              ref.read(pdaOrdersIsSearchVisibleProvider.notifier).state = newVisible;
              if (!newVisible) {
                _searchController.clear();
                ref.read(pdaOrdersSearchQueryProvider.notifier).state = '';
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: (filterPaymentType != 'All' || filterDeliveryType != 'All' || filterClient != 'All')
                  ? AppColors.orange
                  : Colors.white,
            ),
            onPressed: () => _showFilterModalSheet(context),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (notifState.unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notifState.unreadCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 14, left: 4),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.orange,
                child: Text(
                  agentName.isNotEmpty ? agentName.substring(0, 1).toUpperCase() : 'R',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BRAND DARK BLUE HEADER SECTION
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    // Search Input Bar (when toggled open)
                    if (isSearchVisible) ...[
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (value) => ref.read(pdaOrdersSearchQueryProvider.notifier).state = value,
                        decoration: InputDecoration(
                          hintText: 'Search by ID, Customer, Phone, Product, Address...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white70),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(pdaOrdersSearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF60A5FA)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Delivery Summary Card matching delivery and orders.md
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'DELIVERY SUMMARY TODAY',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${allOrders.length} Total',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF60A5FA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryMetricPill(
                                  label: 'Pending',
                                  count: '$assignedCount',
                                  color: const Color(0xFF60A5FA),
                                  textColor: const Color(0xFF93C5FD),
                                  bgColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SummaryMetricPill(
                                  label: 'In Progress',
                                  count: '$inProgressCount',
                                  color: const Color(0xFFFB923C),
                                  textColor: const Color(0xFFFDBA74),
                                  bgColor: const Color(0xFFEA580C).withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SummaryMetricPill(
                                  label: 'Delivered',
                                  count: '$deliveredCount',
                                  color: const Color(0xFF4ADE80),
                                  textColor: const Color(0xFF86EFAC),
                                  bgColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SummaryMetricPill(
                                  label: 'Failed',
                                  count: '$failedCount',
                                  color: const Color(0xFFF87171),
                                  textColor: const Color(0xFFFCA5A5),
                                  bgColor: const Color(0xFFE11D48).withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. BOTTOM SECTION: Filter Tabs + Orders List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Tabs Horizontal Scroll Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterTabPill(
                            label: 'All (${allOrders.length})',
                            isSelected: selectedTab == 'All',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'All',
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Pending ($assignedCount)',
                            isSelected: selectedTab == 'Pending',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'Pending',
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'In Progress ($inProgressCount)',
                            isSelected: selectedTab == 'In Progress',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'In Progress',
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Delivered ($deliveredCount)',
                            isSelected: selectedTab == 'Delivered',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'Delivered',
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Failed ($failedCount)',
                            isSelected: selectedTab == 'Failed',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'Failed',
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Returns ($returnsCount)',
                            isSelected: selectedTab == 'Returns',
                            onTap: () => ref.read(pdaOrdersSelectedTabProvider.notifier).state = 'Returns',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Orders List View / Shimmer / Empty State
                    if (ordersState.isLoading) ...[
                      const OrderCardSkeleton(),
                      const OrderCardSkeleton(),
                      const OrderCardSkeleton(),
                    ] else if (filteredOrders.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No deliveries match your filter',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try clearing your search query or selecting a different tab.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return _DeliveryOperationalCard(order: order, index: index);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Filter Modal Sheet for advanced filtering
  void _showFilterModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final filterPaymentType = ref.watch(pdaOrdersFilterPaymentTypeProvider);
            final filterDeliveryType = ref.watch(pdaOrdersFilterDeliveryTypeProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Deliveries',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Payment Type Filter
                  const Text('Payment Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['All', 'POD', 'Prepaid'].map((type) {
                      final selected = filterPaymentType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (_) {
                            ref.read(pdaOrdersFilterPaymentTypeProvider.notifier).state = type;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Type Filter
                  const Text('Fulfillment Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'Distributed Inventory', 'Client Package'].map((type) {
                      final selected = filterDeliveryType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) {
                          ref.read(pdaOrdersFilterDeliveryTypeProvider.notifier).state = type;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Reset & Apply Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(pdaOrdersFilterPaymentTypeProvider.notifier).state = 'All';
                            ref.read(pdaOrdersFilterDeliveryTypeProvider.notifier).state = 'All';
                            ref.read(pdaOrdersFilterClientProvider.notifier).state = 'All';
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryMetricPill extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  final Color? textColor;
  final Color? bgColor;

  const _SummaryMetricPill({
    required this.label,
    required this.count,
    required this.color,
    this.textColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor ?? color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterTabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DeliveryOperationalCard extends ConsumerWidget {
  final OrderEntity order;
  final int index;

  const _DeliveryOperationalCard({
    required this.order,
    required this.index,
  });

  void _callCustomer(BuildContext context, String phone) {
    MapLauncherHelper.launchPhoneCall(context: context, phoneNumber: phone);
  }

  void _openWhatsAppPrompt(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final riderName = user != null && (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
        ? '${user.firstName} ${user.lastName}'.trim()
        : (user?.fullName.isNotEmpty == true ? user!.fullName : 'Dispatch Rider');

    final message = order.getWhatsAppLocationRequestText(riderName: riderName);
    final fallbackUri = order.getWhatsAppLocationRequestUri(riderName: riderName);
    MapLauncherHelper.launchWhatsApp(
      context: context,
      customerPhone: order.customerPhone,
      message: message,
      fallbackUri: fallbackUri,
    );
  }

  void _openMap(BuildContext context) {
    final fullDest = '${order.deliveryAddress}, ${order.deliveryCity}, ${order.deliveryState}';
    MapLauncherHelper.launchTurnByTurnNavigation(
      context: context,
      latitude: order.latitude,
      longitude: order.longitude,
      destinationAddress: fullDest,
      customerName: order.customerName,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isDelivered = order.status == 'delivered';
    final isFailed = order.status == 'failed' || order.status == 'cancelled';

    // Status-specific Left Accent Border Color
    Color statusLeftColor;
    Color statusBg;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (order.status) {
      case 'delivered':
        statusLeftColor = const Color(0xFF10B981); // WhatsApp Emerald
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'DELIVERED';
        statusIcon = Icons.done_all_rounded; // WhatsApp double check
        break;
      case 'in_transit':
        statusLeftColor = const Color(0xFF2563EB); // Electric Blue
        statusBg = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusLabel = 'IN PROGRESS';
        statusIcon = Icons.directions_bike_rounded;
        break;
      case 'failed':
        statusLeftColor = const Color(0xFFEF4444); // Crimson
        statusBg = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFB91C1C);
        statusLabel = 'FAILED';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'call_back':
        statusLeftColor = const Color(0xFF8B5CF6); // Purple
        statusBg = const Color(0xFFEDE9FE);
        statusTextColor = const Color(0xFF6D28D9);
        statusLabel = 'CALL BACK';
        statusIcon = Icons.phone_callback_rounded;
        break;
      case 'accepted':
      case 'pending':
      default:
        statusLeftColor = AppColors.orange; // Amber Orange
        statusBg = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFB45309);
        statusLabel = 'PENDING';
        statusIcon = Icons.schedule_rounded;
        break;
    }

    // Location Confidence Badge styling
    Color confBg;
    Color confTextColor;
    String confShortLabel;
    if (order.isLocationVerified) {
      confBg = const Color(0xFFDCFCE7);
      confTextColor = const Color(0xFF15803D);
      confShortLabel = 'GATE PIN 🛡️';
    } else if (order.locationConfidence == 'high') {
      confBg = const Color(0xFFDCFCE7);
      confTextColor = const Color(0xFF15803D);
      confShortLabel = 'GPS PIN 📍';
    } else if (order.locationConfidence == 'medium') {
      confBg = const Color(0xFFFEF3C7);
      confTextColor = const Color(0xFFD97706);
      confShortLabel = 'LANDMARK 🧭';
    } else {
      confBg = const Color(0xFFFEE2E2);
      confTextColor = const Color(0xFFB91C1C);
      confShortLabel = 'NEED PIN ❓';
    }

    // Card background tint & border styling (WhatsApp read green for delivered)
    final cardBgColor = isDelivered
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.22) : const Color(0xFFF0FDF4))
        : (isFailed
            ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.15) : const Color(0xFFFEF2F2))
            : theme.cardColor);

    final cardBorder = isDelivered
        ? Border.all(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFF86EFAC).withValues(alpha: 0.7), width: 1.2)
        : (isFailed
            ? Border.all(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.3) : const Color(0xFFFECACA))
            : Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
            color: isDelivered
                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.1 : 0.06)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Dynamic Status-Coded Left Accent Border Bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4.5,
                color: statusLeftColor,
              ),
            ),

            // Main Card Content
            InkWell(
              onTap: () => context.push('/orders/${order.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Customer Name, Status Badge, Location Confidence, and Product
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Customer Name + Status Badge + Confidence Pill
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              Text(
                                order.customerName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon, size: isDelivered ? 13 : 11, color: statusTextColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      statusLabel,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: statusTextColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: confBg,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  confShortLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: confTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Address Info
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Product Info
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  order.freeQuantity > 0
                                      ? '${order.productName} x ${order.totalPhysicalQuantity}'
                                      : '${order.productName} x ${order.quantity}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Action Buttons: WhatsApp Prompt & Call & Map
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp Live Pin Request
                        if (order.customerPhone.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _openWhatsAppPrompt(context, ref),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ),

                        // Map Directions Shortcut
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _openMap(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(
                                Icons.directions_rounded,
                                size: 15,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),

                        // Call Button
                        if (order.customerPhone.isNotEmpty)
                          Material(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(8),
                            elevation: 0.5,
                            child: InkWell(
                              onTap: () => _callCustomer(context, order.customerPhone),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Call',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

