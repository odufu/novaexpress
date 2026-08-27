import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_onboard_rider_modal.dart';
import '../widgets/dc_rider_detail_modal.dart';

class DCRidersPage extends ConsumerWidget {
  const DCRidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);

    final allCount = dcState.drivers.length;
    final pdaCount = dcState.drivers.where((d) => d.isPda).length;
    final inHouseCount = dcState.drivers.where((d) => d.isInHouseRider).length;
    final activeCount = dcState.drivers.where((d) => d.isActive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Onboard CTA
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final headerContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riders & Delivery Fleet Control',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Onboard and manage PDAs & in-house riders with custom commission and transport agreements (BR-010 to BR-015)',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                ],
              );

              final actionButton = ElevatedButton.icon(
                onPressed: () => DCOnboardRiderModal.show(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Onboard Delivery Agent',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF031632),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerContent,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: actionButton),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerContent),
                  const SizedBox(width: 12),
                  actionButton,
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Personnel Model Summary Cards (Responsive Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 900) {
                cardWidth = (constraints.maxWidth - 14) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 28) / 3;
              }

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildPersonnelTypeSummaryCard(
                      title: 'PDA Agents (Personal Transport)',
                      count: '$pdaCount Agents',
                      subtext: 'Carries client inventory • ₦1,000 avg comm.',
                      icon: Icons.two_wheeler_rounded,
                      color: const Color(0xFFF37021),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildPersonnelTypeSummaryCard(
                      title: 'In-House Fleet Riders',
                      count: '$inHouseCount Riders',
                      subtext: 'Company bikes • Base salary + fuel allowance',
                      icon: Icons.delivery_dining_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildPersonnelTypeSummaryCard(
                      title: 'Active on Route Today',
                      count: '$activeCount on Duty',
                      subtext: '96.4% on-time delivery SLA',
                      icon: Icons.badge_rounded,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Agents ($allCount)', 'all', dcState.fleetFilter, dcNotifier),
                const SizedBox(width: 8),
                _buildFilterChip('Active on Route ($activeCount)', 'active', dcState.fleetFilter, dcNotifier, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildFilterChip('At Rest / Standby', 'at_rest', dcState.fleetFilter, dcNotifier, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildFilterChip('Delayed', 'delayed', dcState.fleetFilter, dcNotifier, color: const Color(0xFFEF4444)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Full Driver Manifest Table
          DCDriverManifestTable(
            drivers: dcState.filteredDrivers,
            onAddDriver: () => DCOnboardRiderModal.show(context),
            onExportCSV: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ DC Rider Roster exported as CSV.')),
              );
            },
            onDriverTap: (driver) => DCRiderDetailModal.show(context, driver),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelTypeSummaryCard({
    required String title,
    required String count,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(count, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(subtext, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, String currentFilter, DCConsoleNotifier notifier, {Color? color}) {
    final isSelected = currentFilter.toLowerCase() == filterKey.toLowerCase();
    return InkWell(
      onTap: () => notifier.setFleetFilter(filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? const Color(0xFF2563EB)) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
