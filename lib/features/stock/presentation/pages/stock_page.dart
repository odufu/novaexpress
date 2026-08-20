import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
      ref.read(stockProvider.notifier).fetchStockItems(agentId);
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
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final stockNotifier = ref.read(stockProvider.notifier);
    final notifState = ref.watch(notificationsProvider);

    final currentTimeStr = DateFormat('h:mm a').format(DateTime.now());
    final inboundRequests = stockState.inboundRequests.where((r) => r.status != 'Completed').toList();
    final hasAwaitingReturns = stockState.totalAwaitingReturn > 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              ref.read(bottomNavIndexProvider.notifier).state = 0;
            }
          },
        ),
        title: Text(
          'Inventory',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Live Notification Bell with Dynamic Unread Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 26,
                  color: theme.colorScheme.onSurface,
                ),
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Subtle Overflow Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurface,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'reconcile') {
                context.push('/stock/audit');
              } else if (val == 'refresh') {
                stockNotifier.fetchStockItems();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reconcile',
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Text('Stock Audit / Reconciliation'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Text('Sync Inventory Data'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Floating Primary Action: Request Stock
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/stock/request'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Request Stock',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(authProvider).user;
          final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
          await stockNotifier.fetchStockItems(agentId);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtitle
              Text(
                'My assigned stock',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // Search Bar with Barcode Scanner
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => stockNotifier.setSearchQuery(val),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by product name, SKU or barcode',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.crop_free_rounded,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                      tooltip: 'Scan Barcode',
                      onPressed: () {
                        context.push('/orders/scan');
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // INVENTORY SUMMARY (My Stock / What's Available)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'INVENTORY SUMMARY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentTimeStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => stockNotifier.fetchStockItems(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.sync_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4 Metrics Summary Cards
              if (stockState.isLoading)
                const Row(
                  children: [
                    Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 12)),
                  ],
                )
              else
                Row(
                  children: [
                    // Total Stock
                    Expanded(
                      child: _SummaryMetricCard(
                        iconBgColor: const Color(0xFFE0EDFF),
                        iconColor: const Color(0xFF2563EB),
                        icon: Icons.inventory_2_rounded,
                        count: stockState.totalInCustody,
                        title: 'Total Stock',
                        subtitle: 'Assigned to you',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delivered
                    Expanded(
                      child: _SummaryMetricCard(
                        iconBgColor: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF16A34A),
                        icon: Icons.check_rounded,
                        count: stockState.stockItems.fold(0, (acc, i) => acc + i.deliveredCount),
                        title: 'Delivered',
                        subtitle: 'Total delivered',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Available
                    Expanded(
                      child: _SummaryMetricCard(
                        iconBgColor: const Color(0xFFFFEDD5),
                        iconColor: const Color(0xFFEA580C),
                        icon: Icons.all_inbox_rounded,
                        count: stockState.totalAvailable,
                        title: 'Available',
                        subtitle: 'In your possession',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Returned
                    Expanded(
                      child: _SummaryMetricCard(
                        iconBgColor: const Color(0xFFFFE4E6),
                        iconColor: const Color(0xFFE11D48),
                        icon: Icons.reply_rounded,
                        count: stockState.stockItems.fold(0, (acc, i) => acc + i.returnedCount),
                        title: 'Returned',
                        subtitle: 'To hub/other',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${stockState.stockItems.length})',
                      isSelected: stockState.activeFilter == StockFilter.all,
                      onTap: () => stockNotifier.setFilter(StockFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Available (${stockState.availableCountFiltered})',
                      isSelected: stockState.activeFilter == StockFilter.available,
                      onTap: () => stockNotifier.setFilter(StockFilter.available),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Low Stock (${stockState.lowStockCountFiltered})',
                      isSelected: stockState.activeFilter == StockFilter.lowStock,
                      onTap: () => stockNotifier.setFilter(StockFilter.lowStock),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Out of Stock (${stockState.outOfStockCountFiltered})',
                      isSelected: stockState.activeFilter == StockFilter.outOfStock,
                      onTap: () => stockNotifier.setFilter(StockFilter.outOfStock),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CONTEXTUAL BANNER 1: What's Coming (Incoming Stock)
              // Only appears when an inbound request exists!
              if (inboundRequests.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F274A) : const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.move_to_inbox_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Incoming: ${inboundRequests.first.requestId}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'READY',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'From ${inboundRequests.first.dcName}',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.push('/stock/handover/${inboundRequests.first.requestId}'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          minimumSize: const Size(50, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Collect',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // CONTEXTUAL BANNER 2: What's Going Back (Returns)
              // Only appears when items are awaiting return!
              if (hasAwaitingReturns) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF331500) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFEA580C), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stockState.totalAwaitingReturn} items awaiting return to DC',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                            Text(
                              'Failed delivery packages ready for hub drop-off',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/stock/returns'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Process',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // MY PRODUCTS Section Header
              Text(
                'MY PRODUCTS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),

              // Product Items List
              if (stockState.isLoading) ...[
                const AppSkeletonLoader(width: double.infinity, height: 160, borderRadius: 16),
                const SizedBox(height: 12),
                const AppSkeletonLoader(width: double.infinity, height: 160, borderRadius: 16),
              ] else if (stockState.filteredStockItems.isEmpty) ...[
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
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No matching products found',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Column(
                  children: stockState.filteredStockItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ProductInventoryCard(
                        item: item,
                        onViewDetails: () {
                          context.push('/stock/details/${item.name}');
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),

              // CONTEXTUAL BANNER 3: Stock Reconciliation Banner (bottom of list)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F274A) : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.all_inbox_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock Reconciliation',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verify your physical stock and report any differences.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => context.push('/stock/audit'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Reconcile',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final Color iconBgColor;
  final Color iconColor;
  final IconData icon;
  final int count;
  final String title;
  final String subtitle;

  const _SummaryMetricCard({
    required this.iconBgColor,
    required this.iconColor,
    required this.icon,
    required this.count,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          style: GoogleFonts.inter(
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

class _ProductInventoryCard extends StatelessWidget {
  final StockItemEntity item;
  final VoidCallback onViewDetails;

  const _ProductInventoryCard({
    required this.item,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Badge styling based on status
    Color badgeBg;
    Color badgeTextColor;
    Color progressColor;

    switch (item.status) {
      case StockStatus.available:
        badgeBg = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF16A34A);
        progressColor = const Color(0xFF16A34A);
        break;
      case StockStatus.lowStock:
        badgeBg = const Color(0xFFFFEDD5);
        badgeTextColor = const Color(0xFFEA580C);
        progressColor = const Color(0xFFEA580C);
        break;
      case StockStatus.outOfStock:
        badgeBg = const Color(0xFFFFE4E6);
        badgeTextColor = const Color(0xFFE11D48);
        progressColor = const Color(0xFFE11D48);
        break;
    }

    final unitLabel = item.assignedCount == 1 ? 'unit' : 'units';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Thumbnail
                Container(
                  width: 78,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: item.imageAsset != null
                        ? Image.asset(
                            item.imageAsset!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildFallbackProductIcon(),
                          )
                        : _buildFallbackProductIcon(),
                  ),
                ),
                const SizedBox(width: 12),

                // Middle Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // SKU Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SKU: ${item.sku}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Bullet Breakdown per screenshot & PRD
                      _buildBulletRow(const Color(0xFF2563EB), 'Assigned', '${item.assignedCount} ${item.assignedCount == 1 ? "unit" : "units"}', isDark),
                      const SizedBox(height: 3),
                      _buildBulletRow(const Color(0xFF16A34A), 'Delivered', '${item.deliveredCount} ${item.deliveredCount == 1 ? "unit" : "units"}', isDark),
                      const SizedBox(height: 3),
                      _buildBulletRow(const Color(0xFFEA580C), 'Available', '${item.availableCount} ${item.availableCount == 1 ? "unit" : "units"}', isDark),
                      const SizedBox(height: 3),
                      _buildBulletRow(const Color(0xFFE11D48), 'Returned', '${item.returnedCount} ${item.returnedCount == 1 ? "unit" : "units"}', isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Info Column (Stock Level & Status)
                SizedBox(
                  width: 95,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status Badge
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.statusBadgeText,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: badgeTextColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stock Level Label & Chevron
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              'Stock Level',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Percentage Big Text
                      Text(
                        '${item.stockPercentageInt}%',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: badgeTextColor,
                        ),
                      ),
                      const SizedBox(height: 1),

                      // Fraction
                      Text(
                        '${item.availableCount} / ${item.assignedCount} $unitLabel',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: item.stockPercentage,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Action View Details Button
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackProductIcon() {
    return const Center(
      child: Icon(
        Icons.inventory_2_rounded,
        size: 32,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildBulletRow(Color dotColor, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
