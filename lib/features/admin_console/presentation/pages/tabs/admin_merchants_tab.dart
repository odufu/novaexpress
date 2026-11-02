import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_filter_header.dart';
import '../../widgets/admin_merchant_modal.dart';
import '../../widgets/admin_metric_card.dart';

class AdminMerchantsTab extends ConsumerWidget {
  const AdminMerchantsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final merchants = state.filteredMerchants;
    final totalMerchants = state.merchants.length;
    final enterpriseCount = state.merchants.where((m) => m.isEnterprise).length;
    final totalClosersAssigned = state.merchants.fold(0, (s, m) => s + m.closerCount);
    final totalRemittedNaira = state.merchants.fold(0.0, (s, m) => s + m.totalRemittedNaira);

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
                    title: 'Merchants',
                    value: '$totalMerchants',
                    icon: Icons.storefront_outlined,
                    iconColor: const Color(0xFF10B981),
                    subtitle: 'retail client partners',
                    tooltip: 'Active e-commerce stores warehousing inventory and dispatching orders with NovaXpress',
                  ),
                  AdminMetricCard(
                    title: 'Enterprise Accounts',
                    value: '$enterpriseCount',
                    icon: Icons.workspace_premium_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    subtitle: 'dedicated closer teams',
                    tooltip: 'High-volume merchants with allocated sales rep teams and custom warehousing SLAs',
                  ),
                  AdminMetricCard(
                    title: 'Telesales Closers',
                    value: '$totalClosersAssigned',
                    icon: Icons.support_agent_rounded,
                    iconColor: AppColors.orange,
                    subtitle: 'active lead confirmers',
                    tooltip: 'Dedicated closer sales representatives assigned across merchant accounts',
                  ),
                  AdminMetricCard(
                    title: 'Total Remitted',
                    value: CurrencyFormatter.formatNaira(totalRemittedNaira),
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    subtitle: 'T+1 bank settlements',
                    tooltip: 'Total cash-on-delivery payments remitted to merchant corporate accounts to date',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters & Actions
          AdminFilterHeader(
            searchHint: 'Search merchant by brand name, contact person, phone, email...',
            searchValue: state.searchQuery,
            onSearchChanged: notifier.setSearchQuery,
            onClearSearch: () => notifier.setSearchQuery(''),
            actionButtonText: 'Onboard Merchant',
            actionButtonIcon: Icons.add_business_rounded,
            onActionButtonPressed: () => _openMerchantModal(context, ref),
            count: merchants.length,
            countLabel: 'Merchants',
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
              child: merchants.isEmpty
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
                                  Text('Merchant Partner', style: _headerStyle(isDark)),
                                  const SizedBox(width: 4),
                                  const NovaInfoIcon(message: 'Brand trade name and primary contact officer'),
                                ],
                              ),
                            ),
                            DataColumn(
                              label: Text('Account Tier', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Closers', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('COD Settlement Bank', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Cycle', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Remitted', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Actions', style: _headerStyle(isDark)),
                              ),
                            ),
                          ],
                          rows: merchants.map((m) {
                            return DataRow(
                              cells: [
                                // Business & Contact
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        child: Text(
                                          m.businessName.isNotEmpty ? m.businessName[0].toUpperCase() : 'M',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            m.businessName,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            '${m.contactName} • ${m.phone}',
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

                                // Tier Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (m.isEnterprise ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m.tier,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: m.isEnterprise ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ),

                                // Closers count
                                DataCell(
                                  Text(
                                    '${m.closerCount} / ${m.closerLimit}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12),
                                  ),
                                ),

                                // Bank Account
                                DataCell(
                                  Row(
                                    children: [
                                      if (m.isBankVerified) ...[
                                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                                        const SizedBox(width: 5),
                                      ],
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            m.bankName.isNotEmpty ? m.bankName : 'Not Set',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          if (m.accountNumber.isNotEmpty)
                                            Text(
                                              m.accountNumber,
                                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Settlement Schedule
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m.settlementSchedule == 'daily_t1' ? 'Daily T+1' : 'Weekly',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ),

                                // Total Remitted
                                DataCell(
                                  Text(
                                    CurrencyFormatter.formatNaira(m.totalRemittedNaira),
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // Actions
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF3B82F6)),
                                    onPressed: () => _openMerchantModal(context, ref, m),
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
            Icon(Icons.storefront_outlined, size: 40, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              'No merchant records found',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _openMerchantModal(BuildContext context, WidgetRef ref, [AdminMerchant? m]) {
    final notifier = ref.read(adminConsoleProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AdminMerchantModal(
          initialMerchant: m,
          onSave: notifier.saveMerchant,
        );
      },
    );
  }
}
