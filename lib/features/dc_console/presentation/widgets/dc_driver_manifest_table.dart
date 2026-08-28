import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';

final manifestSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final manifestFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

class DCDriverManifestTable extends ConsumerStatefulWidget {
  final List<DCFleetDriver> drivers;
  final VoidCallback? onAddDriver;
  final VoidCallback? onExportCSV;
  final Function(DCFleetDriver driver)? onDriverTap;

  const DCDriverManifestTable({
    super.key,
    required this.drivers,
    this.onAddDriver,
    this.onExportCSV,
    this.onDriverTap,
  });

  @override
  ConsumerState<DCDriverManifestTable> createState() => _DCDriverManifestTableState();
}

class _DCDriverManifestTableState extends ConsumerState<DCDriverManifestTable> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  void _onDebouncedSearch(String val) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(manifestSearchProvider.notifier).state = val;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final searchQuery = ref.watch(manifestSearchProvider);
    final personnelFilter = ref.watch(manifestFilterProvider);
    final ordersState = ref.watch(ordersProvider);
    final allOrders = ordersState.orders;

    // Filter drivers by search query and model filter
    final filteredDrivers = widget.drivers.where((d) {
      if (personnelFilter != 'all') {
        if (personnelFilter == 'pda' && !d.isPda) return false;
        if (personnelFilter == 'in_house' && !d.isInHouseRider) return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchesName = d.name.toLowerCase().contains(q);
        final matchesCode = d.driverCode.toLowerCase().contains(q);
        final matchesPhone = d.phone.contains(q);
        final matchesVehicle = d.vehicleModel.toLowerCase().contains(q) || d.vehiclePlate.toLowerCase().contains(q);
        final matchesZone = d.assignedZone.toLowerCase().contains(q);
        return matchesName || matchesCode || matchesPhone || matchesVehicle || matchesZone;
      }
      return true;
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Strip
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF37021),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delivery Personnel Manifest',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF031632),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live fleet overview, route shift tracking, model classification, and driver operations.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (widget.onAddDriver != null)
                      ElevatedButton.icon(
                        onPressed: widget.onAddDriver,
                        icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                        label: Text('Onboard Agent', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF031632),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    if (widget.onExportCSV != null)
                      OutlinedButton.icon(
                        onPressed: widget.onExportCSV,
                        icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF64748B)),
                        label: Text('Export CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          // Search & Filter Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;

                final searchField = SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onDebouncedSearch,
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search riders by name, code, phone, vehicle, or zone...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(manifestSearchProvider.notifier).state = '';
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
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

                final modelFilters = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip(ref, 'All Models', 'all', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip(ref, 'PDA Agents', 'pda', isDark, activeColor: const Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    _buildFilterChip(ref, 'In-House', 'in_house', isDark, activeColor: const Color(0xFF10B981)),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: modelFilters),
                      const SizedBox(height: 10),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 14),
                    modelFilters,
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF2E3D6B)),

          // Responsive Table View
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 850;

              if (filteredDrivers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_search_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No delivery personnel found matching "$searchQuery".',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (isNarrow) {
                return _buildMobileCardList(filteredDrivers, allOrders, isDark);
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 74,
                    headingRowHeight: 46,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0B1021).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                    ),
                    headingTextStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF64748B),
                    ),
                    dataTextStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF031632),
                    ),
                    columns: const [
                      DataColumn(label: Text('AGENT CODE')),
                      DataColumn(label: Text('RIDER / AGENT')),
                      DataColumn(label: Text('MODEL')),
                      DataColumn(label: Text('AGREEMENT')),
                      DataColumn(label: Text('ZONE & VEHICLE')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('SHIFT PROGRESS')),
                      DataColumn(label: Text('LIVE COD')),
                      DataColumn(label: Text('STOCK')),
                      DataColumn(label: Text('ACTION')),
                    ],
                    rows: filteredDrivers.map((driver) {
                      // Live performance calculations based on matched orders
                      final driverOrders = allOrders.where((o) {
                        return (o.deliveryAgentId != null && o.deliveryAgentId == driver.id) ||
                            (o.deliveryAgentCode != null && o.deliveryAgentCode == driver.driverCode) ||
                            (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase() == driver.name.toLowerCase());
                      }).toList();

                      final totalOrders = driverOrders.isNotEmpty ? driverOrders.length : driver.totalAssignedOrders;
                      final completedOrders = driverOrders.isNotEmpty
                          ? driverOrders.where((o) => o.isDelivered || o.status.toLowerCase() == 'delivered').length
                          : driver.completedOrders;

                      final double progressRatio = totalOrders > 0
                          ? (completedOrders / totalOrders).clamp(0.0, 1.0)
                          : (driver.routeProgressPercent / 100.0).clamp(0.0, 1.0);
                      final int progressPercent = (progressRatio * 100).toInt();

                      return DataRow(
                        onSelectChanged: (_) => widget.onDriverTap?.call(driver),
                        cells: [
                          // Agent Code
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  driver.driverCode,
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rider Name & Contact
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UserAvatarWidget(
                                  avatarUrl: driver.avatarUrl,
                                  fullName: driver.name,
                                  radius: 15,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      driver.phone,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Operating Model
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: driver.isPda
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    driver.isPda ? Icons.phone_android_rounded : Icons.two_wheeler_rounded,
                                    size: 12,
                                    color: driver.isPda ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    driver.isPda ? 'PDA Agent' : 'In-House Fleet',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: driver.isPda ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Agreement Structure
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₦${driver.commissionRate.toInt()} + ₦${driver.transportAllowance.toInt()}',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  driver.isPda ? 'Comm + Transport' : 'Base + Drop Rate',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),

                          // Zone & Vehicle
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 2),
                                    Text(driver.assignedZone, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Text(
                                  '${driver.vehicleModel} • ${driver.vehiclePlate}',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),

                          // Shift Status
                          DataCell(_buildStatusPill(driver.status)),

                          // Shift Performance & Progress Bar (Delivery over Total Orders)
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$completedOrders/$totalOrders',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                      Text(
                                        '$progressPercent%',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: totalOrders == 0
                                              ? const Color(0xFF94A3B8)
                                              : (progressPercent == 100
                                                  ? const Color(0xFF10B981)
                                                  : (driver.isDelayed
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFFF37021))),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalOrders > 0 ? progressRatio : 0.0,
                                      minHeight: 5,
                                      backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        totalOrders == 0
                                            ? const Color(0xFF94A3B8).withValues(alpha: 0.3)
                                            : (progressPercent == 100
                                                ? const Color(0xFF10B981)
                                                : (driver.isDelayed
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFF37021))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Live Cash in Hand (COD)
                          DataCell(
                            Text(
                              CurrencyFormatter.formatNaira(driver.cashInCustody),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),

                          // Stock in Custody
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${driver.itemsInCustody} pkgs',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ),

                          // Action View Details
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
                              tooltip: 'Open Rider Financials & Order Breakdown',
                              onPressed: () => widget.onDriverTap?.call(driver),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, bool isDark, {Color? activeColor}) {
    final currentFilter = ref.watch(manifestFilterProvider);
    final isSelected = currentFilter == value;
    final color = activeColor ?? const Color(0xFFF37021);

    return InkWell(
      onTap: () => ref.read(manifestFilterProvider.notifier).state = value,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardList(List<DCFleetDriver> drivers, List<OrderEntity> allOrders, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final driver = drivers[i];

        // Dynamic order performance calculation
        final driverOrders = allOrders.where((o) {
          return (o.deliveryAgentId != null && o.deliveryAgentId == driver.id) ||
              (o.deliveryAgentCode != null && o.deliveryAgentCode == driver.driverCode) ||
              (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase() == driver.name.toLowerCase());
        }).toList();

        final totalOrders = driverOrders.isNotEmpty ? driverOrders.length : driver.totalAssignedOrders;
        final completedOrders = driverOrders.isNotEmpty
            ? driverOrders.where((o) => o.isDelivered || o.status.toLowerCase() == 'delivered').length
            : driver.completedOrders;

        final double progressRatio = totalOrders > 0
            ? (completedOrders / totalOrders).clamp(0.0, 1.0)
            : (driver.routeProgressPercent / 100.0).clamp(0.0, 1.0);
        final int progressPercent = (progressRatio * 100).toInt();

        return InkWell(
          onTap: () => widget.onDriverTap?.call(driver),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: driver.avatarUrl,
                            fullName: driver.name,
                            radius: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                Text(driver.driverCode, style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF2563EB)), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(driver.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: driver.isPda ? const Color(0xFF2563EB).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          driver.isPda ? 'PDA (Personal)' : 'In-House (Fleet)',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: driver.isPda ? const Color(0xFF2563EB) : const Color(0xFF059669)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Rate: ₦${driver.commissionRate.toInt()} + ₦${driver.transportAllowance.toInt()}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Zone: ${driver.assignedZone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    Text('COD: ${CurrencyFormatter.formatNaira(driver.cashInCustody)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 10),

                // Shift Progress Row & Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shift Deliveries: $completedOrders/$totalOrders',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    Text(
                      '$progressPercent% Completed',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: totalOrders == 0
                            ? const Color(0xFF94A3B8)
                            : (progressPercent == 100
                                ? const Color(0xFF10B981)
                                : (driver.isDelayed
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF37021))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalOrders > 0 ? progressRatio : 0.0,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalOrders == 0
                          ? const Color(0xFF94A3B8).withValues(alpha: 0.3)
                          : (progressPercent == 100
                              ? const Color(0xFF10B981)
                              : (driver.isDelayed
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF37021))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase().replaceAll('_', ' ');

    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF059669);
        break;
      case 'delayed':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFDC2626);
        break;
      case 'at_rest':
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
