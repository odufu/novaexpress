import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_metric_card.dart';

class AdminAuditLogsTab extends ConsumerWidget {
  const AdminAuditLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final logs = state.filteredAuditLogs;
    final allLogs = state.auditLogs;

    // Metrics calculation
    final totalCount = allLogs.length;
    final dcAdminCount = allLogs.where((l) {
      final r = l.actorRole.toLowerCase();
      return r.contains('dc_manager') || r.contains('dc_admin') || r.contains('supervisor');
    }).length;
    final userMgmtCount = allLogs.where((l) => l.action.contains('USER') || l.action.contains('ADMIN')).length;
    final financeCount = allLogs.where((l) {
      final a = l.action;
      return a.contains('REMIT') || a.contains('EXPENSE') || a.contains('EXPENDITURE') || a.contains('PAYOUT');
    }).length;

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
                    title: 'Audit Trail Events',
                    value: '$totalCount',
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    subtitle: 'immutable log records',
                    tooltip: 'Total security & operational actions logged across all distribution centers',
                  ),
                  AdminMetricCard(
                    title: 'DC Admin Actions',
                    value: '$dcAdminCount',
                    icon: Icons.apartment_rounded,
                    iconColor: AppColors.orange,
                    subtitle: 'by Hub Managers & Admins',
                    tooltip: 'Actions executed by General Distribution Managers and DC Supervisors',
                  ),
                  AdminMetricCard(
                    title: 'RBAC & User Provisioning',
                    value: '$userMgmtCount',
                    icon: Icons.person_add_alt_1_rounded,
                    iconColor: const Color(0xFF10B981),
                    subtitle: 'admin & officer creations',
                    tooltip: 'Account creation, role elevation, and permission modifications',
                  ),
                  AdminMetricCard(
                    title: 'Financial Audits',
                    value: '$financeCount',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    subtitle: 'remittances & expenses',
                    tooltip: 'Cash reconciliation, vault transfers, and expenditure disbursements',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters & Search Bar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: TextField(
                          onChanged: notifier.setSearchQuery,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by actor name, email, action, DC, or details...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: state.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () => notifier.setSearchQuery(''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Live status pill & count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            '${logs.length} Logged Events',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Multi-faceted Filter Dropdowns
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Role Filter
                    _buildFilterDropdown(
                      label: 'Actor Role',
                      value: state.auditLogRoleFilter,
                      icon: Icons.badge_outlined,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Operator Roles')),
                        DropdownMenuItem(value: 'dc_manager', child: Text('DC Admin / Manager')),
                        DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                        DropdownMenuItem(value: 'dc_operations', child: Text('Orders & Dispatch Admin')),
                        DropdownMenuItem(value: 'dc_stock_admin', child: Text('Stock & Inventory Admin')),
                        DropdownMenuItem(value: 'dc_finance_admin', child: Text('Station Finance Admin')),
                        DropdownMenuItem(value: 'general_accountant', child: Text('General Accountant')),
                        DropdownMenuItem(value: 'delivery_agent', child: Text('Delivery Agent / Rider')),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setAuditLogRoleFilter(val);
                      },
                    ),

                    // Action Category Filter
                    _buildFilterDropdown(
                      label: 'Action Category',
                      value: state.auditLogActionFilter,
                      icon: Icons.category_outlined,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Action Types')),
                        DropdownMenuItem(value: 'users', child: Text('User Management & Roles')),
                        DropdownMenuItem(value: 'finance', child: Text('Finance & Remittances')),
                        DropdownMenuItem(value: 'orders', child: Text('Orders & Dispatch')),
                        DropdownMenuItem(value: 'stock', child: Text('Stock & Inventory')),
                        DropdownMenuItem(value: 'policy', child: Text('System Policies & Tariffs')),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setAuditLogActionFilter(val);
                      },
                    ),

                    // Hub / DC Filter
                    _buildFilterDropdown(
                      label: 'Distribution Center',
                      value: state.auditLogHubFilter,
                      icon: Icons.warehouse_outlined,
                      isDark: isDark,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Distribution Centers')),
                        ...state.distributionCenters.map((dc) => DropdownMenuItem(
                              value: dc.id,
                              child: Text('${dc.name} (${dc.code})'),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setAuditLogHubFilter(val);
                      },
                    ),

                    // Date Filter
                    _buildFilterDropdown(
                      label: 'Time Horizon',
                      value: state.auditLogDateFilter,
                      icon: Icons.calendar_today_outlined,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Time')),
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(value: 'week', child: Text('Past 7 Days')),
                        DropdownMenuItem(value: 'month', child: Text('Past 30 Days')),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setAuditLogDateFilter(val);
                      },
                    ),

                    // Reset Filters Button if any filter active
                    if (state.auditLogRoleFilter != 'all' ||
                        state.auditLogActionFilter != 'all' ||
                        state.auditLogHubFilter != 'all' ||
                        state.auditLogDateFilter != 'all' ||
                        state.searchQuery.isNotEmpty)
                      InkWell(
                        onTap: () {
                          notifier.setSearchQuery('');
                          notifier.setAuditLogRoleFilter('all');
                          notifier.setAuditLogActionFilter('all');
                          notifier.setAuditLogHubFilter('all');
                          notifier.setAuditLogDateFilter('all');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text(
                                'Reset Filters',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Log Entries Container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: logs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: const Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            'No audit logs match your query',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your role, action, or date filters to expand the search results.',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final timeStr = DateFormat('dd MMM yyyy • HH:mm:ss').format(log.timestamp);
                      final actionColor = _getActionColor(log.action);
                      final roleBadge = _getRoleBadge(log.actorRole);

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action Icon Avatar
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: actionColor.withValues(alpha: 0.12),
                              child: Icon(_getActionIcon(log.action), size: 18, color: actionColor),
                            ),
                            const SizedBox(width: 14),

                            // Log Content Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Action Tag, Resource, DC Name, and Exact Time
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: actionColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          log.action,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: actionColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Resource Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          log.resource,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),

                                      // DC Hub Badge (if available)
                                      if (log.distributionCenterName != null && log.distributionCenterName!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.warehouse_rounded, size: 11, color: AppColors.orange),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.distributionCenterName!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFFD97706),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const Spacer(),

                                      // Exact Timing
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Action Description Text
                                  Text(
                                    log.details,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Actor Attribution Footer
                                  Row(
                                    children: [
                                      // Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleBadge.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          roleBadge.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: roleBadge.color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Actor: ',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                      ),
                                      Text(
                                        log.actorName,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        ' (${log.actorEmail})',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'IP: ${log.ipAddress}',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE_DC_ADMIN') || a.contains('CREATE_ADMIN_USER') || a.contains('CREATE') || a.contains('ONBOARD')) {
      return const Color(0xFF10B981);
    }
    if (a.contains('UPDATE') || a.contains('VERIFY') || a.contains('APPROVE')) {
      return const Color(0xFF3B82F6);
    }
    if (a.contains('SUSPEND') || a.contains('DELETE') || a.contains('REJECT')) {
      return const Color(0xFFEF4444);
    }
    if (a.contains('TRANSFER') || a.contains('DISPATCH') || a.contains('ORDER')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF8B5CF6);
  }

  IconData _getActionIcon(String action) {
    final a = action.toUpperCase();
    if (a.contains('DC_ADMIN') || a.contains('HUB')) return Icons.apartment_rounded;
    if (a.contains('USER') || a.contains('ADMIN')) return Icons.person_outline_rounded;
    if (a.contains('REMIT') || a.contains('EXPENSE') || a.contains('EXPENDITURE') || a.contains('PAYOUT')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (a.contains('ORDER') || a.contains('DISPATCH')) return Icons.local_shipping_rounded;
    if (a.contains('STOCK') || a.contains('TRANSFER')) return Icons.inventory_2_rounded;
    if (a.contains('POLICY') || a.contains('SETTINGS')) return Icons.tune_rounded;
    if (a.contains('TARIFF')) return Icons.price_change_outlined;
    return Icons.security_rounded;
  }

  _RoleBadgeData _getRoleBadge(String role) {
    final r = role.toLowerCase();
    if (r.contains('super_admin') || r.contains('admin')) {
      return _RoleBadgeData(label: 'SUPER ADMIN', color: const Color(0xFFE11D48));
    }
    if (r.contains('dc_manager') || r.contains('dc_admin') || r.contains('supervisor')) {
      return _RoleBadgeData(label: 'DC ADMIN', color: AppColors.orange);
    }
    if (r.contains('finance')) {
      return _RoleBadgeData(label: 'DC FINANCE', color: const Color(0xFFD97706));
    }
    if (r.contains('stock')) {
      return _RoleBadgeData(label: 'DC STOCK', color: const Color(0xFF0284C7));
    }
    if (r.contains('operations') || r.contains('ops')) {
      return _RoleBadgeData(label: 'DC OPS', color: const Color(0xFF059669));
    }
    if (r.contains('accountant')) {
      return _RoleBadgeData(label: 'ACCOUNTANT', color: const Color(0xFF7C3AED));
    }
    if (r.contains('delivery') || r.contains('rider')) {
      return _RoleBadgeData(label: 'RIDER', color: const Color(0xFF6366F1));
    }
    return _RoleBadgeData(label: role.toUpperCase(), color: const Color(0xFF64748B));
  }
}

class _RoleBadgeData {
  final String label;
  final Color color;
  const _RoleBadgeData({required this.label, required this.color});
}
