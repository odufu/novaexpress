import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_city_map_widget.dart';
import '../widgets/dc_rider_detail_modal.dart';
import '../widgets/dc_onboard_rider_modal.dart';

class DCDashboardPage extends ConsumerWidget {
  const DCDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);

    final inTransitCount = ordersState.orders.where((o) => o.status == 'in_transit' || o.status == 'assigned').length;
    final unassignedCount = ordersState.orders.where((o) => (o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty) && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed').length;
    final pendingReturnsCount = ordersState.orders.where((o) => o.status == 'failed' || o.status == 'call_back').length;
    final pendingRemittance = financeState.totalPendingRemittance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hub Header Banner
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dcState.activeHubName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dcState.activeHubCode,
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Online',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dcState.activeHubName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dcState.activeHubCode,
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Online',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Hub KPIs Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1100;
              const spacing = 12.0;

              double cardWidth;
              if (isMobile) {
                cardWidth = (constraints.maxWidth - spacing) / 2;
              } else if (isTablet) {
                cardWidth = (constraints.maxWidth - (spacing * 3)) / 4;
              } else {
                cardWidth = (constraints.maxWidth - (spacing * 3)) / 4;
              }

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildMetricCard(
                    title: 'Restock Picking Queue',
                    value: '$unassignedCount Orders',
                    subtext: 'Awaiting rider allocation',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFF37021),
                    isDark: isDark,
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: 'In-Transit Orders',
                    value: '$inTransitCount Active Routes',
                    subtext: 'Active field deliveries',
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: 'Cash in Fleet Custody',
                    value: CurrencyFormatter.formatNaira(pendingRemittance),
                    subtext: 'Pending COD remittance',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: 'Returns Awaiting QC',
                    value: '$pendingReturnsCount Orders',
                    subtext: 'Pending QC or rescheduling',
                    icon: Icons.assignment_return_outlined,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Map & Live Fleet Visualization
          Container(
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DCCityMapWidget(
                drivers: dcState.drivers,
                onDriverSelected: (driver) => DCRiderDetailModal.show(context, driver),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Driver Manifest Section
          DCDriverManifestTable(
            drivers: dcState.filteredDrivers,
            onAddDriver: () => DCOnboardRiderModal.show(context),
            onExportCSV: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ DC Rider Manifest exported as CSV.')),
              );
            },
            onDriverTap: (driver) => DCRiderDetailModal.show(context, driver),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
    required double width,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
