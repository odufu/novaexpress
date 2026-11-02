import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/ux_states/ux_states.dart';
import '../../domain/entities/client_accountant.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_accountant_credentials_modal.dart';
import '../widgets/client_onboard_accountant_modal.dart';

class ClientAccountantsPage extends ConsumerStatefulWidget {
  const ClientAccountantsPage({super.key});

  @override
  ConsumerState<ClientAccountantsPage> createState() => _ClientAccountantsPageState();
}

class _ClientAccountantsPageState extends ConsumerState<ClientAccountantsPage> {
  final _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    final allAccountants = state.accountants;
    final filtered = _searchFilter.trim().isEmpty
        ? allAccountants
        : allAccountants.where((a) {
            final q = _searchFilter.trim().toLowerCase();
            return a.fullName.toLowerCase().contains(q) ||
                a.email.toLowerCase().contains(q) ||
                a.phone.toLowerCase().contains(q) ||
                a.accountantCode.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Accountants',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${state.activeAccountantsCount} Active',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Merchant finance personnel managing daily settlements & disbursements',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ClientOnboardAccountantModal(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Onboard',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // KPI Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = isWide
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildKpiCard(
                        title: 'Accountants',
                        value: '${state.totalAccountantsCount}',
                        subtext: '${state.activeAccountantsCount} Active Staff',
                        icon: Icons.badge_rounded,
                        color: const Color(0xFF0F766E),
                        isDark: isDark,
                        width: cardWidth,
                      ),
                      _buildKpiCard(
                        title: 'Active',
                        value: '${state.activeAccountantsCount}',
                        subtext: 'Online Staff',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                        width: cardWidth,
                      ),
                      _buildKpiCard(
                        title: 'Validated',
                        value: '${state.totalSettlementsValidatedByAccountants}',
                        subtext: 'DC Sheets Signed',
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                        width: cardWidth,
                      ),
                      _buildKpiCard(
                        title: 'Signed Vol.',
                        value: currencyFormatter.format(state.totalSettlementAmountValidated),
                        subtext: 'Cumulative Sign-off',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                        width: cardWidth,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchFilter = val),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by accountant name, code, email, or phone...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searchFilter.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content: Table or Cards or Empty State
              if (state.isLoading && filtered.isEmpty)
                NovaLoadingSkeleton.table(rows: 4)
              else if (filtered.isEmpty)
                if (_searchFilter.isNotEmpty)
                  NovaNoSearchResultsState(
                    searchQuery: _searchFilter,
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchFilter = '');
                    },
                  )
                else
                  NovaEmptyState.staff(
                    customMessage:
                        'No accountants have been onboarded yet. Onboard finance personnel to manage daily DC settlement sheets.',
                    onAction: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ClientOnboardAccountantModal(),
                      );
                    },
                  )
              else if (isWide)
                _buildAccountantsTable(filtered, isDark, currencyFormatter)
              else
                _buildAccountantsCardList(filtered, isDark, currencyFormatter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountantsTable(
    List<ClientAccountant> accountants,
    bool isDark,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.2), // Accountant
            1: FlexColumnWidth(2.0), // Contact
            2: FlexColumnWidth(2.0), // Permissions
            3: FlexColumnWidth(1.4), // Validated
            4: FlexColumnWidth(1.0), // Status
            5: FlexColumnWidth(1.2), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Table Header
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              children: [
                _buildTableHeaderCell('ACCOUNTANT', isDark),
                _buildTableHeaderCell('CONTACT', isDark),
                _buildTableHeaderCell('PERMISSIONS', isDark),
                _buildTableHeaderCell('VALIDATED', isDark),
                _buildTableHeaderCell('STATUS', isDark),
                _buildTableHeaderCell('ACTIONS', isDark),
              ],
            ),
            // Table Rows
            ...accountants.map((accountant) {
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                children: [
                  // Accountant
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                          child: Text(
                            accountant.fullName.isNotEmpty
                                ? accountant.fullName[0].toUpperCase()
                                : 'A',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accountant.fullName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                accountant.accountantCode,
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contact
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountant.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                        Text(
                          accountant.phone,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Permissions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (accountant.canApproveSettlements)
                          _buildPermissionBadge('Settlement', const Color(0xFF0F766E)),
                        if (accountant.canManageExpenses)
                          _buildPermissionBadge('Expenses', const Color(0xFF3B82F6)),
                        if (accountant.canDisbursePayouts)
                          _buildPermissionBadge('Payouts', const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  // Validated
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${accountant.totalSettlementsValidated} Sheets',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          currencyFormatter.format(accountant.totalAmountValidated),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: accountant.isActive,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          ref
                              .read(clientPortalProvider.notifier)
                              .toggleAccountantStatus(
                                accountantId: accountant.id,
                                isActive: val,
                              );
                        },
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share_rounded, size: 16),
                          tooltip: 'Share Credentials',
                          color: const Color(0xFF0F766E),
                          onPressed: () {
                            ClientAccountantCredentialsModal.show(
                              context,
                              accountant: accountant,
                              clientName:
                                  ref.read(clientPortalProvider).clientProfile.companyName,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountantsCardList(
    List<ClientAccountant> accountants,
    bool isDark,
    NumberFormat currencyFormatter,
  ) {
    return Column(
      children: accountants.map((accountant) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                    child: Text(
                      accountant.fullName.isNotEmpty
                          ? accountant.fullName[0].toUpperCase()
                          : 'A',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountant.fullName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          accountant.accountantCode,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 16),
                    tooltip: 'Share Credentials',
                    color: const Color(0xFF0F766E),
                    onPressed: () {
                      ClientAccountantCredentialsModal.show(
                        context,
                        accountant: accountant,
                        clientName:
                            ref.read(clientPortalProvider).clientProfile.companyName,
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    accountant.email,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  Text(
                    accountant.phone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (accountant.canApproveSettlements)
                        _buildPermissionBadge('Settlement', const Color(0xFF0F766E)),
                      if (accountant.canManageExpenses)
                        _buildPermissionBadge('Expenses', const Color(0xFF3B82F6)),
                      if (accountant.canDisbursePayouts)
                        _buildPermissionBadge('Payouts', const Color(0xFFF59E0B)),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: accountant.isActive,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        ref
                            .read(clientPortalProvider.notifier)
                            .toggleAccountantStatus(
                              accountantId: accountant.id,
                              isActive: val,
                            );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTableHeaderCell(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

