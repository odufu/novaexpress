import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/admin_models.dart';

/// Modal dialog opened when tapping a warehouse row in the Warehouses & Branches table.
/// Displays hub physical specifications, supervisor credentials, capacity, vault status, and contextual actions.
class AdminWarehouseDetailModal extends StatelessWidget {
  final AdminDistributionCenter dc;
  final VoidCallback? onEditDc;
  final VoidCallback? onInboundRestock;

  const AdminWarehouseDetailModal({
    super.key,
    required this.dc,
    this.onEditDc,
    this.onInboundRestock,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminDistributionCenter dc,
    VoidCallback? onEditDc,
    VoidCallback? onInboundRestock,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AdminWarehouseDetailModal(
        dc: dc,
        onEditDc: onEditDc,
        onInboundRestock: onInboundRestock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isGrand = dc.isGrandDc;
    final brandColor = isGrand ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final statusColor = dc.status == 'operational'
        ? const Color(0xFF10B981)
        : (dc.status == 'maintenance' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final capacityPercent = dc.capacity > 0 ? (dc.currentStockCount / dc.capacity * 100).clamp(0, 100) : 0;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGrand ? Icons.stars_rounded : Icons.hub_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dc.name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isGrand)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GRAND DC',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                dc.status.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Code: ${dc.code} • ${dc.city}, ${dc.state} • Lead Supervisor: ${dc.supervisorName}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Warehouse Metrics Ribbon
                    Row(
                      children: [
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Active Couriers',
                          value: '${dc.activeRiders} Riders',
                          icon: Icons.two_wheeler_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Stock Held',
                          value: '${dc.currentStockCount} units',
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Capacity',
                          value: '${dc.capacity} units',
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFFF97316),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Vault Balance',
                          value: CurrencyFormatter.formatNaira(dc.vaultBalance),
                          icon: Icons.account_balance_rounded,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Facility Location & Contact
                    Text(
                      'Facility Location & Physical Logistics Address',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Physical Address', dc.address, isDark),
                          _buildDetailRow('City / Municipal', dc.city, isDark),
                          _buildDetailRow('State / Region', dc.state, isDark),
                          _buildDetailRow('Station Lead Supervisor', dc.supervisorName, isDark, highlight: true),
                          _buildDetailRow(
                            'Administrative Tier',
                            isGrand ? 'Grand Central Command (National Master Node)' : 'Regional Operations Hub',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Storage Utilization & Vault Cash
                    Text(
                      'Storage Capacity & Storage Floor Utilization',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Occupancy: ${dc.currentStockCount} of ${dc.capacity} units (${capacityPercent.toStringAsFixed(1)}%)',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${dc.capacity - dc.currentStockCount} available',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (capacityPercent / 100).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                capacityPercent > 85 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onInboundRestock != null) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Inbound QC Restock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onInboundRestock?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onEditDc != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit DC Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEditDc?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
