import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dc_console/presentation/widgets/dc_order_detail_modal.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_create_order_modal.dart';

class ClientOrdersPage extends ConsumerStatefulWidget {
  const ClientOrdersPage({super.key});

  @override
  ConsumerState<ClientOrdersPage> createState() => _ClientOrdersPageState();
}

class _ClientOrdersPageState extends ConsumerState<ClientOrdersPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBulkCsvImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload_file_rounded, color: Color(0xFF0D9488)),
            const SizedBox(width: 8),
            Text('Bulk CSV Order Import', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload a batch CSV file with customer orders. NoveXPS automated 2-tier dispatch engine will parse each order, resolve the State/LGA, and instantly route it to the optimal Distribution Center and LGA delivery agent.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Required CSV Columns:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('customer_name, customer_phone, delivery_address, delivery_state, delivery_lga, product_name, package_name, quantity, total_amount, payment_type',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              final count = await ref.read(clientPortalProvider.notifier).importBulkOrdersCsv();
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D9488),
                  content: Text('Successfully imported and dispatched $count bulk orders!'),
                ),
              );
            },
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Import Sample Batch (2 Orders)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final orders = state.filteredOrders;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 850;

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Header Bar: Responsive Title & Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Orders & Dispatch',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Real-time overview of all orders created by ${state.clientProfile.companyName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showBulkCsvImportDialog,
                    icon: Icon(Icons.file_upload_outlined, size: 16, color: isDark ? Colors.white : const Color(0xFF475569)),
                    label: Text(
                      'Bulk CSV',
                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF475569)),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => ClientCreateOrderModal.show(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('New Order', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Toolbar Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Filter Controls: Search and State Dropdown
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isFilterWide = constraints.maxWidth >= 600;
                    if (isFilterWide) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: _buildSearchField(isDark)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildStateFilter(state, isDark)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildSearchField(isDark),
                          const SizedBox(height: 8),
                          _buildStateFilter(state, isDark),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 10),

                // Status Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('all', 'All Orders (${state.orders.length})', isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('pending', 'Processing (${state.pendingOrdersCount})', isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('assigned', 'Assigned (${state.orders.where((o) => o.status == "assigned").length})', isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('in_transit', 'In Transit (${state.inTransitOrdersCount})', isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('delivered', 'Delivered (${state.deliveredOrdersCount})', isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('failed', 'Failed (${state.failedOrdersCount})', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Orders List: Responsive Table for Desktop vs Clean Cards for Mobile/Tablet
          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 44, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),
                    Text(
                      'No matching orders found',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try modifying your search or filter terms',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else if (isWide)
            // Desktop Wide Table View
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) => Divider(
                  color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9),
                  height: 1,
                ),
                itemBuilder: (context, index) => _buildOrderTableRow(orders[index], isDark),
              ),
            )
          else
            // Mobile & Tablet Responsive Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildOrderMobileCard(orders[index], isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => ref.read(clientPortalProvider.notifier).setSearchQuery(val),
        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search order #, customer, product...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildStateFilter(ClientPortalState state, bool isDark) {
    return SizedBox(
      height: 38,
      child: DropdownButtonFormField<String>(
        value: state.selectedStateFilter,
        isExpanded: true,
        style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All States')),
          ...NigeriaLocations.states.map((s) => DropdownMenuItem(value: s, child: Text(s))),
        ],
        onChanged: (val) {
          if (val != null) ref.read(clientPortalProvider.notifier).setStateFilter(val);
        },
      ),
    );
  }

  Widget _buildStatusFilterChip(String status, String label, bool isDark) {
    final state = ref.watch(clientPortalProvider);
    final isSelected = state.selectedStatusFilter == status;
    return InkWell(
      onTap: () => ref.read(clientPortalProvider.notifier).setStatusFilter(status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF37021)
                : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTableRow(OrderEntity order, bool isDark) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => DCOrderDetailModal(order: order),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Order # & Date
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    order.createdAt.toLocal().toString().substring(0, 16),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

            // Recipient & Destination
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${order.customerPhone} • ${order.lga ?? "AMAC"}, ${order.deliveryState}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Product & Package
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.productName} (${order.packageDealName ?? "${order.quantity} units"})',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '₦${order.totalAmount.toStringAsFixed(0)} • ${order.paymentType}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Assigned Hub & Rider / Closer
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 13, color: Color(0xFFF37021)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.distributionCenterId != null ? 'Wuse Central DC' : 'Auto Routing...',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.deliveryAgentName ?? 'Pending Auto-Assign',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Badge
            _buildStatusBadge(order.status),
            const SizedBox(width: 10),
            const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0D9488)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderMobileCard(OrderEntity order, bool isDark) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => DCOrderDetailModal(order: order),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151D36) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Order # & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFFF37021)),
                    const SizedBox(width: 6),
                    Text(
                      order.orderNumber,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 8),

            // Customer & Destination
            Text(
              order.customerName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              '${order.customerPhone} • ${order.lga ?? "AMAC"}, ${order.deliveryState}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Product & Price Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${order.productName} (${order.packageDealName ?? "${order.quantity} units"})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₦${order.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Dispatch & Closer Attribution
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      order.deliveryAgentName ?? 'Pending Rider',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                if (order.closerCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Closer: ${order.closerCode}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'delivered':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        label = 'Delivered';
        break;
      case 'in_transit':
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        fg = const Color(0xFF3B82F6);
        label = 'In Transit';
        break;
      case 'assigned':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        label = 'Assigned';
        break;
      case 'failed':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        label = 'Failed';
        break;
      case 'pending':
      default:
        bg = const Color(0xFF64748B).withValues(alpha: 0.12);
        fg = const Color(0xFF64748B);
        label = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
