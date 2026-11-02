import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_dc_modal.dart';
import '../../widgets/admin_filter_header.dart';
import '../../widgets/admin_metric_card.dart';

class AdminDistributionCentersTab extends ConsumerWidget {
  const AdminDistributionCentersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dcs = state.filteredDistributionCenters;
    final totalDcs = state.distributionCenters.length;
    final totalRiders = state.distributionCenters.fold(0, (s, d) => s + d.activeRiders);
    final totalVaultNaira = state.distributionCenters.fold(0.0, (s, d) => s + d.vaultBalance);
    final totalStock = state.distributionCenters.fold(0, (s, d) => s + d.currentStockCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : 2.5,
                children: [
                  AdminMetricCard(
                    title: 'Active Hubs',
                    value: '$totalDcs',
                    icon: Icons.hub_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    subtitle: 'regional distribution centers',
                    tooltip: 'Commissioned physical logistics centers managing warehousing and dispatch',
                  ),
                  AdminMetricCard(
                    title: 'Fleet Size',
                    value: '$totalRiders',
                    icon: Icons.two_wheeler_outlined,
                    iconColor: AppColors.orange,
                    subtitle: 'allocated dispatch riders',
                    tooltip: 'Combined field riders across all regional distribution stations',
                  ),
                  AdminMetricCard(
                    title: 'Vault Cash',
                    value: CurrencyFormatter.formatNaira(totalVaultNaira),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF10B981),
                    subtitle: 'pending bank remittance',
                    tooltip: 'Cash collected by riders awaiting daily settlement deposit into company bank',
                  ),
                  AdminMetricCard(
                    title: 'Vault Stock',
                    value: '$totalStock',
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    subtitle: 'stored merchant packages',
                    tooltip: 'Total physical product stock held across all warehouse staging shelves',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters & Actions
          AdminFilterHeader(
            searchHint: 'Search hub by name, code, state, supervisor...',
            searchValue: state.searchQuery,
            onSearchChanged: notifier.setSearchQuery,
            onClearSearch: () => notifier.setSearchQuery(''),
            actionButtonText: 'Create DC',
            actionButtonIcon: Icons.add_business_rounded,
            onActionButtonPressed: () => _openDCModal(context, ref),
            count: dcs.length,
            countLabel: 'DCs & Hubs',
          ),
          const SizedBox(height: 16),

          // High Density Data Table
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: dcs.isEmpty
                  ? _buildEmptyState(isDark)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 290),
                        child: DataTable(
                          horizontalMargin: 16,
                          columnSpacing: 20,
                          headingRowHeight: 46,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 56,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : const Color(0xFFF8FAFC),
                          ),
                          columns: [
                            DataColumn(
                              label: Row(
                                children: [
                                  Text('Distribution Center', style: _headerStyle(isDark)),
                                  const SizedBox(width: 4),
                                  const NovaInfoIcon(message: 'Hub designation code and operating center name'),
                                ],
                              ),
                            ),
                            DataColumn(
                              label: Text('Region / State', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Lead Supervisor', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Active Fleet', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Vault Cash', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Capacity', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Actions', style: _headerStyle(isDark)),
                              ),
                            ),
                          ],
                          rows: dcs.map((dc) {
                            return DataRow(
                              cells: [
                                // DC Name & Code
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: dc.isGrandDc
                                              ? AppColors.orange.withValues(alpha: 0.15)
                                              : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          dc.code,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: dc.isGrandDc ? AppColors.orange : const Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                dc.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (dc.isGrandDc) ...[
                                                const SizedBox(width: 6),
                                                const NovaTooltip(
                                                  message: 'Grand Central Headquarters Mega-Hub',
                                                  child: Icon(Icons.stars_rounded, size: 15, color: AppColors.orange),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            dc.address,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF64748B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Region / State
                                DataCell(
                                  Text(
                                    '${dc.city}, ${dc.state}',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                                  ),
                                ),

                                // Lead Supervisor
                                DataCell(
                                  Text(
                                    dc.supervisorName,
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                ),

                                // Fleet
                                DataCell(
                                  Row(
                                    children: [
                                      const Icon(Icons.two_wheeler_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 5),
                                      Text('${dc.activeRiders} Riders', style: GoogleFonts.jetBrainsMono(fontSize: 12)),
                                    ],
                                  ),
                                ),

                                // Vault Balance
                                DataCell(
                                  Text(
                                    CurrencyFormatter.formatNaira(dc.vaultBalance),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),

                                // Capacity Progress
                                DataCell(
                                  Text(
                                    '${dc.currentStockCount} / ${dc.capacity}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ),

                                // Actions
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF3B82F6)),
                                    onPressed: () => _openDCModal(context, ref, dc),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.hub_outlined, size: 40, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              'No distribution centers found',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDCModal(BuildContext context, WidgetRef ref, [AdminDistributionCenter? dc]) {
    final notifier = ref.read(adminConsoleProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AdminDCModal(
          initialDc: dc,
          onSave: notifier.saveDistributionCenter,
        );
      },
    );
  }
}
