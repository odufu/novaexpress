import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_filter_header.dart';
import '../../widgets/admin_metric_card.dart';
import '../../widgets/admin_user_modal.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final users = state.filteredUsers;
    final totalUsers = state.users.length;
    final activeUsers = state.users.where((u) => u.isActive).length;
    final dcStaff = state.users.where((u) => u.role.startsWith('dc_')).length;
    final riders = state.users.where((u) => u.role == 'delivery_agent').length;

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
                    title: 'Total Users',
                    value: '$totalUsers',
                    icon: Icons.people_alt_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    subtitle: 'registered personnel',
                    tooltip: 'Total registered accounts across all operational branches',
                  ),
                  AdminMetricCard(
                    title: 'Active Now',
                    value: '$activeUsers',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    subtitle: 'in good standing',
                    tooltip: 'Users currently granted access without suspension locks',
                  ),
                  AdminMetricCard(
                    title: 'DC Operations',
                    value: '$dcStaff',
                    icon: Icons.warehouse_outlined,
                    iconColor: AppColors.orange,
                    subtitle: 'hub supervisors & officers',
                    tooltip: 'Distribution Center managers, stock admins, and finance officers',
                  ),
                  AdminMetricCard(
                    title: 'Field Fleet',
                    value: '$riders',
                    icon: Icons.two_wheeler_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    subtitle: 'PDAs & company riders',
                    tooltip: 'Last-mile dispatch agents assigned across regional hubs',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters & Actions
          AdminFilterHeader(
            searchHint: 'Search users by name, email, phone, code...',
            searchValue: state.searchQuery,
            onSearchChanged: notifier.setSearchQuery,
            onClearSearch: () => notifier.setSearchQuery(''),
            actionButtonText: 'New User',
            actionButtonIcon: Icons.person_add_rounded,
            onActionButtonPressed: () => _openUserModal(context, ref),
            count: users.length,
            countLabel: 'Users',
            filterDropdowns: [
              // Role Filter
              _buildDropdown(
                value: state.roleFilter,
                isDark: isDark,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                  DropdownMenuItem(value: 'dc_manager', child: Text('DC Manager')),
                  DropdownMenuItem(value: 'dc_operations', child: Text('DC Operations')),
                  DropdownMenuItem(value: 'dc_stock_admin', child: Text('DC Stock')),
                  DropdownMenuItem(value: 'dc_finance_admin', child: Text('DC Finance')),
                  DropdownMenuItem(value: 'general_accountant', child: Text('Accountant')),
                  DropdownMenuItem(value: 'sales_supervisor', child: Text('Sales Supervisor')),
                  DropdownMenuItem(value: 'closer', child: Text('Telesales Closer')),
                  DropdownMenuItem(value: 'marketer', child: Text('Marketer')),
                  DropdownMenuItem(value: 'client', child: Text('Merchant')),
                  DropdownMenuItem(value: 'delivery_agent', child: Text('Rider (PDA)')),
                ],
                onChanged: (val) => notifier.setRoleFilter(val ?? 'all'),
              ),
              // Status Filter
              _buildDropdown(
                value: state.statusFilter,
                isDark: isDark,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (val) => notifier.setStatusFilter(val ?? 'all'),
              ),
            ],
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
              child: users.isEmpty
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
                                  Text('User Profile', style: _headerStyle(isDark)),
                                  const SizedBox(width: 4),
                                  const NovaInfoIcon(message: 'Full name, email address, and phone number'),
                                ],
                              ),
                            ),
                            DataColumn(
                              label: Row(
                                children: [
                                  Text('Role', style: _headerStyle(isDark)),
                                  const SizedBox(width: 4),
                                  const NovaInfoIcon(message: 'Assigned platform access privilege'),
                                ],
                              ),
                            ),
                            DataColumn(
                              label: Text('Hub / Merchant', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Text('Status', style: _headerStyle(isDark)),
                            ),
                            DataColumn(
                              label: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Actions', style: _headerStyle(isDark)),
                              ),
                            ),
                          ],
                          rows: users.map((user) {
                            return DataRow(
                              cells: [
                                // User Column
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                                        child: Text(
                                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.orange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user.fullName,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            user.email,
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

                                // Role Column
                                DataCell(_buildRoleBadge(user.role, isDark)),

                                // Hub / Merchant Column
                                DataCell(
                                  Text(
                                    user.distributionCenterName ?? user.clientCompanyName ?? '—',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ),
                                  ),
                                ),

                                // Status Column
                                DataCell(_buildStatusBadge(user.status)),

                                // Actions Column
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      NovaTooltip(
                                        message: user.isActive ? 'Suspend account access' : 'Reactivate account',
                                        child: IconButton(
                                          icon: Icon(
                                            user.isActive ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                                            size: 17,
                                            color: user.isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                          ),
                                          onPressed: () => notifier.toggleUserStatus(user.id),
                                        ),
                                      ),
                                      NovaTooltip(
                                        message: 'Edit role and hub assignments',
                                        child: IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF3B82F6)),
                                          onPressed: () => _openUserModal(context, ref, user),
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

  Widget _buildRoleBadge(String role, bool isDark) {
    Color bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    Color text = const Color(0xFF3B82F6);
    String label = role;

    switch (role) {
      case 'super_admin':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
        text = const Color(0xFF8B5CF6);
        label = 'Admin';
        break;
      case 'dc_manager':
        bg = AppColors.orange.withValues(alpha: 0.15);
        text = AppColors.orange;
        label = 'DC Supervisor';
        break;
      case 'dc_operations':
        bg = const Color(0xFF0EA5E9).withValues(alpha: 0.15);
        text = const Color(0xFF0EA5E9);
        label = 'DC Orders';
        break;
      case 'dc_stock_admin':
        bg = const Color(0xFF14B8A6).withValues(alpha: 0.15);
        text = const Color(0xFF14B8A6);
        label = 'DC Stock';
        break;
      case 'dc_finance_admin':
      case 'general_accountant':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        text = const Color(0xFF10B981);
        label = 'Finance';
        break;
      case 'closer':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        text = const Color(0xFFF59E0B);
        label = 'Closer';
        break;
      case 'delivery_agent':
        bg = const Color(0xFF6366F1).withValues(alpha: 0.15);
        text = const Color(0xFF6366F1);
        label = 'Rider';
        break;
      case 'client':
        bg = const Color(0xFFEC4899).withValues(alpha: 0.15);
        text = const Color(0xFFEC4899);
        label = 'Merchant';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Suspended',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              'No users matched your criteria',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _openUserModal(BuildContext context, WidgetRef ref, [AdminUserItem? user]) {
    final state = ref.read(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);

    showDialog(
      context: context,
      builder: (context) {
        return AdminUserModal(
          initialUser: user,
          distributionCenters: state.distributionCenters,
          merchants: state.merchants,
          onSave: notifier.saveUser,
        );
      },
    );
  }
}
