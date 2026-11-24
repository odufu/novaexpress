import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_merchant_detail_modal.dart';
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

    final displayedMerchants = state.filteredMerchants;
    final totalMerchants = state.merchants.length;
    final enterpriseCount = state.merchants.where((m) => m.isEnterprise).length;
    final totalClosersAssigned = state.merchants.fold(0, (s, m) => s + m.closerCount);
    final totalRemittedNaira = state.merchants.fold(0.0, (s, m) => s + m.totalRemittedNaira);

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek, high-density Metrics Header (Compact ribbon by default, expandable to cards)
          AdminMetricsHeader(
            metrics: [
              AdminMetricData(
                title: 'Merchants',
                value: '$totalMerchants',
                icon: Icons.storefront_outlined,
                iconColor: const Color(0xFF10B981),
                subtitle: 'retail client partners',
                tooltip:
                    'Active e-commerce stores warehousing inventory and dispatching orders with NovaXpress',
              ),
              AdminMetricData(
                title: 'Enterprise Accounts',
                value: '$enterpriseCount',
                icon: Icons.workspace_premium_outlined,
                iconColor: const Color(0xFF8B5CF6),
                subtitle: 'dedicated closer teams',
                tooltip:
                    'High-volume merchants with allocated sales rep teams and custom warehousing SLAs',
              ),
              AdminMetricData(
                title: 'Telesales Closers',
                value: '$totalClosersAssigned',
                icon: Icons.support_agent_rounded,
                iconColor: AppColors.orange,
                subtitle: 'active lead confirmers',
                tooltip:
                    'Dedicated closer sales representatives assigned across merchant accounts',
              ),
              AdminMetricData(
                title: 'Total Remitted',
                value: CurrencyFormatter.formatNaira(totalRemittedNaira),
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'T+1 bank settlements',
                tooltip:
                    'Total cash-on-delivery payments remitted to merchant corporate accounts to date',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Pending Approvals Queue
          if (state.pendingApprovalMerchants.isNotEmpty) ...[
            _buildPendingApprovalBanner(context, state, isDark, notifier),
            const SizedBox(height: 12),
          ],

          // 3. Data Representation: DataTable on Desktop (with filters in heading), Cards on Mobile
          if (isDesktop)
            _buildDesktopMerchantsDataTable(
                context, ref, state, notifier, displayedMerchants, isDark)
          else ...[
            _buildMobileFilterAndActionBar(context, ref, state, notifier, isDark),
            const SizedBox(height: 12),
            _buildMobileMerchantsCardList(
                context, ref, displayedMerchants, isDark, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingApprovalBanner(
    BuildContext context,
    AdminConsoleState state,
    bool isDark,
    AdminConsoleNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${state.pendingApprovalMerchants.length} PENDING VERIFICATION',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('New Merchant Approval Gate', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ...state.pendingApprovalMerchants.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.businessName, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        Text('Contact: ${m.contactName} (${m.phone}) • Tier: ${m.tier}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => notifier.rejectMerchant(m.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Decline', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => notifier.approveMerchant(m.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: const Text('Approve Merchant', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildMobileFilterAndActionBar(
    BuildContext context,
    WidgetRef ref,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Tier Filter
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: state.merchantTierFilter,
                  decoration: _filterInputDeco('Merchant Tier', Icons.workspace_premium_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setMerchantTierFilter(val);
                  },
                ),
              ),

              // Status Filter
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: state.statusFilter,
                  decoration: _filterInputDeco('Account Status', Icons.toggle_on_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setStatusFilter(val);
                  },
                ),
              ),

              // Search Box
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: notifier.setSearchQuery,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search Merchant / Contact...',
                    hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Action: Onboard Merchant
          ElevatedButton.icon(
            icon: const Icon(Icons.add_business_rounded, size: 15),
            label: const Text('Onboard Merchant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AdminMerchantModal(
                  onSave: notifier.saveMerchant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMerchantsDataTable(
    BuildContext context,
    WidgetRef ref,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    List<AdminMerchant> merchants,
    bool isDark,
  ) {
    final columns = <ExcelColumnDef<AdminMerchant>>[
      ExcelColumnDef<AdminMerchant>(
        key: 'merchant',
        label: 'Merchant Business',
        defaultWidth: 230,
        minWidth: 180,
        sortValue: (m) => m.businessName,
        searchString: (m) => '${m.businessName} ${m.contactName}',
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.businessName,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${m.contactName} • ${m.phone}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'tier',
        label: 'Tier',
        defaultWidth: 110,
        minWidth: 90,
        align: TextAlign.center,
        sortValue: (m) => m.tier,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: m.isEnterprise ? const Color(0xFF8B5CF6).withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                m.tier,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: m.isEnterprise ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'products',
        label: 'Products Distributed',
        defaultWidth: 200,
        minWidth: 160,
        cellBuilder: (ctx, m, idx, dark, primary) {
          if (m.productsDistributed.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('All Catalog', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: m.productsDistributed.map((p) {
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      p.split(' ').first,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'chosen_agents',
        label: 'Chosen Logistics Agents',
        defaultWidth: 220,
        minWidth: 170,
        cellBuilder: (ctx, m, idx, dark, primary) {
          if (m.assignedAgentNames.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('All Available', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: m.assignedAgentNames.map((a) {
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      a.split(' ').first,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFEA580C)),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'active_orders',
        label: 'Active Orders',
        defaultWidth: 105,
        minWidth: 85,
        align: TextAlign.center,
        sortValue: (m) => m.activeOrdersCount,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Center(
            child: Text(
              '${m.activeOrdersCount}',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'today_gross_cod',
        label: 'Today Gross COD',
        defaultWidth: 125,
        minWidth: 100,
        align: TextAlign.right,
        sortValue: (m) => m.todayGrossCod,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(m.todayGrossCod),
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'today_fees',
        label: 'Delivery Fees',
        defaultWidth: 110,
        minWidth: 90,
        align: TextAlign.right,
        sortValue: (m) => m.todayDeliveryFees,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(m.todayDeliveryFees),
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFFEF4444)),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'today_net',
        label: 'Net Remittance',
        defaultWidth: 130,
        minWidth: 105,
        align: TextAlign.right,
        sortValue: (m) => m.todayNetRemittance,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                CurrencyFormatter.formatNaira(m.todayNetRemittance),
                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'status',
        label: 'Status',
        defaultWidth: 100,
        minWidth: 80,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: m.isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.status.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: m.isActive ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminMerchant>(
        key: 'actions',
        label: 'Actions',
        defaultWidth: 120,
        minWidth: 100,
        cellBuilder: (ctx, m, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF0284C7)),
                    tooltip: 'Edit Merchant Profile',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => AdminMerchantModal(
                          initialMerchant: m,
                          onSave: notifier.saveMerchant,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF64748B)),
                    tooltip: 'Filter Global Stock for ${m.businessName}',
                    onPressed: () {
                      notifier.setStockMerchantFilter(m.id);
                      notifier.setActiveTab(1); // Jump to Stock tab
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];

    final topToolbarActions = <Widget>[
      // 1. Tier Filter
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.merchantTierFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                  DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setMerchantTierFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 2. Status Filter
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.toggle_on_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.statusFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setStatusFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 3. Compact Search Box
      SizedBox(
        width: 180,
        height: 32,
        child: TextField(
          onChanged: notifier.setSearchQuery,
          style: GoogleFonts.inter(fontSize: 11.5),
          decoration: InputDecoration(
            hintText: 'Search Merchant / Contact...',
            hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
            prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ),

      // 4. Onboard Merchant Button
      ElevatedButton.icon(
        icon: const Icon(Icons.add_business_rounded, size: 13),
        label: const Text('Onboard Merchant'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AdminMerchantModal(
              onSave: notifier.saveMerchant,
            ),
          );
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: PangeaExcelDataTable<AdminMerchant>(
        items: merchants,
        columns: columns,
        brandPrimary: const Color(0xFF10B981),
        tableHeight: 620,
        topToolbarActions: topToolbarActions,
        onRowTap: (merchant) {
          AdminMerchantDetailModal.show(
            context: context,
            merchant: merchant,
            onEditMerchant: () {
              showDialog(
                context: context,
                builder: (c) => AdminMerchantModal(
                  initialMerchant: merchant,
                  onSave: notifier.saveMerchant,
                ),
              );
            },
            onViewStock: () {
              notifier.setActiveTab(1); // Jump to Multi-Hub Stock tab
            },
          );
        },
        emptyMessage: 'No merchants match the selected filter criteria.',
      ),
    );
  }

  Widget _buildMobileMerchantsCardList(
    BuildContext context,
    WidgetRef ref,
    List<AdminMerchant> merchants,
    bool isDark,
    AdminConsoleNotifier notifier,
  ) {
    if (merchants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No merchants match the active criteria.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: merchants.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = merchants[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.businessName, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        Text('${m.contactName} • ${m.phone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.isEnterprise ? const Color(0xFF8B5CF6).withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      m.tier,
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: m.isEnterprise ? const Color(0xFF7C3AED) : const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Today COD: ${CurrencyFormatter.formatNaira(m.todayGrossCod)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF10B981))),
                  Text('Net: ${CurrencyFormatter.formatNaira(m.todayNetRemittance)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined, size: 14),
                    label: const Text('View Stock'),
                    onPressed: () {
                      notifier.setStockMerchantFilter(m.id);
                      notifier.setActiveTab(1);
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Edit'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => AdminMerchantModal(initialMerchant: m, onSave: notifier.saveMerchant),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _filterInputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }
}
