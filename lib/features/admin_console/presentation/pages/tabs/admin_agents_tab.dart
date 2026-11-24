import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_agent_detail_modal.dart';
import '../../widgets/admin_assign_agent_merchants_modal.dart';
import '../../widgets/admin_edit_agent_modal.dart';
import '../../widgets/admin_manage_agent_custody_modal.dart';
import '../../widgets/admin_metric_card.dart';

class AdminAgentsTab extends ConsumerWidget {
  const AdminAgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayedAgents = state.filteredAgents;
    final totalAgents = state.agents.length;
    final pendingCount = state.agents.where((a) => a.isPendingApproval).length;
    final totalFleet = state.agents.fold<int>(0, (sum, a) => sum + a.activeRidersCount);
    final totalUnitsHeld = displayedAgents.fold<int>(
      0,
      (sum, a) => sum + a.heldStock.values.fold<int>(0, (s, q) => s + q),
    );

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards (Top)
          // 1. Sleek, high-density Metrics Header (Compact ribbon by default, expandable to cards)
          AdminMetricsHeader(
            metrics: [
              AdminMetricData(
                title: 'Total Agents & 3PLs',
                value: '$totalAgents',
                icon: Icons.local_shipping_outlined,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'registered logistics partners',
                tooltip:
                    'External 3PL companies and internal fleet agents registered on NovaXpress',
              ),
              AdminMetricData(
                title: 'Stock in Agent Custody',
                value: '$totalUnitsHeld units',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.orange,
                subtitle: 'in partner custody',
                tooltip:
                    'Total merchant products currently held by operating agents across Nigeria',
              ),
              AdminMetricData(
                title: 'Active Fleet Couriers',
                value: '$totalFleet couriers',
                icon: Icons.two_wheeler_rounded,
                iconColor: const Color(0xFF10B981),
                subtitle: 'dispatch authorized',
                tooltip:
                    'Combined field courier personnel managed across partner agents',
              ),
              AdminMetricData(
                title: 'Pending Approvals',
                value: '$pendingCount',
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFFF59E0B),
                subtitle: 'awaiting verification',
                tooltip:
                    'New logistics companies requiring NovaXpress board authorization before go-live',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Pending Approvals Banner
          if (state.pendingApprovalAgents.isNotEmpty) ...[
            _buildPendingApprovalBanner(context, state, isDark, notifier),
            const SizedBox(height: 12),
          ],

          // 3. Data Representation: DataTable on Desktop (with filters in heading), Cards on Mobile
          if (isDesktop)
            _buildDesktopAgentsDataTable(
                context, ref, displayedAgents, isDark, notifier)
          else ...[
            _buildMobileFilterAndActionBar(context, ref, state, notifier, isDark),
            const SizedBox(height: 12),
            _buildMobileAgentsCardList(
                context, ref, displayedAgents, isDark, notifier),
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
                '${state.pendingApprovalAgents.length} PENDING AGENT AUTHORIZATIONS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...state.pendingApprovalAgents.map((agent) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPendingAgentCard(context, agent, isDark, notifier),
            )),
      ],
    );
  }

  Widget _buildPendingAgentCard(
    BuildContext context,
    AdminLogisticsAgent agent,
    bool isDark,
    AdminConsoleNotifier notifier,
  ) {
    return Container(
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
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  '${agent.typeLabel} • Hub: ${agent.assignedWarehouseName ?? "Central"} • Delivery Fee: ${CurrencyFormatter.formatNaira(agent.deliveryFee)}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => notifier.suspendAgent(agent.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Decline', style: TextStyle(fontSize: 11.5)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => notifier.approveAgent(agent.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: const Text('Approve Agent', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          // Left: Filter criteria
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Merchant Filter (CRUCIAL: See which agents a merchant is using!)
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  value: state.agentMerchantFilter,
                  decoration: _filterInputDeco('Filter by Merchant Usage', Icons.storefront_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Merchants (All Agents)')),
                    ...state.merchants.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.businessName} Agents', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setAgentMerchantFilter(val);
                  },
                ),
              ),

              // Hub / Distribution Center Filter
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  value: state.agentHubFilter,
                  decoration: _filterInputDeco('Distribution Center', Icons.hub_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Distribution Centers')),
                    DropdownMenuItem(value: 'DC-ABJ-01', child: Text('Abuja Central DC')),
                    DropdownMenuItem(value: 'DC-LAG-01', child: Text('Lagos Central DC')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setAgentHubFilter(val);
                  },
                ),
              ),

              // Status Filter
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: state.agentStatusFilter,
                  decoration: _filterInputDeco('Agent Status', Icons.toggle_on_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active Only')),
                    DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setAgentStatusFilter(val);
                  },
                ),
              ),

              // Search Box
              SizedBox(
                width: 180,
                child: TextField(
                  onChanged: notifier.setSearchQuery,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search Agent / Code...',
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

          // Right: Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                label: const Text('Agent Daily Sales'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.push('/agent-daily-sales'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                label: const Text('Register Agent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openRegisterAgentModal(context, ref, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAgentsDataTable(
    BuildContext context,
    WidgetRef ref,
    List<AdminLogisticsAgent> agents,
    bool isDark,
    AdminConsoleNotifier notifier,
  ) {
    final state = ref.watch(adminConsoleProvider);

    final columns = <ExcelColumnDef<AdminLogisticsAgent>>[
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'agent',
        label: 'Logistics Agent & Code',
        defaultWidth: 240,
        minWidth: 190,
        sortValue: (a) => a.name,
        searchString: (a) => '${a.name} ${a.agentCode}',
        cellBuilder: (ctx, agent, idx, dark, primary) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      agent.name,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${agent.agentCode} • ${agent.typeLabel}',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'hub',
        label: 'Assigned Hub',
        defaultWidth: 180,
        minWidth: 140,
        sortValue: (a) => a.assignedWarehouseName ?? '',
        cellBuilder: (ctx, a, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a.assignedWarehouseName ?? 'Central Command',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'merchants',
        label: 'Merchants Served',
        defaultWidth: 180,
        minWidth: 140,
        cellBuilder: (ctx, a, idx, dark, primary) {
          final displayNames = <String>[];
          for (final name in a.assignedMerchantNames) {
            final t = name.trim();
            if (t.isNotEmpty && !displayNames.contains(t)) {
              displayNames.add(t);
            }
          }
          for (final m in state.merchants) {
            final bLower = m.businessName.toLowerCase();
            final matches = a.assignedMerchantIds.contains(m.id) ||
                m.assignedAgentIds.contains(a.id) ||
                (bLower.contains('nova') && a.assignedMerchantIds.any((id) => id.contains('novacare'))) ||
                ((bLower.contains('shop') || bLower.contains('eleven')) &&
                    a.assignedMerchantIds.any((id) => id.contains('shop11') || id.contains('shopeleven'))) ||
                (bLower.contains('leafora') && a.assignedMerchantIds.any((id) => id.contains('leafora')));
            if (matches && !displayNames.contains(m.businessName)) {
              displayNames.add(m.businessName);
            }
          }

          if (displayNames.isEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _openAssignMerchantsModal(context, ref, a, dark),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_link_rounded, size: 13, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        'Assign Merchants',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF8B5CF6),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _openAssignMerchantsModal(context, ref, a, dark),
              borderRadius: BorderRadius.circular(4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: displayNames.map((name) {
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'total_held',
        label: 'Held Custody',
        defaultWidth: 110,
        minWidth: 90,
        align: TextAlign.center,
        sortValue: (a) => a.heldStock.values.fold<int>(0, (s, q) => s + q),
        cellBuilder: (ctx, a, idx, dark, primary) {
          final total = a.heldStock.values.fold<int>(0, (s, q) => s + q);
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$total units',
                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFC2410C)),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'products_breakdown',
        label: 'Products Held ("What They Are With")',
        defaultWidth: 260,
        minWidth: 200,
        cellBuilder: (ctx, a, idx, dark, primary) {
          if (a.heldStock.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('No stock in custody', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: a.heldStock.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${e.key.split(' ').first}: ${e.value}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'delivery_fee',
        label: 'Delivery Fee',
        defaultWidth: 105,
        minWidth: 85,
        align: TextAlign.right,
        sortValue: (a) => a.deliveryFee,
        cellBuilder: (ctx, a, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(a.deliveryFee),
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'failed_fee',
        label: 'Failed Fee',
        defaultWidth: 100,
        minWidth: 80,
        align: TextAlign.right,
        sortValue: (a) => a.failedDeliveryFee,
        cellBuilder: (ctx, a, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(a.failedDeliveryFee),
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFFEF4444)),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'commission',
        label: 'Commission',
        defaultWidth: 95,
        minWidth: 75,
        align: TextAlign.right,
        sortValue: (a) => a.commissionRate,
        cellBuilder: (ctx, a, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${a.commissionRate.toStringAsFixed(1)}%',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'daily_balance',
        label: 'Daily Balancing',
        defaultWidth: 130,
        minWidth: 110,
        cellBuilder: (ctx, a, idx, dark, primary) {
          final isBalanced = a.lastBalancedAt != null && DateTime.now().difference(a.lastBalancedAt!).inHours < 24;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isBalanced ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isBalanced ? 'Balanced Today' : 'Pending Audit',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isBalanced ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'status',
        label: 'Status',
        defaultWidth: 100,
        minWidth: 80,
        cellBuilder: (ctx, a, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: a.isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                a.status.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: a.isActive ? const Color(0xFF059669) : const Color(0xFFEF4444),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<AdminLogisticsAgent>(
        key: 'actions',
        label: 'Stock Actions',
        defaultWidth: 260,
        minWidth: 210,
        cellBuilder: (ctx, a, idx, dark, primary) {
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
                    tooltip: 'Edit Agent & Fees',
                    onPressed: () => _openEditAgentModal(context, ref, a, dark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.hub_outlined, size: 17, color: Color(0xFF8B5CF6)),
                    tooltip: 'Assign / Unassign Merchants',
                    onPressed: () => _openAssignMerchantsModal(context, ref, a, dark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.inventory_2_outlined, size: 17, color: Color(0xFFF97316)),
                    tooltip: 'Assign / Manage Stock Custody',
                    onPressed: () {
                      AdminManageAgentCustodyModal.show(
                        context: context,
                        agent: a,
                        catalogProducts: state.globalStock,
                      );
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _openDailyBalancingModal(context, ref, a, dark),
                    child: const Text('Log Daily Balancing'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFFF97316)),
                    tooltip: 'Ambush Audit (±5% check)',
                    onPressed: () => _openAmbushAuditModal(context, ref, a, dark),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                    tooltip: 'Permanently remove logistics partner',
                    onPressed: () => _confirmDeleteAgent(context, ref, a),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];

    final topToolbarActions = <Widget>[
      // 1. Merchant Filter
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
            Icon(Icons.storefront_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.agentMerchantFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Merchants')),
                  ...state.merchants.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text('${m.businessName} Agents'),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setAgentMerchantFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 2. Hub / DC Filter
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
            Icon(Icons.hub_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.agentHubFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Distribution Centers')),
                  DropdownMenuItem(value: 'DC-ABJ-01', child: Text('Abuja Central DC')),
                  DropdownMenuItem(value: 'DC-LAG-01', child: Text('Lagos Central DC')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setAgentHubFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 3. Status Filter
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
                value: state.agentStatusFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active Only')),
                  DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setAgentStatusFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 4. Compact Search Box
      SizedBox(
        width: 180,
        height: 32,
        child: TextField(
          onChanged: notifier.setSearchQuery,
          style: GoogleFonts.inter(fontSize: 11.5),
          decoration: InputDecoration(
            hintText: 'Search Agent, Phone...',
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

      // 5. Onboard Agent Button
      ElevatedButton.icon(
        icon: const Icon(Icons.person_add_rounded, size: 13),
        label: const Text('Add Logistics Partner'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openRegisterAgentModal(context, ref, isDark),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: PangeaExcelDataTable<AdminLogisticsAgent>(
        items: agents,
        columns: columns,
        brandPrimary: const Color(0xFF0284C7),
        tableHeight: 660,
        initialPageSize: 15,
        topToolbarActions: topToolbarActions,
        onRowTap: (agent) {
          AdminAgentDetailModal.show(
            context: context,
            agent: agent,
            onManageCustody: () {
              AdminManageAgentCustodyModal.show(
                context: context,
                agent: agent,
                catalogProducts: state.globalStock,
              );
            },
            onAssignMerchants: () {
              showDialog(
                context: context,
                builder: (c) => AdminAssignAgentMerchantsModal(
                  agent: agent,
                  availableMerchants: state.merchants,
                  onSave: (updatedMerchantIds, updatedMerchantNames) {
                    notifier.assignAgentToMerchants(
                      agentId: agent.id,
                      merchantIds: updatedMerchantIds,
                      merchantNames: updatedMerchantNames,
                    );
                  },
                ),
              );
            },
            onEditAgent: () {
              showDialog(
                context: context,
                builder: (c) => AdminEditAgentModal(
                  agent: agent,
                  availableMerchants: state.merchants,
                  onSave: notifier.updateLogisticsAgent,
                ),
              );
            },
            onToggleStatus: () {
              notifier.toggleAgentStatus(agent.id);
            },
          );
        },
        emptyMessage: 'No logistics agents match the selected merchant or hub filter criteria.',
      ),
    );
  }

  Widget _buildMobileAgentsCardList(
    BuildContext context,
    WidgetRef ref,
    List<AdminLogisticsAgent> agents,
    bool isDark,
    AdminConsoleNotifier notifier,
  ) {
    if (agents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No agents match the active filter criteria.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: agents.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agent = agents[index];
        final totalUnits = agent.heldStock.values.fold<int>(0, (s, q) => s + q);

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
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, size: 18, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agent.name, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        Text('${agent.agentCode} • ${agent.assignedWarehouseName ?? "Central"}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text('$totalUnits units', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Fee: ${CurrencyFormatter.formatNaira(agent.deliveryFee)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF10B981))),
                  Text('Failed: ${CurrencyFormatter.formatNaira(agent.failedDeliveryFee)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFFEF4444))),
                  Text('Comm: ${agent.commissionRate.toStringAsFixed(1)}%', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF8B5CF6))),
                ],
              ),
              if (agent.assignedMerchantNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: agent.assignedMerchantNames.map((mName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mName,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED)),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Edit Agent & Fees'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: GoogleFonts.inter(fontSize: 11),
                    ),
                    onPressed: () => _openEditAgentModal(context, ref, agent, isDark),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.hub_outlined, size: 14),
                    label: const Text('Merchants'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: GoogleFonts.inter(fontSize: 11),
                    ),
                    onPressed: () => _openAssignMerchantsModal(context, ref, agent, isDark),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined, size: 14),
                    label: const Text('Stock Custody'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: GoogleFonts.inter(fontSize: 11),
                    ),
                    onPressed: () {
                      final globalStock = ref.read(adminConsoleProvider).globalStock;
                      AdminManageAgentCustodyModal.show(
                        context: context,
                        agent: agent,
                        catalogProducts: globalStock,
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.search_rounded, size: 14),
                    label: const Text('Ambush Audit'),
                    onPressed: () => _openAmbushAuditModal(context, ref, agent, isDark),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.balance_rounded, size: 14),
                    label: const Text('Balancing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _openDailyBalancingModal(context, ref, agent, isDark),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: GoogleFonts.inter(fontSize: 11),
                    ),
                    onPressed: () => _confirmDeleteAgent(context, ref, agent),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAgent(BuildContext context, WidgetRef ref, AdminLogisticsAgent agent) async {
    final currentUser = ref.read(authProvider).user;
    final totalUnitsHeld = agent.heldStock.values.fold<int>(0, (s, q) => s + q);
    final confirmed = await NovaCriticalActionConfirmationModal.show(
      context: context,
      actionName: 'Permanently Remove Logistics Partner',
      isDestructive: true,
      operatorAccount: currentUser?.email ?? 'operations@novaxpress.ng',
      promptMessage:
          'Are you sure you want to permanently delete this logistics partner/rider from the database? If they are holding active custody, stock reconciliation must be verified.',
      valuesets: {
        'Agent Name': agent.name,
        'Agent Code': agent.agentCode,
        'Operating Hub': agent.assignedWarehouseName ?? '—',
        'Merchant Coverage': agent.assignedMerchantNames.join(', '),
        'Held Physical Stock': '$totalUnitsHeld units',
      },
    );

    if (confirmed) {
      final ok = await ref.read(adminConsoleProvider.notifier).deleteLogisticsAgent(agent.id, agent.agentCode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Logistics partner ${agent.name} (${agent.agentCode}) permanently removed.'
                  : 'Removed partner locally; database sync logged.',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _openEditAgentModal(
    BuildContext context,
    WidgetRef ref,
    AdminLogisticsAgent agent,
    bool isDark,
  ) {
    final state = ref.read(adminConsoleProvider);
    showDialog(
      context: context,
      builder: (ctx) => AdminEditAgentModal(
        agent: agent,
        availableMerchants: state.merchants,
        onSave: (updated) {
          ref.read(adminConsoleProvider.notifier).updateLogisticsAgent(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agent "${updated.name}" updated successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _openAssignMerchantsModal(
    BuildContext context,
    WidgetRef ref,
    AdminLogisticsAgent agent,
    bool isDark,
  ) {
    final state = ref.read(adminConsoleProvider);
    showDialog(
      context: context,
      builder: (ctx) => AdminAssignAgentMerchantsModal(
        agent: agent,
        availableMerchants: state.merchants,
        onSave: (merchantIds, merchantNames) {
          ref.read(adminConsoleProvider.notifier).assignAgentToMerchants(
                agentId: agent.id,
                merchantIds: merchantIds,
                merchantNames: merchantNames,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated merchant assignments for "${agent.name}".'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _openAmbushAuditModal(
    BuildContext context,
    WidgetRef ref,
    AdminLogisticsAgent agent,
    bool isDark,
  ) {
    final controllers = <String, TextEditingController>{};
    agent.heldStock.forEach((prod, qty) {
      controllers[prod] = TextEditingController(text: '$qty');
    });

    final auditorNameCtrl = TextEditingController(text: 'Board Contract Auditor');
    final auditNotesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.security_update_warning_rounded, color: Color(0xFFF97316), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Random Ambush Stock Audit: ${agent.name}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
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
                        'Unannounced physical count verification on agent custody. Compared against live CRM numbers with strict ±5% tolerance threshold.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: auditorNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Auditor Name / Contract Firm',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Product Physical Count vs CRM Live Custody:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (controllers.isEmpty)
                        Text('No products currently assigned to agent.', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic))
                      else
                        ...controllers.entries.map((e) {
                          final crmQty = agent.heldStock[e.key] ?? 0;
                          final physical = int.tryParse(e.value.text) ?? crmQty;
                          final diff = physical - crmQty;
                          final pct = crmQty > 0 ? (diff.abs() / crmQty) * 100 : 0.0;
                          final isWithinTolerance = pct <= 5.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('CRM Custody: $crmQty units', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isWithinTolerance ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isWithinTolerance ? 'PASS (±${pct.toStringAsFixed(1)}%)' : 'INVESTIGATE (${diff > 0 ? "+$diff" : diff})',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isWithinTolerance ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: e.value,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setModalState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Count',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: auditNotesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Discrepancy explanation or forensic investigation notes...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
                  onPressed: () {
                    final confirmed = <String, int>{};
                    controllers.forEach((k, v) {
                      confirmed[k] = int.tryParse(v.text) ?? (agent.heldStock[k] ?? 0);
                    });

                    ref.read(adminConsoleProvider.notifier).recordAgentDailyBalance(
                          agentId: agent.id,
                          confirmedStock: confirmed,
                          notes: '[AMBUSH AUDIT by ${auditorNameCtrl.text}] ${auditNotesCtrl.text}',
                        );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ambush stock audit logged to Board Investigation Ledger.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  child: const Text('Submit Audit to Board'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDailyBalancingModal(
    BuildContext context,
    WidgetRef ref,
    AdminLogisticsAgent agent,
    bool isDark,
  ) {
    final controllers = <String, TextEditingController>{};
    agent.heldStock.forEach((prodName, qty) {
      controllers[prodName] = TextEditingController(text: '$qty');
    });

    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.balance_rounded, color: Color(0xFF0284C7), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Daily Stock Balancing: ${agent.name}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record confirmed physical stock count held by ${agent.name} after close of business (on or before 10:00 PM). This updates live custody network-wide.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 16),
                if (controllers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('No active products currently assigned to this agent.', style: GoogleFonts.inter(fontSize: 12)),
                  )
                else
                  ...controllers.entries.map((e) {
                    final currentQty = agent.heldStock[e.key] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.key, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                Text('System registered custody: $currentQty units', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: e.value,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Count',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Balancing observations / recount remarks...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () async {
              final confirmed = <String, int>{};
              controllers.forEach((k, v) {
                confirmed[k] = int.tryParse(v.text) ?? (agent.heldStock[k] ?? 0);
              });

              final res = await ref.read(adminConsoleProvider.notifier).recordAgentDailyBalance(
                    agentId: agent.id,
                    confirmedStock: confirmed,
                    notes: notesCtrl.text.trim(),
                  );

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Daily balancing saved successfully.'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            child: const Text('Save & Sync Platform Stock'),
          ),
        ],
      ),
    );
  }

  void _openRegisterAgentModal(BuildContext context, WidgetRef ref, bool isDark) {
    final state = ref.read(adminConsoleProvider);
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deliveryFeeCtrl = TextEditingController(text: '2500');
    final failedFeeCtrl = TextEditingController(text: '1000');
    final commissionRateCtrl = TextEditingController(text: '5.0');
    final statesCtrl = TextEditingController(text: 'Abuja (FCT), Niger, Nasarawa');
    String agentType = '3pl_partner';
    String warehouseId = 'DC-ABJ-01';
    String warehouseName = 'Abuja Central DC';
    final selectedMerchantIds = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 8),
                Text('Register Logistics Agent', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Agent / Company Name *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(labelText: 'Code * (e.g. AD-3PL-01)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: agentType,
                            decoration: const InputDecoration(labelText: 'Agent Type'),
                            items: const [
                              DropdownMenuItem(value: '3pl_partner', child: Text('3PL Partner')),
                              DropdownMenuItem(value: 'internal_logistics', child: Text('Internal Fleet')),
                              DropdownMenuItem(value: 'distributor_agent', child: Text('Regional Distributor')),
                              DropdownMenuItem(value: 'rider_agent', child: Text('Rider Courier Agent')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => agentType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: contactCtrl,
                            decoration: const InputDecoration(labelText: 'Contact Person *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone Number *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Dispatch Email *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: deliveryFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Delivery Fee (₦) *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: failedFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Failed Fee (₦) *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: commissionRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Commission (%) *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: warehouseId,
                      decoration: const InputDecoration(labelText: 'Managing Distribution Center *'),
                      items: const [
                        DropdownMenuItem(value: 'DC-ABJ-01', child: Text('Abuja Central DC')),
                        DropdownMenuItem(value: 'DC-LAG-01', child: Text('Lagos Central DC')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            warehouseId = val;
                            if (val == 'DC-ABJ-01') {
                              warehouseName = 'Abuja Central DC';
                              if (statesCtrl.text == 'Lagos, Ogun, Osun') {
                                statesCtrl.text = 'Abuja (FCT), Niger, Nasarawa';
                              }
                            } else {
                              warehouseName = 'Lagos Central DC';
                              if (statesCtrl.text == 'Abuja (FCT), Niger, Nasarawa') {
                                statesCtrl.text = 'Lagos, Ogun, Osun';
                              }
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: statesCtrl,
                      decoration: const InputDecoration(labelText: 'Coverage States (comma separated)'),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assign Initial Merchants / Partners:',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: state.merchants.map((merchant) {
                          final isChecked = selectedMerchantIds.contains(merchant.id);
                          return CheckboxListTile(
                            value: isChecked,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(merchant.businessName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text('Tier: ${merchant.tier}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedMerchantIds.add(merchant.id);
                                } else {
                                  selectedMerchantIds.remove(merchant.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
                  final selectedMerchantNames = state.merchants
                      .where((m) => selectedMerchantIds.contains(m.id))
                      .map((m) => m.businessName)
                      .toList();

                  ref.read(adminConsoleProvider.notifier).registerLogisticsAgent(
                        name: nameCtrl.text.trim(),
                        agentCode: codeCtrl.text.trim(),
                        type: agentType,
                        contactPerson: contactCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        deliveryFee: double.tryParse(deliveryFeeCtrl.text) ?? 2500.0,
                        failedDeliveryFee: double.tryParse(failedFeeCtrl.text) ?? 1000.0,
                        commissionRate: double.tryParse(commissionRateCtrl.text) ?? 5.0,
                        assignedWarehouseId: warehouseId,
                        assignedWarehouseName: warehouseName,
                        assignedMerchantIds: selectedMerchantIds,
                        assignedMerchantNames: selectedMerchantNames,
                        coverageStates: statesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Register Agent'),
              ),
            ],
          );
        },
      ),
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
