import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/domain/entities/business_expenditure.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../providers/dc_expenditures_provider.dart';
import '../widgets/dc_create_expenditure_modal.dart';
import '../widgets/dc_receipt_preview_modal.dart';

class DCExpendituresPage extends ConsumerStatefulWidget {
  const DCExpendituresPage({super.key});

  @override
  ConsumerState<DCExpendituresPage> createState() => _DCExpendituresPageState();
}

class _DCExpendituresPageState extends ConsumerState<DCExpendituresPage> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
  final NumberFormat _compactCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(ExpenditureCategory category) {
    switch (category) {
      case ExpenditureCategory.dieselFuel:
        return const Color(0xFFF59E0B); // Amber
      case ExpenditureCategory.riderAllowance:
        return const Color(0xFF0D9488); // Teal
      case ExpenditureCategory.logistics:
        return const Color(0xFF3B82F6); // Blue
      case ExpenditureCategory.rentUtilities:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenditureCategory.equipmentMaintenance:
        return const Color(0xFFEC4899); // Pink
      case ExpenditureCategory.packaging:
      case ExpenditureCategory.stationery:
        return const Color(0xFF10B981); // Emerald
      case ExpenditureCategory.facilitySupplies:
        return const Color(0xFF06B6D4); // Cyan
      case ExpenditureCategory.security:
        return const Color(0xFF6366F1); // Indigo
      case ExpenditureCategory.salaries:
        return const Color(0xFFF97316); // Orange
      case ExpenditureCategory.other:
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCategoryIcon(ExpenditureCategory category) {
    switch (category) {
      case ExpenditureCategory.dieselFuel:
        return Icons.local_gas_station_rounded;
      case ExpenditureCategory.riderAllowance:
        return Icons.two_wheeler_rounded;
      case ExpenditureCategory.logistics:
        return Icons.local_shipping_rounded;
      case ExpenditureCategory.rentUtilities:
        return Icons.power_rounded;
      case ExpenditureCategory.equipmentMaintenance:
        return Icons.build_circle_rounded;
      case ExpenditureCategory.packaging:
      case ExpenditureCategory.stationery:
        return Icons.inventory_2_rounded;
      case ExpenditureCategory.facilitySupplies:
        return Icons.cleaning_services_rounded;
      case ExpenditureCategory.security:
        return Icons.security_rounded;
      case ExpenditureCategory.salaries:
        return Icons.badge_rounded;
      case ExpenditureCategory.other:
      default:
        return Icons.receipt_rounded;
    }
  }

  String _getDcName(String? dcId, List<DistributionCenter> dcs) {
    if (dcId == null || dcId.isEmpty) return 'General Network';
    final dc = dcs.where((d) => d.id == dcId || d.code == dcId).firstOrNull;
    return dc?.name ?? 'Station $dcId';
  }

  bool _isMainDc(String? dcId, List<DistributionCenter> dcs) {
    if (dcId == null || dcId.isEmpty) return true;
    final dc = dcs.where((d) => d.id == dcId || d.code == dcId).firstOrNull;
    if (dc == null) return false;
    final name = dc.name.toLowerCase();
    final code = dc.code.toLowerCase();
    return name.contains('wuse') ||
        name.contains('abuja') ||
        code.contains('wuse') ||
        code == 'dc-wuse-01';
  }

  Future<void> _confirmDelete(BusinessExpenditureEntity exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Expenditure Record?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${exp.title}" (${_currencyFormat.format(exp.amount)})? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(dcExpendituresProvider.notifier).deleteExpenditure(exp.id);
    if (ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Expenditure record deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;

    final expState = ref.watch(dcExpendituresProvider);
    final expNotifier = ref.read(dcExpendituresProvider.notifier);
    final authUser = ref.watch(authProvider).user;
    final dcs = ref.watch(dcConsoleProvider).distributionCenters;

    final userDcId = authUser?.distributionCenterId;
    final userIsAbujaMain = _isMainDc(userDcId, dcs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => expNotifier.loadExpenditures(),
        color: const Color(0xFF0D9488),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Top Header Banner & Quick Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  isDesktop ? 24 : 16,
                  isDesktop ? 24 : 16,
                  16,
                ),
                child: _buildHeader(isDesktop, isDark, userIsAbujaMain, userDcId, dcs),
              ),
            ),

            // 2. High-Impact Business KPI Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
                child: _buildKpisGrid(expState, isDesktop, isDark),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // 3. Filter Controls Toolbar
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
                child: _buildFiltersBar(expState, expNotifier, isDesktop, isDark, userIsAbujaMain, dcs),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 4. Content Area: Table for Desktop, Cards for Mobile
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 16,
                0,
                isDesktop ? 24 : 16,
                80,
              ),
              sliver: expState.isLoading
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(60),
                          child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                        ),
                      ),
                    )
                  : expState.filteredExpenditures.isEmpty
                      ? SliverToBoxAdapter(
                          child: _buildEmptyState(isDark),
                        )
                      : isDesktop
                          ? SliverToBoxAdapter(
                              child: _buildDesktopTable(
                                expState.filteredExpenditures,
                                isDark,
                                dcs,
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final exp = expState.filteredExpenditures[index];
                                  return _buildMobileCard(exp, isDark, dcs);
                                },
                                childCount: expState.filteredExpenditures.length,
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              onPressed: () => DCCreateExpenditureModal.show(context),
              backgroundColor: const Color(0xFF0D9488),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Record Expense',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HEADER SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    bool isDesktop,
    bool isDark,
    bool userIsAbujaMain,
    String? userDcId,
    List<DistributionCenter> dcs,
  ) {
    final currentStationName = userIsAbujaMain
        ? 'Abuja Main Grand DC (Headquarters)'
        : _getDcName(userDcId, dcs);

    final canPop = Navigator.of(context).canPop();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (canPop) ...[
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Distribution Center Expenditures',
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 20 : 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: userIsAbujaMain
                          ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          userIsAbujaMain ? Icons.hub_rounded : Icons.warehouse_rounded,
                          size: 12,
                          color: userIsAbujaMain ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userIsAbujaMain ? 'ALL-DC ACCESS' : 'LOCAL STATION',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: userIsAbujaMain ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$currentStationName • Operational OpEx, Invoices, Receipts & Logistics Costs',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isDesktop) ...[
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh expenditures',
            onPressed: () => ref.read(dcExpendituresProvider.notifier).loadExpenditures(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => DCCreateExpenditureModal.show(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Record Expenditure'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. BUSINESS KPIS SECTION (5 METRICS)
  // ---------------------------------------------------------------------------
  Widget _buildKpisGrid(DCExpendituresState state, bool isDesktop, bool isDark) {
    final kpis = [
      _KpiData(
        title: 'Total Period OpEx',
        value: _compactCurrency.format(state.totalExpenditure),
        subtitle: '${state.totalInvoicesCount} total vouchers',
        icon: Icons.payments_rounded,
        gradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
      ),
      _KpiData(
        title: 'Fuel & Fleet Logistics',
        value: _compactCurrency.format(state.fuelAndLogisticsTotal),
        subtitle: state.totalExpenditure > 0
            ? '${((state.fuelAndLogisticsTotal / state.totalExpenditure) * 100).toStringAsFixed(1)}% of total OpEx'
            : '0.0% of OpEx',
        icon: Icons.local_gas_station_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      _KpiData(
        title: 'Station Facilities & Utilities',
        value: _compactCurrency.format(state.facilityAndUtilitiesTotal),
        subtitle: 'Power, rent, repairs & supplies',
        icon: Icons.power_rounded,
        gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      ),
      _KpiData(
        title: 'Packaging & Consumables',
        value: _compactCurrency.format(state.packagingTotal),
        subtitle: 'Waybills, tapes & bags',
        icon: Icons.inventory_2_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
      ),
      _KpiData(
        title: 'Verifiable Receipt Rate',
        value: '${state.receiptVerificationRate.toStringAsFixed(1)}%',
        subtitle: '${state.receiptsAttachedCount} of ${state.totalInvoicesCount} with receipts',
        icon: Icons.verified_rounded,
        gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
      ),
    ];

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - (12 * 4)) / 5;
          return Row(
            children: kpis.map((kpi) {
              return Container(
                width: itemWidth,
                margin: EdgeInsets.only(right: kpi == kpis.last ? 0 : 12),
                child: _buildKpiCard(kpi, isDark),
              );
            }).toList(),
          );
        },
      );
    } else {
      // Mobile: Horizontal scrolling cards
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 190,
              child: _buildKpiCard(kpis[index], isDark),
            );
          },
        ),
      );
    }
  }

  Widget _buildKpiCard(_KpiData kpi, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  kpi.title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: kpi.gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, size: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kpi.value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            kpi.subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. FILTERS & SEARCH TOOLBAR
  // ---------------------------------------------------------------------------
  Widget _buildFiltersBar(
    DCExpendituresState state,
    DCExpendituresNotifier notifier,
    bool isDesktop,
    bool isDark,
    bool userIsAbujaMain,
    List<DistributionCenter> dcs,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Search Input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => notifier.setSearchQuery(val),
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search title, invoice #, vendor, notes...',
                            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Station Scope Dropdown (Abuja Main DC can view all stations)
              if (userIsAbujaMain)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedDcId,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Row(
                            children: [
                              Icon(Icons.hub_rounded, size: 15, color: Color(0xFF0D9488)),
                              SizedBox(width: 6),
                              Text('All Distribution Centers'),
                            ],
                          ),
                        ),
                        ...dcs.map((dc) {
                          return DropdownMenuItem(
                            value: dc.id,
                            child: Row(
                              children: [
                                const Icon(Icons.warehouse_rounded, size: 15, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 6),
                                Text(dc.name),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setDcFilter(val);
                      },
                    ),
                  ),
                ),

              const SizedBox(width: 10),

              // Date Range Preset Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.datePreset,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                      DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      final now = DateTime.now();
                      DateTime? start;
                      DateTime? end = now;

                      switch (val) {
                        case 'Today':
                          start = DateTime(now.year, now.month, now.day);
                          break;
                        case 'This Week':
                          start = now.subtract(Duration(days: now.weekday - 1));
                          break;
                        case 'This Month':
                          start = DateTime(now.year, now.month, 1);
                          break;
                        case 'All Time':
                          start = null;
                          end = null;
                          break;
                      }
                      notifier.setDateRange(start, end, preset: val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Horizontal Category Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('all', 'All Categories', Icons.apps_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('diesel_fuel', 'Diesel & Fuel', Icons.local_gas_station_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('rider_allowance', 'Rider Allowances', Icons.two_wheeler_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('logistics', 'Logistics & Haulage', Icons.local_shipping_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('rent_utilities', 'Rent & Utilities', Icons.power_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('equipment_maintenance', 'Maintenance', Icons.build_circle_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('packaging', 'Packaging', Icons.inventory_2_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('facility_supplies', 'Hub Supplies', Icons.cleaning_services_rounded, state.selectedCategory, notifier, isDark),
                const SizedBox(width: 8),
                _buildCategoryPill('other', 'Other OpEx', Icons.receipt_rounded, state.selectedCategory, notifier, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(
    String val,
    String label,
    IconData icon,
    String currentVal,
    DCExpendituresNotifier notifier,
    bool isDark,
  ) {
    final isSelected = currentVal == val;
    return InkWell(
      onTap: () => notifier.setCategory(val),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D9488)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DESKTOP VIEW: HIGH PERFORMANCE DATA TABLE
  // ---------------------------------------------------------------------------
  Widget _buildDesktopTable(
    List<BusinessExpenditureEntity> list,
    bool isDark,
    List<DistributionCenter> dcs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return isDark ? const Color(0xFF243048) : const Color(0xFFF1F5F9);
                }
                return Colors.transparent;
              }),
              horizontalMargin: 18,
              columnSpacing: 20,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 64,
              columns: [
                DataColumn(
                  label: Text('DATE / INVOICE #', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('EXPENSE TITLE', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('STATION / DC', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('CATEGORY', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('VENDOR / SUPPLIER', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('AMOUNT (₦)', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('RECEIPT', style: _tableHeaderStyle(isDark)),
                ),
                DataColumn(
                  label: Text('ACTIONS', style: _tableHeaderStyle(isDark)),
                ),
              ],
              rows: list.map((exp) {
                final catColor = _getCategoryColor(exp.category);
                final stationName = _getDcName(exp.distributionCenterId, dcs);

                return DataRow(
                  cells: [
                    // 1. Date & Invoice #
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(exp.expenditureDate),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            exp.invoiceNumber ?? 'NO-INVOICE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Title & Description
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              exp.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (exp.description != null && exp.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                exp.description!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 3. Station / DC Badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (stationName.toLowerCase().contains('wuse')
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF3B82F6))
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              stationName.toLowerCase().contains('wuse')
                                  ? Icons.hub_rounded
                                  : Icons.warehouse_rounded,
                              size: 13,
                              color: stationName.toLowerCase().contains('wuse')
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                stationName,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: stationName.toLowerCase().contains('wuse')
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF3B82F6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. Category
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getCategoryIcon(exp.category), size: 13, color: catColor),
                            const SizedBox(width: 5),
                            Text(
                              exp.category.label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Vendor / Beneficiary
                    DataCell(
                      Text(
                        exp.vendorName ?? 'Station Petty Cash',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 6. Amount
                    DataCell(
                      Text(
                        _currencyFormat.format(exp.amount),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),

                    // 7. Receipt Preview Button
                    DataCell(
                      exp.hasReceipt
                          ? InkWell(
                              onTap: () => DCReceiptPreviewModal.show(context, exp, dcName: stationName),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      exp.isPdfReceipt
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.receipt_long_rounded,
                                      size: 14,
                                      color: const Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      exp.isPdfReceipt ? 'View PDF' : 'Receipt',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D9488),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'No Receipt',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                    ),

                    // 8. Actions (Delete, Copy Ref)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (exp.invoiceNumber != null && exp.invoiceNumber!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy voucher reference',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: exp.invoiceNumber!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied ${exp.invoiceNumber} to clipboard'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                            tooltip: 'Delete expenditure',
                            onPressed: () => _confirmDelete(exp),
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
    );
  }

  TextStyle _tableHeaderStyle(bool isDark) {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. MOBILE VIEW: ORGANIC TOUCH-FRIENDLY CARDS
  // ---------------------------------------------------------------------------
  Widget _buildMobileCard(
    BusinessExpenditureEntity exp,
    bool isDark,
    List<DistributionCenter> dcs,
  ) {
    final catColor = _getCategoryColor(exp.category);
    final stationName = _getDcName(exp.distributionCenterId, dcs);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category Badge + Date + Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getCategoryIcon(exp.category), size: 13, color: catColor),
                        const SizedBox(width: 5),
                        Text(
                          exp.category.label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _currencyFormat.format(exp.amount),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Title
              Text(
                exp.title,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

              if (exp.description != null && exp.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  exp.description!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Station, Vendor & Invoice Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warehouse_rounded, size: 12, color: Color(0xFF0D9488)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            stationName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D9488),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (exp.vendorName != null && exp.vendorName!.isNotEmpty)
                    Expanded(
                      child: Text(
                        exp.vendorName!,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    DateFormat('MMM d, yyyy').format(exp.expenditureDate),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Bottom Actions: Receipt Button + Delete
              Row(
                children: [
                  if (exp.invoiceNumber != null && exp.invoiceNumber!.isNotEmpty)
                    Text(
                      'Ref: ${exp.invoiceNumber!}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  const Spacer(),
                  if (exp.hasReceipt)
                    InkWell(
                      onTap: () => DCReceiptPreviewModal.show(context, exp, dcName: stationName),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              exp.isPdfReceipt ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded,
                              size: 14,
                              color: const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              exp.isPdfReceipt ? 'View PDF' : 'View Receipt',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      'No receipt attached',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(exp),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Expenditures Found',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No expense vouchers match the selected station, category, or date range.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => DCCreateExpenditureModal.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Record First Station Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}
