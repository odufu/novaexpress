import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String _selectedTab = 'All';
  String _searchQuery = '';
  bool _isSearchVisible = false;

  // Filter BottomSheet States
  String _filterPaymentType = 'All'; // All, POD, Prepaid
  String _filterDeliveryType = 'All'; // All, Distributed Inventory, Client Package
  String _filterClient = 'All'; // All, Novacare, Other
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
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
    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? user.firstName : 'Emeka';

    final allOrders = ordersState.orders;

    // Real-time metrics matching DOCUMENTATION/PDA/delivery and orders.md
    final assignedCount = allOrders.where((o) => o.status == 'accepted' || o.status == 'pending').length;
    final inProgressCount = allOrders.where((o) => o.status == 'in_transit').length;
    final deliveredCount = allOrders.where((o) => o.status == 'delivered').length;
    final failedCount = allOrders.where((o) => o.status == 'failed' || o.status == 'call_back').length;
    final returnsCount = allOrders.where((o) => o.status == 'failed' || o.status == 'call_back').length;

    // Filter Logic matching PRD
    final filteredOrders = allOrders.where((o) {
      // 1. Tab Filter
      if (_selectedTab == 'Pending' && (o.status != 'accepted' && o.status != 'pending')) return false;
      if (_selectedTab == 'In Progress' && o.status != 'in_transit') return false;
      if (_selectedTab == 'Delivered' && o.status != 'delivered') return false;
      if (_selectedTab == 'Failed' && (o.status != 'failed' && o.status != 'call_back')) return false;
      if (_selectedTab == 'Returns' && (o.status != 'failed' && o.status != 'call_back')) return false;

      // 2. Modal Sheet Filters
      if (_filterPaymentType == 'POD' && !o.isPod) return false;
      if (_filterPaymentType == 'Prepaid' && o.isPod) return false;
      if (_filterDeliveryType == 'Distributed Inventory' && !o.isDistributedInventory) return false;
      if (_filterDeliveryType == 'Client Package' && !o.isClientPackage) return false;
      if (_filterClient != 'All' && !o.clientName.toLowerCase().contains(_filterClient.toLowerCase())) return false;

      // 3. Search Query Filter (Order ID, Customer, Phone, Product, Address)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
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
              _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: (_filterPaymentType != 'All' || _filterDeliveryType != 'All' || _filterClient != 'All')
                  ? AppColors.orange
                  : Colors.white,
            ),
            onPressed: () => _showFilterModalSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(ordersProvider.notifier).fetchOrders(),
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 14, left: 4),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.orange,
                child: Text(
                  agentName.substring(0, 1).toUpperCase(),
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
                    if (_isSearchVisible) ...[
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search by ID, Customer, Phone, Product, Address...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white70),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
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
                              Text(
                                'DELIVERY SUMMARY TODAY',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
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
                            isSelected: _selectedTab == 'All',
                            onTap: () => setState(() => _selectedTab = 'All'),
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Pending ($assignedCount)',
                            isSelected: _selectedTab == 'Pending',
                            onTap: () => setState(() => _selectedTab = 'Pending'),
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'In Progress ($inProgressCount)',
                            isSelected: _selectedTab == 'In Progress',
                            onTap: () => setState(() => _selectedTab = 'In Progress'),
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Delivered ($deliveredCount)',
                            isSelected: _selectedTab == 'Delivered',
                            onTap: () => setState(() => _selectedTab = 'Delivered'),
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Failed ($failedCount)',
                            isSelected: _selectedTab == 'Failed',
                            onTap: () => setState(() => _selectedTab = 'Failed'),
                          ),
                          const SizedBox(width: 8),
                          _FilterTabPill(
                            label: 'Returns ($returnsCount)',
                            isSelected: _selectedTab == 'Returns',
                            onTap: () => setState(() => _selectedTab = 'Returns'),
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
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      final selected = _filterPaymentType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() => _filterPaymentType = type);
                            setState(() {});
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
                      final selected = _filterDeliveryType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() => _filterDeliveryType = type);
                          setState(() {});
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
                            setModalState(() {
                              _filterPaymentType = 'All';
                              _filterDeliveryType = 'All';
                              _filterClient = 'All';
                            });
                            setState(() {});
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

  void _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(' ', '').trim();
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Left Accent Border Color based on row index
    final isOrange = index % 2 == 0;
    final dynamicLeftColor = isOrange
        ? AppColors.orange
        : (isDark ? const Color(0xFF38608F) : AppColors.primary);

    // Status Badge Styling & Labels
    Color statusBg;
    Color statusTextColor;
    String statusLabel;

    switch (order.status) {
      case 'delivered':
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'DELIVERED';
        break;
      case 'in_transit':
        statusBg = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusLabel = 'IN PROGRESS';
        break;
      case 'failed':
        statusBg = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFB91C1C);
        statusLabel = 'FAILED';
        break;
      case 'call_back':
        statusBg = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFD97706);
        statusLabel = 'CALL BACK';
        break;
      case 'accepted':
      case 'pending':
      default:
        statusBg = const Color(0xFFFDECDD);
        statusTextColor = const Color(0xFFB45309);
        statusLabel = 'PENDING';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dynamic Left Accent Border Bar
              Container(
                width: 4.5,
                color: dynamicLeftColor,
              ),

              // Main Card Content
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/orders/${order.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Left: Customer Name, Status Badge, and Product
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Customer Name + Status Badge
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      order.customerName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: statusTextColor,
                                        letterSpacing: 0.3,
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
                        const SizedBox(width: 12),

                        // Obvious, High-Contrast Call Action Button
                        if (order.customerPhone.isNotEmpty)
                          Material(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(10),
                            elevation: 1,
                            child: InkWell(
                              onTap: () => _callCustomer(order.customerPhone),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 15, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Call',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

