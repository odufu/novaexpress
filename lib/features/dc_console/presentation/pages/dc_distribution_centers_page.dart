import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/location_lookup_service.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';

class DCDistributionCentersPage extends ConsumerStatefulWidget {
  const DCDistributionCentersPage({super.key});

  @override
  ConsumerState<DCDistributionCentersPage> createState() => _DCDistributionCentersPageState();
}

class _DCDistributionCentersPageState extends ConsumerState<DCDistributionCentersPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> get _nigerianStates => ['All States', ...LocationLookupService.getAllStates()];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final notifier = ref.read(dcConsoleProvider.notifier);

    final allDcs = dcState.distributionCenters.isNotEmpty
        ? dcState.distributionCenters
        : defaultDistributionCenters;
    final filteredDcs = dcState.filteredDistributionCenters;

    final totalDcs = allDcs.length;
    final totalHubs = allDcs.where((d) => d.isHub).length;
    final totalActive = allDcs.where((d) => d.isActive).length;
    final totalCapacity = allDcs.fold<int>(0, (sum, d) => sum + d.storageCapacityUnits);
    final totalRiders = allDcs.fold<int>(0, (sum, d) => sum + d.totalAssignedRiders);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title & Create Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribution Centers Network',
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provision, monitor, and manage regional fulfillment hubs, transit depots, and coverage zones.',
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 11.5 : 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateOrEditDCDialog(context, isDark),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 17, color: Colors.white),
                  label: Text(
                    isCompact ? 'New DC' : '+ Register Distribution Center',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 18, vertical: isCompact ? 10 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top KPI Summary Cards
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard(
                      width: cardWidth,
                      title: 'Total Network DCs',
                      value: '$totalDcs Hubs',
                      subtext: '$totalActive active operations',
                      icon: Icons.apartment_rounded,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      width: cardWidth,
                      title: 'Primary Regional Hubs',
                      value: '$totalHubs Hubs',
                      subtext: '${totalDcs - totalHubs} satellite depots',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF37021),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      width: cardWidth,
                      title: 'Fleet Attachment Capacity',
                      value: '$totalRiders Riders',
                      subtext: 'Across all active facilities',
                      icon: Icons.two_wheeler_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      width: cardWidth,
                      title: 'Network Storage Volume',
                      value: '${totalCapacity.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Units',
                      subtext: 'Cumulative warehouse space',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Input
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => notifier.setSearchQuery(val),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search distribution centers by name, code, state, city, or operating zone...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        notifier.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // State Filter Dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: dcState.selectedStateFilter,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
                            ),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
                            items: _nigerianStates.map((state) {
                              return DropdownMenuItem<String>(
                                value: state == 'All States' ? 'all' : state,
                                child: Text(state),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                notifier.setSelectedStateFilter(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All Hubs (${allDcs.length})', dcState.dcFilter, isDark, (f) => notifier.setDcFilter(f)),
                        const SizedBox(width: 8),
                        _buildFilterChip('hubs', '⭐ Regional Hubs (${allDcs.where((d) => d.isHub).length})', dcState.dcFilter, isDark, (f) => notifier.setDcFilter(f)),
                        const SizedBox(width: 8),
                        _buildFilterChip('satellites', '🛰️ Satellite Depots (${allDcs.where((d) => !d.isHub).length})', dcState.dcFilter, isDark, (f) => notifier.setDcFilter(f)),
                        const SizedBox(width: 8),
                        _buildFilterChip('active', '✅ Active Operations (${allDcs.where((d) => d.isActive).length})', dcState.dcFilter, isDark, (f) => notifier.setDcFilter(f)),
                        const SizedBox(width: 8),
                        _buildFilterChip('inactive', '⏸️ Inactive (${allDcs.where((d) => !d.isActive).length})', dcState.dcFilter, isDark, (f) => notifier.setDcFilter(f)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Distribution Center Cards List
            if (filteredDcs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.apartment_outlined, size: 54, color: const Color(0xFF94A3B8)),
                    const SizedBox(height: 14),
                    Text(
                      'No Distribution Centers Found',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try refining your search keyword or selected state filter.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isTwoCol = constraints.maxWidth >= 850;
                  final itemWidth = isTwoCol ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: filteredDcs.map((dc) {
                      final isCurrentActiveHub = dc.id == dcState.activeHubId || dc.code == dcState.activeHubCode;

                      return SizedBox(
                        width: itemWidth,
                        child: _buildDCCard(
                          context: context,
                          dc: dc,
                          isCurrentActiveHub: isCurrentActiveHub,
                          isDark: isDark,
                          onEdit: () => _showCreateOrEditDCDialog(context, isDark, existingDc: dc),
                          onManageZones: () => _showZoneManagementModal(context, dc, isDark),
                          onSwitchHub: () {
                            notifier.switchActiveHub(dc);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Active Hub switched to ${dc.name} (${dc.code})'),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          onToggleStatus: () {
                            notifier.toggleDistributionCenterStatus(dc.id, !dc.isActive);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    String currentFilter,
    bool isDark,
    Function(String) onSelect,
  ) {
    final isSelected = currentFilter == key;

    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDCCard({
    required BuildContext context,
    required DistributionCenter dc,
    required bool isCurrentActiveHub,
    required bool isDark,
    required VoidCallback onEdit,
    required VoidCallback onManageZones,
    required VoidCallback onSwitchHub,
    required VoidCallback onToggleStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentActiveHub
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isCurrentActiveHub ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentActiveHub
                ? const Color(0xFFF37021).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code Badge, Hub Type, Active Status, Context Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dc.isHub
                      ? const Color(0xFFF37021).withValues(alpha: 0.12)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  dc.isHub ? Icons.warehouse_rounded : Icons.apartment_rounded,
                  color: dc.isHub ? const Color(0xFFF37021) : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dc.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentActiveHub) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'CURRENT DC',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dc.code,
                            style: GoogleFonts.firaCode(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '•  ${dc.fullLocation}',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Active / Inactive Pill
              InkWell(
                onTap: onToggleStatus,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dc.isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dc.isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFF94A3B8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dc.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dc.isActive ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: dc.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Physical Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dc.address,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Contact Details & Manager
          Row(
            children: [
              if (dc.managerName != null && dc.managerName!.isNotEmpty) ...[
                const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dc.managerName!,
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (dc.contactPhone != null && dc.contactPhone!.isNotEmpty) ...[
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  dc.contactPhone!,
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Operational Statistics Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildStatItem('Classification', dc.isHub ? 'Regional Hub' : 'Satellite Depot', isDark, isBold: true)),
                Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildStatItem('Storage Volume', dc.displayCapacity, isDark)),
                Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildStatItem('Operating Zones', '${dc.operatingZones.length} Zones', isDark)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Coverage Delivery Zones Tags
          Row(
            children: [
              Text(
                'Coverage Delivery Zones:',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
              const Spacer(),
              InkWell(
                onTap: onManageZones,
                child: Text(
                  'Manage Zones ➜',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: dc.operatingZones.take(5).map((zone) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  zone,
                  style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              );
            }).toList()
              ..addAll(dc.operatingZones.length > 5
                  ? [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${dc.operatingZones.length - 5} more',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                      )
                    ]
                  : []),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isCurrentActiveHub ? null : onSwitchHub,
                  icon: Icon(
                    isCurrentActiveHub ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isCurrentActiveHub ? 'Active Hub' : 'Switch to Hub',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentActiveHub ? const Color(0xFF10B981) : const Color(0xFFF37021),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showCreateOrEditDCDialog(
    BuildContext context,
    bool isDark, {
    DistributionCenter? existingDc,
  }) {
    final isEditing = existingDc != null;
    final nameCtrl = TextEditingController(text: existingDc?.name ?? '');
    final codeCtrl = TextEditingController(text: existingDc?.code ?? 'DC-');
    final cityCtrl = TextEditingController(text: existingDc?.city ?? 'Abuja');
    final addressCtrl = TextEditingController(text: existingDc?.address ?? '');
    final phoneCtrl = TextEditingController(text: existingDc?.contactPhone ?? '+234 ');
    final emailCtrl = TextEditingController(text: existingDc?.contactEmail ?? '');
    final managerCtrl = TextEditingController(text: existingDc?.managerName ?? '');
    final capacityCtrl = TextEditingController(text: existingDc != null ? existingDc.storageCapacityUnits.toString() : '35000');

    String selectedState = existingDc?.state ?? 'Federal Capital Territory';
    if (!LocationLookupService.getAllStates().contains(selectedState)) {
      selectedState = LocationLookupService.normalizeStateName(selectedState);
    }
    bool isHub = existingDc?.isHub ?? false;
    bool isActive = existingDc?.isActive ?? true;

    List<String> availableLgas = LocationLookupService.getLgasForState(selectedState);
    List<String> selectedLgas = existingDc != null && existingDc.operatingZones.isNotEmpty
        ? List<String>.from(existingDc.operatingZones)
        : (availableLgas.isNotEmpty ? List<String>.from(availableLgas) : ['Abuja Municipal (AMAC)']);

    String lgaSearchQuery = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          final filteredLgas = lgaSearchQuery.trim().isEmpty
              ? availableLgas
              : availableLgas.where((l) => l.toLowerCase().contains(lgaSearchQuery.toLowerCase())).toList();

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Distribution Center' : 'Register New Distribution Center',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Distribution Center Name *',
                        hintText: 'e.g. Lekki Regional Fulfillment Hub',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Unique DC Code *',
                              hintText: 'e.g. DC-LOS-03',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: LocationLookupService.getAllStates().contains(selectedState)
                                ? selectedState
                                : LocationLookupService.getAllStates().first,
                            decoration: const InputDecoration(labelText: 'Operating State (Nigeria) *'),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: LocationLookupService.getAllStates().map((state) {
                              return DropdownMenuItem<String>(
                                value: state,
                                child: Text(state, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedState = val;
                                  availableLgas = LocationLookupService.getLgasForState(val);
                                  selectedLgas = List.from(availableLgas);
                                  cityCtrl.text = availableLgas.isNotEmpty ? availableLgas.first : val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City / Municipality *',
                              hintText: 'e.g. Lekki',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Storage Capacity (Units)',
                              hintText: 'e.g. 50000',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Full Physical Warehouse Address *',
                        hintText: 'Plot number, street, industrial layout, nearest landmark',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: managerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Station Manager Name',
                              hintText: 'e.g. Folake Adebayo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact Phone Number',
                              hintText: '+234 812 345 6789',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Official Hub Email Address',
                        hintText: 'hub.contact@novaexpress.com',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // LGA Coverage Selector Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.map_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'LGAs of Delivery Coverage *',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selectedLgas.length} of ${availableLgas.length} LGAs covered in $selectedState',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() => selectedLgas = List.from(availableLgas));
                                    },
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    child: const Text('Select All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() => selectedLgas.clear());
                                    },
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (availableLgas.length > 8) ...[
                            Container(
                              height: 34,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => lgaSearchQuery = val),
                                style: const TextStyle(fontSize: 11.5),
                                decoration: const InputDecoration(
                                  hintText: 'Filter LGAs...',
                                  hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  prefixIcon: Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],

                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 140),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: filteredLgas.map((lga) {
                                  final isSelected = selectedLgas.contains(lga);
                                  return FilterChip(
                                    label: Text(lga, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF2563EB),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          selectedLgas.add(lga);
                                        } else {
                                          selectedLgas.remove(lga);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hub Classification Checkbox
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isHub,
                            activeColor: const Color(0xFFF37021),
                            onChanged: (val) => setState(() => isHub = val ?? false),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Designate as Primary Regional Hub',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Hubs manage inter-city waybills and fulfill inventory replenishment to satellite depots.',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final code = codeCtrl.text.trim().toUpperCase();
                  final city = cityCtrl.text.trim();
                  final address = addressCtrl.text.trim();

                  if (name.isEmpty || code.isEmpty || city.isEmpty || address.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ DC Name, Code, City, and Address are required fields.'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }

                  if (selectedLgas.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Please attach at least 1 LGA of coverage to this Distribution Center.'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }

                  final capacity = int.tryParse(capacityCtrl.text.replaceAll(',', '')) ?? 25000;
                  final zones = List<String>.from(selectedLgas);

                  try {
                    final savedDc = await showAppLoadingDialog<DistributionCenter>(
                      context: ctx,
                      message: isEditing ? 'Updating Distribution Center...' : 'Registering Distribution Center...',
                      subMessage: 'Syncing fulfillment network directory & live database...',
                      isDark: isDark,
                      task: () async {
                        if (isEditing) {
                          final updated = existingDc.copyWith(
                            name: name,
                            code: code,
                            state: selectedState,
                            city: city,
                            address: address,
                            contactPhone: phoneCtrl.text.trim(),
                            contactEmail: emailCtrl.text.trim(),
                            managerName: managerCtrl.text.trim(),
                            isHub: isHub,
                            isActive: isActive,
                            storageCapacityUnits: capacity,
                            operatingZones: zones,
                            updatedAt: DateTime.now(),
                          );
                          await ref.read(dcConsoleProvider.notifier).updateDistributionCenter(updated);
                          return updated;
                        } else {
                          return await ref.read(dcConsoleProvider.notifier).createDistributionCenter(
                                name: name,
                                code: code,
                                stateName: selectedState,
                                city: city,
                                address: address,
                                contactPhone: phoneCtrl.text.trim(),
                                contactEmail: emailCtrl.text.trim(),
                                managerName: managerCtrl.text.trim(),
                                isHub: isHub,
                                operatingZones: zones,
                                storageCapacityUnits: capacity,
                              );
                        }
                      },
                    );

                    if (savedDc != null) {
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (context.mounted) {
                        _showDCSuccessModal(
                          context: context,
                          isDark: isDark,
                          dc: savedDc,
                          isEditing: isEditing,
                        );
                      }
                    }
                  } catch (e) {
                    var reason = e.toString();
                    if (reason.startsWith('Exception: ')) {
                      reason = reason.substring(11);
                    }
                    if (reason.contains('SocketException') || reason.contains('Failed host lookup')) {
                      reason = 'Network connection error: Unable to connect to live database. Please check your internet connection.';
                    }

                    if (ctx.mounted) {
                      _showDCFailureModal(
                        context: ctx,
                        isDark: isDark,
                        reason: reason,
                        dcName: name,
                        code: code,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: Text(
                  isEditing ? 'Save Changes' : 'Register DC Hub',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDCSuccessModal({
    required BuildContext context,
    required bool isDark,
    required DistributionCenter dc,
    required bool isEditing,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 38),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                isEditing ? 'Distribution Center Updated!' : 'Distribution Center Registered!',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isEditing
                    ? '${dc.name} details have been updated across the network.'
                    : '${dc.name} has been enrolled into the national fulfillment network.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Summary Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('DC Name:', dc.name, isDark, isBold: true),
                    const SizedBox(height: 6),
                    _buildRow('DC Code:', dc.code, isDark, valueColor: const Color(0xFF2563EB)),
                    const SizedBox(height: 6),
                    _buildRow('Classification:', dc.isHub ? '⭐ Primary Regional Hub' : '🛰️ Satellite Depot', isDark),
                    const SizedBox(height: 6),
                    _buildRow('Location:', dc.fullLocation, isDark),
                    const SizedBox(height: 6),
                    _buildRow('Capacity:', dc.displayCapacity, isDark),
                    const SizedBox(height: 6),
                    _buildRow('Coverage Zones:', '${dc.operatingZones.length} Zones', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Back to DC Directory',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDCFailureModal({
    required BuildContext context,
    required bool isDark,
    required String reason,
    required String dcName,
    required String code,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 38),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'DC Registration Failed',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Unable to register "$dcName" ($code).',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Reason Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason / Diagnosis:',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your input fields are preserved. You can review your details and try again.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Back to DC Details',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showZoneManagementModal(BuildContext context, DistributionCenter dc, bool isDark) {
    final zonesList = List<String>.from(dc.operatingZones);
    final zoneInputCtrl = TextEditingController();
    final stateLgas = LocationLookupService.getLgasForState(dc.state);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final unaddedLgas = stateLgas.where((lga) => !zonesList.contains(lga)).toList();

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manage LGA Coverage (${dc.name})',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select LGAs and operational delivery zones attached to this Distribution Hub in ${dc.state}:',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // Add Custom Zone Input Field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: zoneInputCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add custom neighborhood or LGA name...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (val) {
                              final clean = val.trim();
                              if (clean.isNotEmpty && !zonesList.contains(clean)) {
                                setDialogState(() {
                                  zonesList.add(clean);
                                  zoneInputCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final clean = zoneInputCtrl.text.trim();
                            if (clean.isNotEmpty && !zonesList.contains(clean)) {
                              setDialogState(() {
                                zonesList.add(clean);
                                zoneInputCtrl.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: const Text('+ Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Active Zones / Covered LGAs
                    Text(
                      'Active Covered LGAs (${zonesList.length})',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: zonesList.isEmpty
                            ? Text('No LGAs attached. Please select at least 1 LGA.', style: TextStyle(fontSize: 11.5, color: Colors.orange.shade400))
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: zonesList.map((z) {
                                  return Chip(
                                    label: Text(z, style: const TextStyle(fontSize: 11.5)),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                    onDeleted: () {
                                      setDialogState(() => zonesList.remove(z));
                                    },
                                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),

                    if (unaddedLgas.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Available LGAs in ${dc.state} (Tap to attach):',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: unaddedLgas.map((lga) {
                              return ActionChip(
                                label: Text('+ $lga', style: const TextStyle(fontSize: 11)),
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                onPressed: () {
                                  setDialogState(() => zonesList.add(lga));
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(dcConsoleProvider.notifier).updateOperatingZones(dc.id, zonesList);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated ${zonesList.length} coverage zones for ${dc.name}'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Save Zones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
