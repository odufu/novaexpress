import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/dc_fleet_driver.dart';

class DCDriverManifestTable extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          // Header Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF031632),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time shift tracking, compensation model, and SLA performance metrics',
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
                    ElevatedButton.icon(
                      onPressed: onAddDriver,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Onboard Agent',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF031632),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onExportCSV,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      label: Text(
                        'Export CSV',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF031632),
                        ),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 12),
                      actionButtons,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }
              },
            ),
          ),

          const Divider(height: 1, color: Color(0xFF2E3D6B)),

          // Responsive Content: Table for Desktop / Tablet, Card List for Mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;

              if (isNarrow) {
                return _buildMobileCardList(isDark);
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 20,
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
                      DataColumn(label: Text('OPERATOR NAME')),
                      DataColumn(label: Text('PERSONNEL MODEL')),
                      DataColumn(label: Text('AGREEMENT RATE')),
                      DataColumn(label: Text('VEHICLE & PLATE')),
                      DataColumn(label: Text('SHIFT STATUS')),
                      DataColumn(label: Text('ROUTE PROGRESS')),
                      DataColumn(label: Text('SLA')),
                    ],
                    rows: drivers.map((driver) {
                      return DataRow(
                        onSelectChanged: (_) => onDriverTap?.call(driver),
                        cells: [
                          // Driver ID
                          DataCell(
                            Text(
                              driver.driverCode,
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),

                          // Operator Name
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF031632).withValues(alpha: 0.15),
                                  child: Text(
                                    driver.name.isNotEmpty ? driver.name.substring(0, 1) : 'A',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF031632),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  driver.name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),

                          // Personnel Model
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: driver.isPda
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                driver.isPda ? 'PDA (Personal)' : 'In-House (Fleet)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: driver.isPda ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ),

                          // Agreement Rate
                          DataCell(
                            Text(
                              '₦${driver.commissionRate.toInt()} + ₦${driver.transportAllowance.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF031632),
                              ),
                            ),
                          ),

                          // Vehicle & Plate
                          DataCell(
                            Text(
                              driver.vehicleModel,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ),

                          // Status
                          DataCell(_buildStatusPill(driver.status)),

                          // Route Progress
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: driver.routeProgressPercent / 100.0,
                                        minHeight: 6,
                                        backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          driver.isDelayed
                                              ? const Color(0xFFEF4444)
                                              : (driver.routeProgressPercent >= 100
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF37021)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    driver.routeProgressPercent >= 100
                                        ? 'Done'
                                        : '${driver.routeProgressPercent.toInt()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Efficiency / SLA
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: driver.efficiencyRating >= 90
                                      ? const Color(0xFF10B981)
                                      : (driver.efficiencyRating >= 80 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${driver.efficiencyRating.toStringAsFixed(1)}%',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: driver.efficiencyRating >= 90
                                        ? const Color(0xFF10B981)
                                        : (driver.efficiencyRating >= 80 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                  ),
                                ),
                              ],
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

  Widget _buildMobileCardList(bool isDark) {
    if (drivers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No delivery agents found.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final driver = drivers[idx];
        return InkWell(
          onTap: () => onDriverTap?.call(driver),
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
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF031632).withValues(alpha: 0.15),
                            child: Text(
                              driver.name.isNotEmpty ? driver.name.substring(0, 1) : 'A',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF031632)),
                            ),
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
                Text('Vehicle: ${driver.vehicleModel}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: driver.routeProgressPercent / 100.0,
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      driver.isDelayed ? const Color(0xFFEF4444) : const Color(0xFFF37021),
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
