import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_onboard_rider_modal.dart';

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
            onDriverTap: (driver) => _showRiderDetailDrawer(context, isDark, driver),
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

  void _showRiderDetailDrawer(BuildContext context, bool isDark, DCFleetDriver driver) {
    final isPda = driver.isPda;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(driver.name.substring(0, 1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(driver.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPda ? const Color(0xFF2563EB).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPda ? 'PDA (Own Transport)' : 'In-House Rider',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isPda ? const Color(0xFF2563EB) : const Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                        Text('${driver.driverCode} • ${driver.vehicleModel}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: driver.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      driver.status.toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: driver.isActive ? const Color(0xFF059669) : const Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Unique Compensation Agreement Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Compensation Agreement Terms', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
                        Text(
                          '${CurrencyFormatter.formatNaira(driver.totalPerDeliveryEntitlement)} / drop',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Model Structure:', driver.compensationType.toUpperCase()),
                    _buildDetailRow('Delivery Commission:', '${CurrencyFormatter.formatNaira(driver.commissionRate)} per drop'),
                    _buildDetailRow('Transport / Fuel Allowance:', '${CurrencyFormatter.formatNaira(driver.transportAllowance)} per drop'),
                    _buildDetailRow('Failed Attempt Stipend:', '${CurrencyFormatter.formatNaira(driver.failedDeliveryAllowance)} per attempt'),
                    if (driver.baseSalary > 0)
                      _buildDetailRow('Monthly Base Salary:', CurrencyFormatter.formatNaira(driver.baseSalary)),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Text('Operational Custody & SLA', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildDetailRow('Assigned Distribution Center:', 'Wuse DC (DC-WUSE-01)'),
              _buildDetailRow('Assigned Zone:', driver.assignedZone),
              _buildDetailRow('Contact Phone:', driver.phone),
              _buildDetailRow('Live Vehicle Stock Units:', '${driver.itemsInCustody} units in custody'),
              _buildDetailRow('Live Cash in Hand (COD):', CurrencyFormatter.formatNaira(driver.cashInCustody), isBold: true),
              _buildDetailRow('Completed Deliveries Today:', '${driver.completedOrders} / ${driver.totalAssignedOrders} orders'),
              _buildDetailRow('Route SLA Rating:', '${driver.efficiencyRating.toStringAsFixed(1)}%'),

              const SizedBox(height: 14),
              Text('Payout Bank Account & Guarantor', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildDetailRow('Payout Bank:', '${driver.bankName} • ${driver.bankAccountNumber}'),
              _buildDetailRow('Account Name:', driver.bankAccountName.isNotEmpty ? driver.bankAccountName : driver.name),
              _buildDetailRow('Guarantor:', '${driver.guarantorName} (${driver.guarantorPhone})'),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📞 Calling ${driver.name} at ${driver.phone}...')),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call Rider'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ Alert sent to ${driver.name}')),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.white),
                      label: const Text('Dispatch Alert', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF031632)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
