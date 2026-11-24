import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/admin_models.dart';

/// Modal dialog opened when tapping an Agent row in the Agents & 3PLs table.
/// Surfaces key metrics, contact credentials, custody stock breakdown, and contextual actions.
class AdminAgentDetailModal extends StatelessWidget {
  final AdminLogisticsAgent agent;
  final VoidCallback? onAssignMerchants;
  final VoidCallback? onEditAgent;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onManageCustody;

  const AdminAgentDetailModal({
    super.key,
    required this.agent,
    this.onAssignMerchants,
    this.onEditAgent,
    this.onToggleStatus,
    this.onManageCustody,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminLogisticsAgent agent,
    VoidCallback? onAssignMerchants,
    VoidCallback? onEditAgent,
    VoidCallback? onToggleStatus,
    VoidCallback? onManageCustody,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AdminAgentDetailModal(
        agent: agent,
        onAssignMerchants: onAssignMerchants,
        onEditAgent: onEditAgent,
        onToggleStatus: onToggleStatus,
        onManageCustody: onManageCustody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isInternal = agent.type == 'internal_logistics' || agent.agentCode.startsWith('NX-');
    final statusColor = agent.status == 'active'
        ? const Color(0xFF10B981)
        : (agent.status == 'pending_approval' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final totalCustodyUnits = agent.heldStock.values.fold<int>(0, (s, q) => s + q);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: (isInternal ? const Color(0xFF2563EB) : const Color(0xFF0284C7))
                    .withValues(alpha: isDark ? 0.2 : 0.08),
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
                      color: isInternal ? const Color(0xFF2563EB) : const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isInternal ? Icons.local_shipping_rounded : Icons.business_center_rounded,
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
                              agent.name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                agent.status.toUpperCase(),
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
                          '${isInternal ? "Internal Logistics Fleet" : "3PL Logistics Partner"} • Code: ${agent.agentCode} • ${agent.assignedWarehouseName ?? "Operating in Nigeria"}',
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
                    // Key Metric Cards Ribbon
                    Row(
                      children: [
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Active Riders',
                          value: '${agent.activeRidersCount}',
                          icon: Icons.two_wheeler_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Total Deliveries',
                          value: '${agent.totalDeliveries}',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Custody Stock',
                          value: '$totalCustodyUnits units',
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFFF97316),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Total Remitted',
                          value: CurrencyFormatter.formatNaira(agent.totalRemittedNaira),
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Contact & Coverage
                    Text(
                      'Contact & Operating Coverage',
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
                          _buildDetailRow('Contact Person', agent.contactPerson, isDark),
                          _buildDetailRow('Phone Number', agent.phone, isDark),
                          _buildDetailRow('Email Address', agent.email, isDark),
                          _buildDetailRow(
                            'Operating Warehouse',
                            agent.assignedWarehouseName ?? 'Abuja / Lagos Corridors',
                            isDark,
                          ),
                          _buildDetailRow(
                            'Coverage States',
                            agent.coverageStates.isNotEmpty ? agent.coverageStates.join(', ') : 'All Assigned States',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Tariffs & Compensation
                    Text(
                      'Tariffs & Financial Compensation',
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
                          _buildDetailRow(
                            'Delivery Fee (per order)',
                            CurrencyFormatter.formatNaira(agent.deliveryFee),
                            isDark,
                            highlight: true,
                          ),
                          _buildDetailRow(
                            'Failed Delivery Attempt Fee',
                            CurrencyFormatter.formatNaira(agent.failedDeliveryFee),
                            isDark,
                          ),
                          _buildDetailRow(
                            'Commission Rate',
                            '${agent.commissionRate.toStringAsFixed(1)}%',
                            isDark,
                          ),
                          _buildDetailRow(
                            'Bank Name & Account',
                            '${agent.bankName.isNotEmpty ? agent.bankName : "Not Set"} • ${agent.accountNumber.isNotEmpty ? agent.accountNumber : "No Account"} (${agent.accountName})',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Physical Custody Stock Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock in Custody ($totalCustodyUnits total units)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (onManageCustody != null)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.inventory_2_outlined, size: 14),
                            label: const Text('Assign / Manage Custody'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onManageCustody?.call();
                            },
                          )
                        else if (totalCustodyUnits > 0)
                          Text(
                            'Live Fleet Holding',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (agent.heldStock.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'No stock currently in custody for this logistics agent.',
                          style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: agent.heldStock.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 8),
                                      Text(
                                        entry.key,
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${entry.value} units',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onToggleStatus != null)
                    OutlinedButton.icon(
                      icon: Icon(
                        agent.status == 'active' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        size: 15,
                      ),
                      label: Text(agent.status == 'active' ? 'Suspend Agent' : 'Activate Agent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: agent.status == 'active' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        side: BorderSide(
                          color: agent.status == 'active' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onToggleStatus?.call();
                      },
                    ),
                  if (onManageCustody != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.inventory_2_outlined, size: 15),
                      label: const Text('Manage Stock Custody'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onManageCustody?.call();
                      },
                    ),
                  if (onAssignMerchants != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link_rounded, size: 15),
                      label: const Text('Assign Merchants'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onAssignMerchants?.call();
                      },
                    ),
                  if (onEditAgent != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Edit Terms'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEditAgent?.call();
                      },
                    ),
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
