import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_contact_rider_modal.dart';

final dcOrderMatchingSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcOrderMatchingFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcOrderMatchingRiderFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final dcOrderMatchingTableViewProvider = StateProvider.autoDispose<bool>((ref) => false);

class DCOrderPaymentMatchingPage extends ConsumerStatefulWidget {
  const DCOrderPaymentMatchingPage({super.key});

  @override
  ConsumerState<DCOrderPaymentMatchingPage> createState() => _DCOrderPaymentMatchingPageState();
}

class _DCOrderPaymentMatchingPageState extends ConsumerState<DCOrderPaymentMatchingPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');
      ref.read(financeProvider.notifier).loadRemittances('22222222-2222-4222-8222-222222222222');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Evaluates payment status classification for an order
  String _getOrderPaymentCategory(OrderEntity order, List<RemittanceEntity> remittances) {
    if (order.isDirectTransfer) {
      return 'direct_paystack';
    }
    if (order.status == 'delivered') {
      // Check if rider has verified remittance matching this delivery
      final isRemitted = remittances.any((r) =>
          r.isVerified &&
          (r.referenceNumber.contains(order.orderNumber) ||
              r.deliveryAgentId == order.deliveryAgentId));
      return isRemitted ? 'remitted_verified' : 'cash_awaiting_remittance';
    }
    return 'in_transit';
  }

  /// Calculates net remittance due for an order after deducting rider commission, transport and transfer charge
  double _calculateNetRemittanceDue(OrderEntity order) {
    if (order.isDirectTransfer) return 0.0;
    const defaultRiderCommission = 1000.0;
    const defaultTransportAllowance = 1500.0;
    final transferFee = TransactionFeeCalculator.calculateTransferFee(order.totalAmount);
    final totalDeduction = defaultRiderCommission + defaultTransportAllowance + transferFee;
    return (order.totalAmount - totalDeduction).clamp(0.0, order.totalAmount);
  }

  List<OrderEntity> _filterOrders(
    List<OrderEntity> orders,
    List<RemittanceEntity> remittances,
    String selectedFilter,
    String? selectedRiderFilter,
    String searchQuery,
  ) {
    final query = searchQuery.trim().toLowerCase();
    return orders.where((order) {
      final category = _getOrderPaymentCategory(order, remittances);

      if (selectedFilter == 'direct_paystack' && category != 'direct_paystack') {
        return false;
      }
      if (selectedFilter == 'cash_awaiting_remittance' && category != 'cash_awaiting_remittance') {
        return false;
      }
      if (selectedFilter == 'remitted_verified' && category != 'remitted_verified') {
        return false;
      }
      if (selectedFilter == 'in_transit' && category != 'in_transit') {
        return false;
      }

      if (selectedRiderFilter != null && selectedRiderFilter.isNotEmpty) {
        final riderCode = order.deliveryAgentCode ?? order.deliveryAgentId ?? '';
        if (riderCode != selectedRiderFilter) {
          return false;
        }
      }

      if (query.isNotEmpty) {
        final matchOrderNo = order.orderNumber.toLowerCase().contains(query);
        final matchCustomer = order.customerName.toLowerCase().contains(query);
        final matchCity = order.deliveryCity.toLowerCase().contains(query);
        final matchRider = (order.deliveryAgentName ?? '').toLowerCase().contains(query);
        final matchRiderCode = (order.deliveryAgentCode ?? '').toLowerCase().contains(query);
        if (!matchOrderNo && !matchCustomer && !matchCity && !matchRider && !matchRiderCode) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);
    final selectedFilter = ref.watch(dcOrderMatchingFilterProvider);
    final selectedRiderFilter = ref.watch(dcOrderMatchingRiderFilterProvider);
    final searchQuery = ref.watch(dcOrderMatchingSearchProvider);
    final isTableView = ref.watch(dcOrderMatchingTableViewProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final allOrders = ordersState.orders;
    final allRemittances = financeState.remittances;
    final filteredOrders = _filterOrders(allOrders, allRemittances, selectedFilter, selectedRiderFilter, searchQuery);

    // Compute Key Metrics
    final totalOrderValue = allOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final directPaystackOrders = allOrders.where((o) => _getOrderPaymentCategory(o, allRemittances) == 'direct_paystack').toList();
    final directPaystackSum = directPaystackOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    final cashAwaitingOrders = allOrders.where((o) => _getOrderPaymentCategory(o, allRemittances) == 'cash_awaiting_remittance').toList();
    final cashAwaitingGross = cashAwaitingOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final cashAwaitingNetDue = cashAwaitingOrders.fold(0.0, (sum, o) => sum + _calculateNetRemittanceDue(o));

    final remittedOrders = allOrders.where((o) => _getOrderPaymentCategory(o, allRemittances) == 'remitted_verified').toList();
    final remittedSum = remittedOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    // Get unique list of assigned riders for dropdown filter
    final uniqueRiders = <String, String>{};
    for (final o in allOrders) {
      final code = o.deliveryAgentCode ?? o.deliveryAgentId;
      final name = o.deliveryAgentName ?? (code != null ? 'Rider $code' : 'Unassigned');
      if (code != null && code.isNotEmpty) {
        uniqueRiders[code] = name;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.price_check_rounded, color: Color(0xFFF37021), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Order-Payment Matching & Reconciliation',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 17 : 21,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Matches orders to payment channels: Direct Paystack Settlements vs Cash Collected Awaiting Remittance.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Refresh Matching Matrix',
                  onPressed: () {
                    ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');
                    ref.read(financeProvider.notifier).loadRemittances('22222222-2222-4222-8222-222222222222');
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 KPI Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth;
                if (constraints.maxWidth < 600) {
                  cardWidth = constraints.maxWidth;
                } else if (constraints.maxWidth < 1100) {
                  cardWidth = (constraints.maxWidth - 12) / 2;
                } else {
                  cardWidth = (constraints.maxWidth - 36) / 4;
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildSummaryCard(
                      title: 'TOTAL MONITORED VALUE',
                      value: CurrencyFormatter.formatNaira(totalOrderValue),
                      subtext: '${allOrders.length} Shipments Audited',
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: cardWidth,
                      isDark: isDark,
                    ),
                    _buildSummaryCard(
                      title: 'DIRECT PAYSTACK PAID',
                      value: CurrencyFormatter.formatNaira(directPaystackSum),
                      subtext: '${directPaystackOrders.length} Orders • ₦0 Cash Held by Rider',
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFF00A2D3),
                      bgColor: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
                      borderColor: const Color(0xFF00A2D3).withValues(alpha: 0.4),
                      width: cardWidth,
                      isDark: isDark,
                    ),
                    _buildSummaryCard(
                      title: 'CASH AWAITING REMITTANCE',
                      value: CurrencyFormatter.formatNaira(cashAwaitingNetDue),
                      subtext: '${cashAwaitingOrders.length} Orders (${CurrencyFormatter.formatNaira(cashAwaitingGross)} Gross)',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      bgColor: isDark ? const Color(0xFF2E1C0C) : const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      width: cardWidth,
                      isDark: isDark,
                      isAlert: cashAwaitingOrders.isNotEmpty,
                    ),
                    _buildSummaryCard(
                      title: 'REMITTED & RECONCILED',
                      value: CurrencyFormatter.formatNaira(remittedSum),
                      subtext: '${remittedOrders.length} Orders Cleared into Treasury',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF10B981),
                      bgColor: isDark ? const Color(0xFF0D2818) : const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: cardWidth,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filter Bar (Search + Tabs + Rider Dropdown)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search Input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => ref.read(dcOrderMatchingSearchProvider.notifier).state = val,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by Order #, Customer, City, or Rider...',
                            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Rider Dropdown Filter
                      if (uniqueRiders.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: selectedRiderFilter,
                              hint: Text('All Riders', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Fleet Riders', style: TextStyle(fontSize: 12.5)),
                                ),
                                ...uniqueRiders.entries.map(
                                  (e) => DropdownMenuItem<String?>(
                                    value: e.key,
                                    child: Text('${e.value} (${e.key})', style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ),
                              ],
                              onChanged: (val) => ref.read(dcOrderMatchingRiderFilterProvider.notifier).state = val,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips / Tabs & View Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Filter Chips / Tabs
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'All Orders (${allOrders.length})', Icons.dashboard_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip('direct_paystack', '⚡ Direct Paystack (${directPaystackOrders.length})', Icons.bolt_rounded, color: const Color(0xFF00A2D3)),
                              const SizedBox(width: 8),
                              _buildFilterChip('cash_awaiting_remittance', '⚠️ Cash Awaiting Remittance (${cashAwaitingOrders.length})', Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              _buildFilterChip('remitted_verified', '✅ Remitted & Verified (${remittedOrders.length})', Icons.check_circle_rounded, color: const Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              _buildFilterChip('in_transit', '⏳ In-Transit / Pending', Icons.local_shipping_rounded, color: const Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // View Mode Switcher: Cards vs Table
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewToggleBtn(
                              icon: Icons.table_chart_rounded,
                              label: 'Table',
                              isSelected: isTableView,
                              isDark: isDark,
                              onTap: () => ref.read(dcOrderMatchingTableViewProvider.notifier).state = true,
                            ),
                            _buildViewToggleBtn(
                              icon: Icons.view_agenda_rounded,
                              label: 'Cards',
                              isSelected: !isTableView,
                              isDark: isDark,
                              onTap: () => ref.read(dcOrderMatchingTableViewProvider.notifier).state = false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order-Payment Matching Matrix (Table View or Card View)
            if (filteredOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rule_folder_outlined, size: 48, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No orders matching the selected filter criteria',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting search terms or clearing payment filter.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              )
            else if (isTableView)
              _buildOrderPaymentTableView(filteredOrders, allRemittances, isDark, isMobile)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final order = filteredOrders[index];
                  return _buildOrderPaymentMatchCard(order, allRemittances, isDark, isMobile);
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF37021) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _buildTableColumnHeader(String label, IconData icon, bool isDark) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFF37021)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPaymentTableView(
    List<OrderEntity> orders,
    List<RemittanceEntity> remittances,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1080),
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 76,
              horizontalMargin: 16,
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              ),
              columns: [
                _buildTableColumnHeader('SHIPMENT / ITEM', Icons.local_shipping_outlined, isDark),
                _buildTableColumnHeader('CUSTOMER & LOCATION', Icons.location_on_outlined, isDark),
                _buildTableColumnHeader('PAYABLE AMOUNT', Icons.payments_outlined, isDark),
                _buildTableColumnHeader('PAYMENT METHOD', Icons.bolt_rounded, isDark),
                _buildTableColumnHeader('RECONCILIATION / NET REMITTANCE', Icons.fact_check_outlined, isDark),
                _buildTableColumnHeader('ASSIGNED RIDER', Icons.delivery_dining_rounded, isDark),
                _buildTableColumnHeader('ACTION', Icons.support_agent_rounded, isDark),
              ],
              rows: orders.map((order) {
                final paymentCategory = _getOrderPaymentCategory(order, remittances);
                final netRemittanceDue = _calculateNetRemittanceDue(order);
                final dcDrivers = ref.watch(dcConsoleProvider).drivers;
                final matchedDriver = dcDrivers.cast<DCFleetDriver?>().firstWhere(
                      (d) =>
                          d != null &&
                          ((order.deliveryAgentId != null && d.id == order.deliveryAgentId) ||
                              (order.deliveryAgentCode != null && d.driverCode.toLowerCase() == order.deliveryAgentCode!.toLowerCase())),
                      orElse: () => null,
                    );
                final riderName = matchedDriver?.name ?? order.deliveryAgentName ?? (order.deliveryAgentCode != null ? 'Rider ${order.deliveryAgentCode}' : 'Unassigned Rider');
                final riderCode = matchedDriver?.driverCode ?? order.deliveryAgentCode ?? 'PDA-7182';
                final riderPhone = matchedDriver?.phone.isNotEmpty == true ? matchedDriver!.phone : '08031234567';
                final riderAvatarUrl = matchedDriver?.avatarUrl ?? '';
                final isDirectPaystack = paymentCategory == 'direct_paystack';
                final isCashAwaiting = paymentCategory == 'cash_awaiting_remittance';
                final isRemitted = paymentCategory == 'remitted_verified';

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark ? const Color(0xFF253349) : const Color(0xFFF8FAFC);
                    }
                    return null;
                  }),
                  cells: [
                    // 1. Shipment / Item Cell
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${order.quantity}x',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              order.productName,
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Customer & Location Cell
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              order.customerName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Text(
                                order.deliveryCity,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 3. Payable Amount Cell
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(order.totalAmount),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFF37021),
                            ),
                          ),
                          Text(
                            order.statusDisplay,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: order.status == 'delivered' ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. Payment Method Cell
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDirectPaystack
                              ? const Color(0xFF00A2D3).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDirectPaystack
                                ? const Color(0xFF00A2D3).withValues(alpha: 0.4)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDirectPaystack ? Icons.bolt_rounded : Icons.payments_rounded,
                              size: 13,
                              color: isDirectPaystack ? const Color(0xFF00A2D3) : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDirectPaystack ? 'Direct (Paystack)' : 'Cash POD',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDirectPaystack ? const Color(0xFF00A2D3) : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Reconciliation / Net Remittance Cell
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isDirectPaystack) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'Settled (₦0 Cash Held)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Earnings credited to My Balance',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            ),
                          ] else if (isCashAwaiting) ...[
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text(
                                  'Net Due: ${CurrencyFormatter.formatNaira(netRemittanceDue)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Gross: ${CurrencyFormatter.formatNaira(order.totalAmount)} in custody',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            ),
                          ] else if (isRemitted) ...[
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'Remitted & Reconciled',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Cleared into DC Treasury',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Payment Pending',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Awaiting delivery handover',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 6. Assigned Rider Cell
                    DataCell(
                      Row(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: riderAvatarUrl,
                            fullName: riderName,
                            radius: 13,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                riderName,
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Text(
                                riderCode,
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 7. Action Cell
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () {
                          DCContactRiderModal.show(
                            context: context,
                            order: order,
                            riderName: riderName,
                            riderCode: riderCode,
                            riderPhone: riderPhone,
                            riderId: order.deliveryAgentId,
                            riderAvatarUrl: riderAvatarUrl,
                            amountAwaitingRemittance: netRemittanceDue,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCashAwaiting ? const Color(0xFFF37021) : const Color(0xFF031632),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.support_agent_rounded, size: 14),
                        label: Text(
                          isCashAwaiting ? 'Remind' : 'Contact',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required double width,
    required bool isDark,
    bool isAlert = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isAlert ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isAlert ? const Color(0xFFD97706) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, {Color? color}) {
    final selectedFilter = ref.watch(dcOrderMatchingFilterProvider);
    final isSelected = selectedFilter == key;
    final activeColor = color ?? const Color(0xFFF37021);

    return GestureDetector(
      onTap: () => ref.read(dcOrderMatchingFilterProvider.notifier).state = key,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF64748B).withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPaymentMatchCard(OrderEntity order, List<RemittanceEntity> remittances, bool isDark, bool isMobile) {
    final paymentCategory = _getOrderPaymentCategory(order, remittances);
    final netRemittanceDue = _calculateNetRemittanceDue(order);
    final dcDrivers = ref.watch(dcConsoleProvider).drivers;
    final matchedDriver = dcDrivers.cast<DCFleetDriver?>().firstWhere(
          (d) =>
              d != null &&
              ((order.deliveryAgentId != null && d.id == order.deliveryAgentId) ||
                  (order.deliveryAgentCode != null && d.driverCode.toLowerCase() == order.deliveryAgentCode!.toLowerCase())),
          orElse: () => null,
        );
    final riderName = matchedDriver?.name ?? order.deliveryAgentName ?? (order.deliveryAgentCode != null ? 'Rider ${order.deliveryAgentCode}' : 'Unassigned Rider');
    final riderCode = matchedDriver?.driverCode ?? order.deliveryAgentCode ?? 'PDA-7182';
    final riderPhone = matchedDriver?.phone.isNotEmpty == true ? matchedDriver!.phone : '08031234567';
    final riderAvatarUrl = matchedDriver?.avatarUrl ?? '';
    final isDirectPaystack = paymentCategory == 'direct_paystack';
    final isCashAwaiting = paymentCategory == 'cash_awaiting_remittance';
    final isRemitted = paymentCategory == 'remitted_verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCashAwaiting
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : (isDirectPaystack ? const Color(0xFF00A2D3).withValues(alpha: 0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isCashAwaiting ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Order Header + Status Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${order.quantity}x ${order.productName}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Customer: ${order.customerName} • ${order.deliveryAddress}, ${order.deliveryCity}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Total Payable Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(order.totalAmount),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF37021),
                    ),
                  ),
                  Text(
                    order.statusDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: order.status == 'delivered' ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Row 2: Payment Classification Matrix Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDirectPaystack
                  ? const Color(0xFF00A2D3).withValues(alpha: 0.1)
                  : (isCashAwaiting ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDirectPaystack
                    ? const Color(0xFF00A2D3).withValues(alpha: 0.3)
                    : (isCashAwaiting ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDirectPaystack
                      ? Icons.bolt_rounded
                      : (isCashAwaiting ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded),
                  size: 20,
                  color: isDirectPaystack
                      ? const Color(0xFF00A2D3)
                      : (isCashAwaiting ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isDirectPaystack
                                ? '⚡ DIRECT TRANSFER (PAYSTACK PAID)'
                                : (isCashAwaiting
                                    ? '⚠️ CASH POD - AWAITING REMITTANCE'
                                    : (isRemitted ? '✅ CASH REMITTED & VERIFIED' : '⏳ PAYMENT PENDING ON ROUTE')),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDirectPaystack
                                  ? const Color(0xFF00A2D3)
                                  : (isCashAwaiting ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDirectPaystack
                            ? 'Funds settled directly into company Paystack treasury. ₦0.00 cash held by PDA. Entitlement credited to rider balance.'
                            : (isCashAwaiting
                                ? 'Physical cash of ${CurrencyFormatter.formatNaira(order.totalAmount)} collected in rider custody. Net remittance due to DC: ${CurrencyFormatter.formatNaira(netRemittanceDue)}.'
                                : (isRemitted
                                    ? 'Cash successfully remitted and verified into DC Treasury.'
                                    : 'Delivery in transit. Payment will be collected upon customer handover.')),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Rider in Charge & Contact Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rider Info Tile
              Row(
                children: [
                  UserAvatarWidget(
                    avatarUrl: riderAvatarUrl,
                    fullName: riderName,
                    radius: 16,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riderName,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$riderCode • $riderPhone',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),

              // Action Buttons
              Row(
                children: [
                  // Contact Agent Button
                  ElevatedButton.icon(
                    onPressed: () {
                      DCContactRiderModal.show(
                        context: context,
                        order: order,
                        riderName: riderName,
                        riderCode: riderCode,
                        riderPhone: riderPhone,
                        riderId: order.deliveryAgentId,
                        riderAvatarUrl: riderAvatarUrl,
                        amountAwaitingRemittance: netRemittanceDue,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCashAwaiting ? const Color(0xFFF37021) : const Color(0xFF031632),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.support_agent_rounded, size: 16),
                    label: Text(
                      isCashAwaiting ? 'Contact & Remind Rider' : 'Contact Rider',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
