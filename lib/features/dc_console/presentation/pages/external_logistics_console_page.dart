import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/mark_order_delivered_modal.dart';

/// Lightweight Agency Console for Third-Party Logistics (3PL) Companies & Rider Agents.
/// 
/// Core Architectural Rules:
/// 1. Lightweight & simple for fast adoption.
/// 2. Not completely dependent on agent adoption: DC Operations staff can update
///    stocks and remittances on their behalf directly into NovaXpress.
/// 3. All agents remit collections to NovaXpress; NovaXpress reconciles and settles
///    net funds to Merchants at the end of business hours (on or before 10:00 PM).
/// 4. NovaXpress Platform Admin approves new agents and logistics partners before live.
class ExternalLogisticsConsolePage extends ConsumerStatefulWidget {
  const ExternalLogisticsConsolePage({super.key});

  @override
  ConsumerState<ExternalLogisticsConsolePage> createState() =>
      _ExternalLogisticsConsolePageState();
}

class _ExternalLogisticsConsolePageState
    extends ConsumerState<ExternalLogisticsConsolePage> {
  int _activeTab = 0; // 0: Deliveries, 1: Stock Custody, 2: Remittance & Settlements, 3: Couriers
  String _orderFilter = 'all'; // 'all', 'in_transit', 'delivered', 'pending', 'failed'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadOrders();
      ref.read(stockProvider.notifier).fetchStockItems();
      ref.read(financeProvider.notifier).loadRemittances();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = ref.watch(authProvider).user;
    final dcState = ref.watch(dcConsoleProvider);
    final ordersState = ref.watch(ordersProvider);
    final stockState = ref.watch(stockProvider);
    final financeState = ref.watch(financeProvider);

    final agencyName = authUser?.clientCompanyName?.isNotEmpty == true
        ? authUser!.clientCompanyName!
        : (authUser?.companyId?.isNotEmpty == true
            ? 'Partner Logistics Agency'
            : 'Third-Party Logistics Partner');
    final agencyCode = authUser?.deliveryAgentCode?.isNotEmpty == true
        ? authUser!.deliveryAgentCode!
        : '3PL-AGT-01';
    final connectedDcName = dcState.activeHubName.isNotEmpty
        ? dcState.activeHubName
        : 'Central Command DC Hub';

    // Scoped riders & orders for this partner
    final allOrders = ordersState.orders;
    final agencyRiders = dcState.drivers;
    final activeOrders = allOrders.where((o) =>
        o.status == 'in_transit' ||
        o.status == 'assigned' ||
        o.status == 'out_for_delivery').toList();
    final deliveredOrders = allOrders.where((o) => o.status == 'delivered').toList();

    // Financial calculations
    final currencyFmt = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final totalCollected = deliveredOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    final totalRemitted = financeState.remittances
        .where((r) => r.isVerified)
        .fold<double>(0.0, (s, r) => s + r.amount);
    final pendingRemittance = (totalCollected - totalRemitted).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          agencyName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'LIVE & APPROVED',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Partner Code: $agencyCode • Hub: $connectedDcName',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Sync Live Data',
            onPressed: () {
              ref.read(ordersProvider.notifier).loadOrders();
              ref.read(stockProvider.notifier).fetchStockItems();
              ref.read(financeProvider.notifier).loadRemittances();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. Mandatory End-of-Day 10:00 PM Remittance Advisory Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, color: Color(0xFF0284C7), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1)),
                      children: const [
                        TextSpan(
                          text: 'Daily Settlement Rule: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: 'All agents remit daily collections to NovaXpress. NovaXpress reconciles and settles net funds to Merchants on or before 10:00 PM daily.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. High-Level Summary Metrics Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Active In-Transit',
                    value: '${activeOrders.length}',
                    subtitle: 'Deliveries on route',
                    color: const Color(0xFF3B82F6),
                    icon: Icons.two_wheeler_rounded,
                    isDark: isDark,
                  ),
                ),
                Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Delivered Today',
                    value: '${deliveredOrders.length}',
                    subtitle: currencyFmt.format(totalCollected),
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                    isDark: isDark,
                  ),
                ),
                Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Remit to NovaXpress',
                    value: currencyFmt.format(pendingRemittance),
                    subtitle: 'Due before 10:00 PM',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.account_balance_wallet_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // 3. Navigation Tab Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentButton(0, 'Deliveries (${allOrders.length})', Icons.assignment_rounded, isDark),
                _buildSegmentButton(1, 'Stock Custody', Icons.inventory_2_rounded, isDark),
                _buildSegmentButton(2, 'Daily Remittance', Icons.payments_rounded, isDark),
                _buildSegmentButton(3, 'Fleet (${agencyRiders.length})', Icons.people_alt_rounded, isDark),
              ],
            ),
          ),

          // 4. Tab Body Content
          Expanded(
            child: _buildTabContent(
              isDark: isDark,
              orders: allOrders,
              stockItems: stockState.stockItems,
              remittances: financeState.remittances,
              riders: agencyRiders,
              currencyFmt: currencyFmt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0284C7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required bool isDark,
    required List<OrderEntity> orders,
    required List<StockItemEntity> stockItems,
    required List<RemittanceEntity> remittances,
    required List<DCFleetDriver> riders,
    required NumberFormat currencyFmt,
  }) {
    switch (_activeTab) {
      case 0:
        return _buildDeliveriesTab(isDark, orders, currencyFmt);
      case 1:
        return _buildStockCustodyTab(isDark, stockItems);
      case 2:
        return _buildRemittancesTab(isDark, remittances, currencyFmt);
      case 3:
        return _buildRidersTab(isDark, riders);
      default:
        return _buildDeliveriesTab(isDark, orders, currencyFmt);
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 0: DELIVERIES / ORDERS
  // ---------------------------------------------------------------------------
  Widget _buildDeliveriesTab(bool isDark, List<OrderEntity> orders, NumberFormat currencyFmt) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = orders.where((o) {
      if (_orderFilter != 'all' && o.status.toLowerCase() != _orderFilter) return false;
      if (query.isNotEmpty) {
        return o.orderNumber.toLowerCase().contains(query) ||
            o.customerName.toLowerCase().contains(query) ||
            o.productName.toLowerCase().contains(query) ||
            o.deliveryAddress.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Operations Backup Note: DC staff can update on their behalf
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync_rounded, color: Color(0xFF059669), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connected to DC Dispatch Hub: NovaXpress DC Operations staff can also update order statuses and confirm deliveries on your agency\'s behalf.',
                  style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857)),
                ),
              ),
            ],
          ),
        ),

        // Search & Filter Chips Strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search order #, customer, address...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _orderFilter,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'in_transit', child: Text('In-Transit')),
                  DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _orderFilter = val);
                },
              ),
            ],
          ),
        ),

        // Orders List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text('No orders match your filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final order = filtered[idx];
                    final isDelivered = order.status.toLowerCase() == 'delivered';
                    final isInTransit = order.status.toLowerCase() == 'in_transit' ||
                        order.status.toLowerCase() == 'assigned';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDelivered
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : (isInTransit
                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDelivered
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDelivered ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                currencyFmt.format(order.totalAmount),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${order.customerName} • ${order.customerPhone}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            order.deliveryAddress,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 13, color: const Color(0xFF0284C7)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${order.productName} (Qty: ${order.quantity})',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isDelivered) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => MarkOrderDeliveredModal.show(context, order),
                                  child: const Text('Mark Delivered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: STOCK CUSTODY
  // ---------------------------------------------------------------------------
  Widget _buildStockCustodyTab(bool isDark, List<StockItemEntity> stockItems) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Physical Stock Custody: Products allocated to your couriers by the DC Stock Keeper. NovaXpress staff update inventory in real-time.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...stockItems.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0284C7), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('SKU: ${item.sku} • Category: ${item.category}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.totalStock} Units',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0284C7)),
                    ),
                    Text('In Custody', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: REMITTANCE & 10:00 PM RECONCILIATION
  // ---------------------------------------------------------------------------
  Widget _buildRemittancesTab(bool isDark, List<RemittanceEntity> remittances, NumberFormat currencyFmt) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NovaXpress Daily Remittance Reconciliation',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFB45309)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '1. All partner couriers remit cash and direct transfer proofs to NovaXpress DC Treasury daily.\n'
                '2. NovaXpress Finance reconciles gross collections, rider commissions, fuel stipends, and road contingencies.\n'
                '3. On or before 10:00 PM daily, NovaXpress settles net balances to the respective brand merchants.',
                style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Remittance Submissions (${remittances.length})',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (remittances.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No remittances recorded for this cycle yet.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          ...remittances.map((rem) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    rem.isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                    color: rem.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ref: ${rem.referenceNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${rem.paymentMethod.toUpperCase()} • ${DateFormat('dd MMM, hh:mm a').format(rem.createdAt)}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text(
                    currencyFmt.format(rem.amount),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: COURIERS & RIDERS
  // ---------------------------------------------------------------------------
  Widget _buildRidersTab(bool isDark, List<DCFleetDriver> riders) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: riders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final driver = riders[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              UserAvatarWidget(
                avatarUrl: driver.avatarUrl,
                fullName: driver.name,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(driver.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 6),
                        Text('(${driver.driverCode})', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF0284C7))),
                      ],
                    ),
                    Text('Zone: ${driver.assignedZone} • ${driver.vehicleType}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: driver.isAvailable
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  driver.isAvailable ? 'AVAILABLE' : 'OFFLINE',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: driver.isAvailable ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
