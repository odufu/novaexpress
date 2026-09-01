import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_rider_detail_modal.dart';
import '../widgets/dc_onboard_rider_modal.dart';

class DCFleetPage extends ConsumerWidget {
  const DCFleetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);

    final allCount = dcState.drivers.length;
    final activeCount = dcState.drivers.where((d) => d.isActive).length;
    final atRestCount = dcState.drivers.where((d) => d.isAtRest).length;
    final delayedCount = dcState.drivers.where((d) => d.isDelayed).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet & Rider Operations',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time fleet monitoring, vehicle telemetry and shift management',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Drivers ($allCount)', 'all', dcState.fleetFilter, dcNotifier),
                const SizedBox(width: 8),
                _buildFilterChip('Active on Route ($activeCount)', 'active', dcState.fleetFilter, dcNotifier, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildFilterChip('At Rest / Standby ($atRestCount)', 'at_rest', dcState.fleetFilter, dcNotifier, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildFilterChip('Delayed Routes ($delayedCount)', 'delayed', dcState.fleetFilter, dcNotifier, color: const Color(0xFFEF4444)),
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
                const SnackBar(content: Text('✅ Fleet manifest exported.')),
              );
            },
            onDriverTap: (driver) => DCRiderDetailModal.show(context, driver),
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
