import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_city_map_widget.dart';

class DCDashboardPage extends ConsumerWidget {
  const DCDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hub Header Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dcState.activeHubName,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Primary Operations & PDA Fleet Control Desk • Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => dcNotifier.setActiveTab(1),
                icon: const Icon(Icons.outbox_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Orders & Routes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF031632),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4 Core Business Metric Tiles
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 1000) {
                cardWidth = (constraints.maxWidth - 12) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 36) / 4;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    title: 'Restock Picking Queue',
                    value: '2 Requests',
                    subtext: '30 units pending dispatch',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFFF37021),
                    isDark: isDark,
                    width: cardWidth,
                    onTap: () => dcNotifier.setActiveTab(2),
                  ),
                  _buildMetricCard(
                    title: 'In-Transit Orders',
                    value: '12 Active Routes',
                    subtext: '96.2% on-time SLA',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                    width: cardWidth,
                    onTap: () => dcNotifier.setActiveTab(1),
                  ),
                  _buildMetricCard(
                    title: 'Cash in Fleet Custody',
                    value: '₦953,000.00',
                    subtext: 'Unverified COD collections',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    width: cardWidth,
                    onTap: () => dcNotifier.setActiveTab(3),
                  ),
                  _buildMetricCard(
                    title: 'Returns Awaiting QC',
                    value: '2 Packages',
                    subtext: 'Pending inspection & grading',
                    icon: Icons.assignment_return_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    width: cardWidth,
                    onTap: () => dcNotifier.setActiveTab(4),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // GPS City Map Canvas
          Container(
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DCCityMapWidget(
                drivers: dcState.drivers,
                onDriverSelected: (driver) {
                  dcNotifier.selectDriver(driver.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected ${driver.name} (${driver.driverCode}) in ${driver.assignedZone}')),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Driver Manifest Section
          DCDriverManifestTable(
            drivers: dcState.filteredDrivers,
            onAddDriver: () => dcNotifier.setActiveTab(6),
            onExportCSV: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ DC Rider Manifest exported as CSV.')),
              );
            },
            onDriverTap: (driver) {
              dcNotifier.selectDriver(driver.id);
              dcNotifier.setActiveTab(6);
            },
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
    required VoidCallback onTap,
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
