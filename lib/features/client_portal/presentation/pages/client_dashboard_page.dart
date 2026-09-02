import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_create_order_modal.dart';
import '../widgets/client_order_tracking_modal.dart';

class ClientDashboardPage extends ConsumerWidget {
  final VoidCallback onNavigateToOrders;
  final VoidCallback onNavigateToProducts;

  const ClientDashboardPage({
    super.key,
    required this.onNavigateToOrders,
    required this.onNavigateToProducts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientPortalProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // Welcome & Quick Action Header
          _buildWelcomeBanner(context, ref, state),
          const SizedBox(height: 24),

          // KPI Metric Summary Grid
          _buildKpiMetricsGrid(context, state),
          const SizedBox(height: 24),

          // Action Shortcuts & Bulk Import Bar
          _buildQuickActionsRow(context, ref),
          const SizedBox(height: 24),

          // Live Active Shipments Section
          _buildLiveOrdersSection(context, state, ref),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, WidgetRef ref, ClientPortalState state) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF2DD4BF), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            state.clientProfile.code,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Live Merchant Console',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  state.clientProfile.companyName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Managing Director: ${state.clientProfile.contactPerson} • ${state.clientProfile.city}, ${state.clientProfile.state}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => ClientCreateOrderModal.show(context),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              'Create New Order',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(BuildContext context, ClientPortalState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildKpiCard(
              title: 'Total Shipments',
              value: '${state.totalOrdersCount}',
              subtitle: '${state.pendingOrdersCount} awaiting dispatch',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF2563EB),
            ),
            _buildKpiCard(
              title: 'Active In-Transit',
              value: '${state.inTransitOrdersCount}',
              subtitle: 'Dispatched to field riders',
              icon: Icons.two_wheeler_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiCard(
              title: 'Delivered Today',
              value: '${state.deliveredOrdersCount}',
              subtitle: 'Success Rate: ${state.deliverySuccessRate.toStringAsFixed(1)}%',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildKpiCard(
              title: 'Gross Delivered Value',
              value: '₦${_formatMoney(state.totalRevenue)}',
              subtitle: 'COD Pending: ₦${_formatMoney(state.pendingCodRemittances)}',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, color: Color(0xFF0D9488), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Merchant Actions',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => ClientCreateOrderModal.show(context),
                icon: const Icon(Icons.add_box_outlined, size: 16, color: Color(0xFF0D9488)),
                label: const Text('Create Order'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onNavigateToProducts,
                icon: const Icon(Icons.add_shopping_cart, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Add Package Deal'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onNavigateToOrders,
                icon: const Icon(Icons.list_alt_rounded, size: 16, color: Color(0xFF475569)),
                label: const Text('View All Orders'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOrdersSection(BuildContext context, ClientPortalState state, WidgetRef ref) {
    final recentOrders = state.orders.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Real-Time Shipments & Dispatch Pipeline',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Track orders dispatched to Distribution Centers and PDA Riders across Nigeria',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onNavigateToOrders,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('See All Shipments'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    Text(
                      'No shipments created yet',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Create New Order" to start sending packages to customers',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentOrders.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 16),
              itemBuilder: (context, index) {
                final order = recentOrders[index];
                return InkWell(
                  onTap: () => ClientOrderTrackingModal.show(context, order),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D9488), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                '${order.customerName} • ${order.deliveryLga ?? "AMAC"}, ${order.deliveryState}',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${order.productName} (${order.packageName ?? "${order.quantity} units"})',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
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
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.assignedAgentName ?? (order.distributionCenterName ?? 'Station DC'),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                order.assignedAgentPhone ?? 'Auto-Assigned',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(order.status),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.track_changes_rounded, color: Color(0xFF0D9488), size: 20),
                          tooltip: 'Track Live Status',
                          onPressed: () => ClientOrderTrackingModal.show(context, order),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'Delivered';
    } else if (s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
      label = 'In Transit';
    } else if (s == 'assigned') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'Assigned';
    } else if (s == 'failed' || s == 'cancelled' || s == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      label = 'Failed';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      label = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String _formatMoney(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(2)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }
}
