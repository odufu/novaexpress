import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/domain/entities/business_expenditure.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../providers/dc_expenditures_provider.dart';
import '../services/dc_finance_excel_exporter.dart';
import '../widgets/dc_create_expenditure_modal.dart';
import '../widgets/dc_receipt_preview_modal.dart';
import '../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';

class DCExpendituresPage extends ConsumerStatefulWidget {
  const DCExpendituresPage({super.key});

  @override
  ConsumerState<DCExpendituresPage> createState() => _DCExpendituresPageState();
}

class _DCExpendituresPageState extends ConsumerState<DCExpendituresPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
  final NumberFormat _compactCurrency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(ExpenditureCategory category) {
    switch (category) {
      case ExpenditureCategory.dieselFuel:
        return const Color(0xFFF59E0B);
      case ExpenditureCategory.riderAllowance:
        return const Color(0xFF0D9488);
      case ExpenditureCategory.logistics:
        return const Color(0xFF3B82F6);
      case ExpenditureCategory.rentUtilities:
        return const Color(0xFF8B5CF6);
      case ExpenditureCategory.equipmentMaintenance:
        return const Color(0xFFEC4899);
      case ExpenditureCategory.packaging:
      case ExpenditureCategory.stationery:
        return const Color(0xFF10B981);
      case ExpenditureCategory.facilitySupplies:
        return const Color(0xFF06B6D4);
      case ExpenditureCategory.security:
        return const Color(0xFF6366F1);
      case ExpenditureCategory.salaries:
        return const Color(0xFFF97316);
      case ExpenditureCategory.other:
      default:
        return const Color(0xFF64748B);
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
    if (dcId == null || dcId.isEmpty || dcId == 'all') return 'All Distribution Centers (Consolidated)';
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
        code == 'dc-wuse-01' ||
        dc.isPrimaryHub;
  }

  Future<void> _exportToExcel(DCExpendituresState expState, List<DistributionCenter> dcs) async {
    setState(() => _isExporting = true);
    try {
      final success = await DcFinanceExcelExporter.exportFinancialReport(
        periodName: expState.datePreset,
        stationName: _getDcName(expState.selectedDcId, dcs),
        totalRevenue: expState.totalRevenue,
        riderWages: expState.riderSalaryAndWages,
        fuelAndMaintenance: expState.fuelMaintenanceAndLubricant,
        airtimeAndData: expState.airtimeAndData,
        totalDirectCosts: expState.totalDirectCosts,
        grossProfit: expState.grossProfit,
        grossProfitMargin: expState.grossProfitMargin,
        adminSalaries: expState.adminSalaries,
        officeExpenses: expState.officeExpenses,
        otherExpenses: expState.otherExpenses,
        totalOpex: expState.totalOpex,
        netProfit: expState.netProfit,
        netProfitMargin: expState.netProfitMargin,
        adjustedNetProfit: expState.adjustedNetProfit,
        totalOrdersAssigned: expState.totalOrdersAssigned,
        totalOrdersDelivered: expState.totalOrdersDelivered,
        deliverySuccessRate: expState.deliverySuccessRate,
        expenditures: expState.filteredExpenditures,
        dcs: dcs,
        failureBreakdown: expState.failureBreakdown,
        riderScorecards: expState.riderScorecards,
        momTrends: expState.momTrends,
      );

      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success
                        ? 'Excel Financial Report downloaded successfully! (.xlsx)'
                        : 'Failed to generate Excel report.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Export error: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BusinessExpenditureEntity exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Expenditure Record?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${exp.title}" (${_currencyFormat.format(exp.amount)})? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Expenditure record removed from station ledger'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;

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
        color: const Color(0xFFF37021),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Executive Header Control Bar
              _buildHeader(isDesktop, isDark, userIsAbujaMain, userDcId, dcs, expState, expNotifier),
              const SizedBox(height: 20),

              // 2. High-Impact Executive KPI Cards (Grid)
              _buildExecutiveKpiGrid(expState, isDesktop, isDark),
              const SizedBox(height: 24),

              // 3. Sub-Tab Switcher Navigation
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: !isDesktop,
                  indicatorColor: const Color(0xFFF37021),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFF37021),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'P&L Statement & KPIs'),
                    Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Expenditures & Invoices'),
                    Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'Delivery Operations & Root Cause'),
                    Tab(icon: Icon(Icons.trending_up_rounded, size: 18), text: 'MoM Growth & Comparison'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Tab Views Area
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildPnlStatementTab(expState, isDark, isDesktop);
                    case 1:
                      return _buildExpendituresLedgerTab(expState, expNotifier, isDark, isDesktop, dcs);
                    case 2:
                      return _buildDeliveryOperationsTab(expState, isDark, isDesktop);
                    case 3:
                      return _buildMomGrowthTab(expState, isDark, isDesktop);
                    default:
                      return _buildPnlStatementTab(expState, isDark, isDesktop);
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              onPressed: () => DCCreateExpenditureModal.show(context),
              backgroundColor: const Color(0xFFF37021),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Record Expense',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildHeaderDatePill(String label, String key, String activePreset, bool isDark, DCExpendituresNotifier notifier) {
    final isSelected = activePreset.toLowerCase() == key.toLowerCase();
    return InkWell(
      onTap: () => notifier.setDatePreset(key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFFF37021) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. EXECUTIVE HEADER CONTROL BAR
  // ==========================================
  Widget _buildHeader(
    bool isDesktop,
    bool isDark,
    bool userIsAbujaMain,
    String? userDcId,
    List<DistributionCenter> dcs,
    DCExpendituresState state,
    DCExpendituresNotifier notifier,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF37021), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 26),
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
                            'Financial Command & Operations Reporting',
                            style: GoogleFonts.inter(
                              fontSize: isDesktop ? 20 : 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'AUDITED REPORT',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'P&L statement, cost of services, direct expenses, and delivery unit economics',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                // Excel Export Button
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : () => _exportToExcel(state, dcs),
                  icon: _isExporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.table_view_rounded, size: 16, color: Colors.white),
                  label: Text(
                    _isExporting ? 'Generating Excel...' : 'Export Excel (.xlsx)',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                // Record Expense Button
                ElevatedButton.icon(
                  onPressed: () => DCCreateExpenditureModal.show(context),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: Text(
                    'Record Expense',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF37021),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Filters Row: Station Selector & Period Selector
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Segmented Date Capsule Ribbon (Today | 7D | 30D | This Month | All Time | 📅)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildHeaderDatePill('Today', 'Today', state.datePreset, isDark, notifier),
                    _buildHeaderDatePill('7D', '7D', state.datePreset, isDark, notifier),
                    _buildHeaderDatePill('30D', '30D', state.datePreset, isDark, notifier),
                    _buildHeaderDatePill('This Month', 'This Month', state.datePreset, isDark, notifier),
                    _buildHeaderDatePill('All Time', 'All Time', state.datePreset, isDark, notifier),
                    IconButton(
                      tooltip: 'Custom Calendar Date Range',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: (state.datePreset == 'Custom' || state.startDate != null)
                            ? const Color(0xFFF37021)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      onPressed: () async {
                        final result = await PangeaDateRangePickerModal.show(
                          context,
                          initialStartDate: state.startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                          initialEndDate: state.endDate ?? DateTime.now(),
                          initialPreset: DateRangePreset.custom,
                        );
                        if (result != null) {
                          notifier.setDateRange(result.startDate, result.endDate, preset: 'Custom');
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (state.datePreset == 'Custom' && state.startDate != null && state.endDate != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF37021)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${DateFormat('dd MMM').format(state.startDate!)} - ${DateFormat('dd MMM').format(state.endDate!)}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => notifier.setDatePreset('All Time'),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFF37021)),
                      ),
                    ],
                  ),
                ),
              ],

              // Station Scope Filter
              if (userIsAbujaMain) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedDcId,
                      dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      icon: const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF3B82F6)),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('🌐 All Distribution Centers Combined')),
                        ...dcs.map((d) {
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('${d.name} (${d.city})'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setDcFilter(val);
                      },
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF0D9488)),
                      const SizedBox(width: 6),
                      Text(
                        'Scoped Station: ${_getDcName(userDcId, dcs)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                ),
              ],

              if (!isDesktop) ...[
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _exportToExcel(state, dcs),
                  icon: const Icon(Icons.table_view_rounded, size: 15, color: Color(0xFF10B981)),
                  label: Text('Export Excel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. HIGH-IMPACT EXECUTIVE KPI GRID
  // ==========================================
  Widget _buildExecutiveKpiGrid(DCExpendituresState state, bool isDesktop, bool isDark) {
    final cols = isDesktop ? 6 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - ((cols - 1) * 12)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildExecutiveCard(
              title: 'TOTAL REVENUE',
              value: _compactCurrency.format(state.totalRevenue),
              subtitle: '${state.totalOrdersDelivered} Delivered Orders',
              icon: Icons.payments_rounded,
              accentColor: const Color(0xFF10B981),
              trend: '+6.69% MoM ↑',
              isDark: isDark,
              width: cardWidth,
            ),
            _buildExecutiveCard(
              title: 'COST OF SERVICES',
              value: _compactCurrency.format(state.totalDirectCosts),
              subtitle: '${state.directCostPercentage.toStringAsFixed(1)}% of Revenue (Direct)',
              icon: Icons.two_wheeler_rounded,
              accentColor: const Color(0xFF3B82F6),
              trend: 'Wages, Fuel & Comms',
              isDark: isDark,
              width: cardWidth,
            ),
            _buildExecutiveCard(
              title: 'GROSS PROFIT',
              value: _compactCurrency.format(state.grossProfit),
              subtitle: '${state.grossProfitMargin.toStringAsFixed(1)}% Margin',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: const Color(0xFFF37021),
              trend: '+8.95% Margin Growth ↑',
              isDark: isDark,
              width: cardWidth,
            ),
            _buildExecutiveCard(
              title: 'OPERATIONAL EXPENSES',
              value: _compactCurrency.format(state.totalOpex),
              subtitle: 'Admin, Capex & Power',
              icon: Icons.business_center_rounded,
              accentColor: const Color(0xFF8B5CF6),
              trend: '${state.opexPercentage.toStringAsFixed(1)}% of Rev',
              isDark: isDark,
              width: cardWidth,
            ),
            _buildExecutiveCard(
              title: 'NET PROFIT',
              value: _compactCurrency.format(state.netProfit),
              subtitle: 'Pre-Capex: ${_compactCurrency.format(state.adjustedNetProfit)}',
              icon: Icons.price_check_rounded,
              accentColor: const Color(0xFF0D9488),
              trend: '22.3% Pre-Capex Margin',
              isDark: isDark,
              width: cardWidth,
            ),
            _buildExecutiveCard(
              title: 'DELIVERY SUCCESS RATE',
              value: '${state.deliverySuccessRate.toStringAsFixed(1)}%',
              subtitle: '${state.totalOrdersDelivered} / ${state.totalOrdersAssigned} Assigned',
              icon: Icons.check_circle_outline_rounded,
              accentColor: state.deliverySuccessRate >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              trend: 'Root Cause Tracked',
              isDark: isDark,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExecutiveCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String trend,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trend,
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: accentColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: P&L STATEMENT & REVENUE BREAKDOWN
  // ==========================================
  Widget _buildPnlStatementTab(DCExpendituresState state, bool isDark, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Audited P&L Table Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Color(0xFFF37021), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'P&L Statement of Operations (${state.datePreset})',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),

              // Table Body
              _buildPnlRow('TOTAL LOGISTICS REVENUE', state.totalRevenue, '100.0%', isDark, isHeader: true, color: const Color(0xFF10B981)),
              _buildPnlSectionHeader('Cost of Services / Direct Operating Costs', isDark),
              _buildPnlRow('  • Riders / PDA Salary & Wages', state.riderSalaryAndWages, '${(state.riderSalaryAndWages / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('  • Fuel, Maintenance & Lubricant', state.fuelMaintenanceAndLubricant, '${(state.fuelMaintenanceAndLubricant / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('  • Logistics Dispatch Comms (Airtime & Data)', state.airtimeAndData, '${(state.airtimeAndData / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('TOTAL DIRECT OPERATING COSTS', state.totalDirectCosts, '${state.directCostPercentage.toStringAsFixed(1)}%', isDark, isSubtotal: true, color: const Color(0xFF3B82F6)),

              _buildPnlRow('GROSS PROFIT', state.grossProfit, '${state.grossProfitMargin.toStringAsFixed(2)}%', isDark, isHeader: true, color: const Color(0xFFF37021)),

              _buildPnlSectionHeader('Operational Expenses (OPEX)', isDark),
              _buildPnlRow('  • Admin Salaries & Hub Operations Team', state.adminSalaries, '${(state.adminSalaries / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('  • Office Expenses & Management Airtime', state.officeExpenses, '${(state.officeExpenses / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('  • Other Expenses & Capex (Power, Lagos Project, Equipment)', state.otherExpenses, '${(state.otherExpenses / state.totalRevenue * 100).toStringAsFixed(1)}%', isDark),
              _buildPnlRow('TOTAL OPERATIONAL EXPENSES', state.totalOpex, '${state.opexPercentage.toStringAsFixed(1)}%', isDark, isSubtotal: true, color: const Color(0xFF8B5CF6)),

              _buildPnlRow('REPORTED NET PROFIT', state.netProfit, '${state.netProfitMargin.toStringAsFixed(2)}%', isDark, isHeader: true, color: const Color(0xFF0D9488)),
              _buildPnlRow('Adjusted Operating Profit (Before Expansion & Equipment Capex)', state.adjustedNetProfit, '${state.adjustedNetProfitMargin.toStringAsFixed(2)}%', isDark, isSpecial: true),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Deep-Dive: What is inside Other Expenses (Table 2c in Report)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_rounded, color: Color(0xFF8B5CF6), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'What is Inside Other Expenses (${_compactCurrency.format(state.otherExpenses)})',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Text(
                    '100.0% OF OTHER OPEX',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...state.otherExpensesBreakdown.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFFF37021)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['group'].toString(),
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['share'].toString(),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF8B5CF6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _currencyFormat.format(item['amount']),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Unit Economics Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildUnitMetric('Revenue per Delivered Order', _currencyFormat.format(state.revenuePerDeliveredOrder), isDark),
              _buildUnitMetric('Direct Cost per Order', _currencyFormat.format(state.directCostPerDeliveredOrder), isDark),
              _buildUnitMetric('Net Profit per Order', _currencyFormat.format(state.netProfitPerDeliveredOrder), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitMetric(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFF37021)),
        ),
      ],
    );
  }

  Widget _buildPnlSectionHeader(String title, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildPnlRow(
    String label,
    double amount,
    String percentage,
    bool isDark, {
    bool isHeader = false,
    bool isSubtotal = false,
    bool isSpecial = false,
    Color? color,
  }) {
    final bg = isHeader
        ? (color ?? const Color(0xFFF37021)).withValues(alpha: isDark ? 0.15 : 0.08)
        : (isSubtotal
            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))
            : (isSpecial ? const Color(0xFF0D9488).withValues(alpha: 0.08) : Colors.transparent));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isHeader ? 13.5 : 12.5,
                fontWeight: (isHeader || isSubtotal || isSpecial) ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              percentage,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: Text(
              _currencyFormat.format(amount),
              style: GoogleFonts.inter(
                fontSize: isHeader ? 14 : 13,
                fontWeight: (isHeader || isSubtotal || isSpecial) ? FontWeight.w900 : FontWeight.w600,
                color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EXPENDITURES & INVOICES LEDGER
  // ==========================================
  Widget _buildExpendituresLedgerTab(
    DCExpendituresState expState,
    DCExpendituresNotifier expNotifier,
    bool isDark,
    bool isDesktop,
    List<DistributionCenter> dcs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter toolbar
        _buildExpenditureFiltersBar(expState, expNotifier, isDesktop, isDark, dcs),
        const SizedBox(height: 16),

        // List / Table
        if (expState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(color: Color(0xFFF37021)),
            ),
          )
        else if (expState.filteredExpenditures.isEmpty)
          _buildEmptyLedgerState(isDark)
        else if (isDesktop)
          _buildDesktopLedgerTable(expState.filteredExpenditures, isDark, dcs)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: expState.filteredExpenditures.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildMobileLedgerCard(expState.filteredExpenditures[index], isDark, dcs);
            },
          ),
      ],
    );
  }

  Widget _buildExpenditureFiltersBar(
    DCExpendituresState state,
    DCExpendituresNotifier notifier,
    bool isDesktop,
    bool isDark,
    List<DistributionCenter> dcs,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: notifier.setSearchQuery,
                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search expense title, invoice #, or vendor...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              notifier.setSearchQuery('');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => DCCreateExpenditureModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: Text('Record', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Filter Ribbon (Today | 7D | 30D | This Month | All Time | 📅)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0), width: 0.8),
            ),
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildHeaderDatePill('Today', 'Today', state.datePreset, isDark, notifier),
                _buildHeaderDatePill('7D', '7D', state.datePreset, isDark, notifier),
                _buildHeaderDatePill('30D', '30D', state.datePreset, isDark, notifier),
                _buildHeaderDatePill('This Month', 'This Month', state.datePreset, isDark, notifier),
                _buildHeaderDatePill('All Time', 'All Time', state.datePreset, isDark, notifier),
                IconButton(
                  tooltip: 'Custom Calendar Date Range',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: (state.datePreset == 'Custom' || state.startDate != null)
                        ? const Color(0xFFF37021)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  onPressed: () async {
                    final result = await PangeaDateRangePickerModal.show(
                      context,
                      initialStartDate: state.startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      initialEndDate: state.endDate ?? DateTime.now(),
                      initialPreset: DateRangePreset.custom,
                    );
                    if (result != null) {
                      notifier.setDateRange(result.startDate, result.endDate, preset: 'Custom');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLedgerChip('all', 'All Categories (${state.expenditures.length})', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('diesel_fuel', 'Diesel & Generator Fuel', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('rider_allowance', 'Rider Allowances & Wages', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('salaries', 'Admin Salaries', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('equipment_maintenance', 'Bike Maintenance & Oil', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('rent_utilities', 'Rent & Utilities', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('packaging', 'Packaging Pouches', state.selectedCategory, isDark, notifier),
                const SizedBox(width: 6),
                _buildLedgerChip('other', 'Other OpEx & Capex', state.selectedCategory, isDark, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerChip(String catKey, String label, String currentCat, bool isDark, DCExpendituresNotifier notifier) {
    final isSelected = currentCat == catKey;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      selectedColor: const Color(0xFFF37021).withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      side: BorderSide(color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
      onSelected: (_) => notifier.setCategory(catKey),
    );
  }

  Widget _buildDesktopLedgerTable(List<BusinessExpenditureEntity> list, bool isDark, List<DistributionCenter> dcs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: PangeaExcelDataTable<BusinessExpenditureEntity>(
        items: list,
        brandPrimary: const Color(0xFFF37021),
        enablePagination: true,
        initialPageSize: 25,
        rowHeight: 56.0,
        dateExtractor: (exp) => exp.expenditureDate,
        showDateFilter: true,
        columns: [
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'date',
            group: 'Expense Record',
            label: 'DATE',
            defaultWidth: 130,
            minWidth: 100,
            sortValue: (exp) => exp.expenditureDate,
            dateValue: (exp) => exp.expenditureDate,
            searchString: (exp) => DateFormat('MMM dd, yyyy').format(exp.expenditureDate),
            cellBuilder: (ctx, exp, row, isDark, brand) => Text(
              DateFormat('MMM dd, yyyy').format(exp.expenditureDate),
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'title_vendor',
            group: 'Expense Record',
            label: 'TITLE & VENDOR',
            defaultWidth: 240,
            minWidth: 180,
            searchString: (exp) => '${exp.title} ${exp.vendorName ?? ""}',
            sortValue: (exp) => exp.title,
            cellBuilder: (ctx, exp, row, isDark, brand) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(exp.title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (exp.vendorName != null && exp.vendorName!.isNotEmpty)
                  Text('Vendor: ${exp.vendorName}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'category',
            group: 'Classification',
            label: 'CATEGORY',
            defaultWidth: 180,
            minWidth: 140,
            searchString: (exp) => exp.category.label,
            sortValue: (exp) => exp.category.label,
            cellBuilder: (ctx, exp, row, isDark, brand) {
              final catColor = _getCategoryColor(exp.category);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(exp.category), size: 13, color: catColor),
                    const SizedBox(width: 5),
                    Text(exp.category.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor)),
                  ],
                ),
              );
            },
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'station',
            group: 'Classification',
            label: 'STATION',
            defaultWidth: 160,
            minWidth: 120,
            searchString: (exp) => _getDcName(exp.distributionCenterId, dcs),
            sortValue: (exp) => _getDcName(exp.distributionCenterId, dcs),
            cellBuilder: (ctx, exp, row, isDark, brand) => Text(
              _getDcName(exp.distributionCenterId, dcs),
              style: GoogleFonts.inter(fontSize: 11.5),
            ),
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'invoice_method',
            group: 'Payment Info',
            label: 'INVOICE / METHOD',
            defaultWidth: 160,
            minWidth: 120,
            searchString: (exp) => '${exp.invoiceNumber ?? ""} ${exp.paymentMethod ?? ""}',
            cellBuilder: (ctx, exp, row, isDark, brand) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (exp.invoiceNumber != null && exp.invoiceNumber!.isNotEmpty)
                  Text(exp.invoiceNumber!, style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600)),
                Text(exp.paymentMethod ?? 'Direct Transfer', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'amount',
            group: 'Financial Value',
            label: 'AMOUNT (₦)',
            defaultWidth: 140,
            minWidth: 110,
            sortValue: (exp) => exp.amount,
            cellBuilder: (ctx, exp, row, isDark, brand) => Text(
              _currencyFormat.format(exp.amount),
              style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFF43F5E)),
            ),
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'receipt',
            group: 'Audit Documents',
            label: 'RECEIPT',
            defaultWidth: 120,
            minWidth: 90,
            cellBuilder: (ctx, exp, row, isDark, brand) {
              final hasReceipt = exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty;
              if (!hasReceipt) return const Text('No Receipt', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
              return TextButton.icon(
                onPressed: () => DCReceiptPreviewModal.show(context, exp, dcName: _getDcName(exp.distributionCenterId, dcs)),
                icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFF37021)),
                label: const Text('View', style: TextStyle(fontSize: 11, color: Color(0xFFF37021))),
              );
            },
          ),
          ExcelColumnDef<BusinessExpenditureEntity>(
            key: 'action',
            group: 'Audit Documents',
            label: 'ACTION',
            defaultWidth: 90,
            minWidth: 70,
            cellBuilder: (ctx, exp, row, isDark, brand) => IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF43F5E)),
              tooltip: 'Delete Expenditure',
              onPressed: () => _confirmDelete(exp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLedgerCard(BusinessExpenditureEntity exp, bool isDark, List<DistributionCenter> dcs) {
    final catColor = _getCategoryColor(exp.category);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(exp.category.label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: catColor)),
              ),
              Text(
                _currencyFormat.format(exp.amount),
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFF37021)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(exp.title, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('MMM dd, yyyy').format(exp.expenditureDate)} • ${_getDcName(exp.distributionCenterId, dcs)}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exp.invoiceNumber?.isNotEmpty == true ? 'Inv #${exp.invoiceNumber}' : (exp.vendorName ?? 'Station Expense'),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
              Row(
                children: [
                  if (exp.hasReceipt)
                    IconButton(
                      icon: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF10B981)),
                      onPressed: () => DCReceiptPreviewModal.show(context, exp, dcName: _getDcName(exp.distributionCenterId, dcs)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDelete(exp),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLedgerState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No station expenditures recorded for this period', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: DELIVERY OPERATIONS & ROOT CAUSE
  // ==========================================
  Widget _buildDeliveryOperationsTab(DCExpendituresState state, bool isDark, bool isDesktop) {
    final failure = state.failureBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fulfillment Summary Bar
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: Color(0xFF3B82F6), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Delivery Performance & Fulfillment Rate',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SUCCESS RATE: ${state.deliverySuccessRate.toStringAsFixed(2)}%',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUnitMetric('Total Assigned Orders', state.totalOrdersAssigned.toString(), isDark),
                  _buildUnitMetric('Delivered Orders', state.totalOrdersDelivered.toString(), isDark),
                  _buildUnitMetric('Undelivered Orders', state.totalOrdersUndelivered.toString(), isDark),
                  _buildUnitMetric('Undelivered Failure Rate', '${state.undeliveredRate.toStringAsFixed(2)}%', isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Root Cause Failure Attribution (Section 3a in Report)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rule_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Breakdown of Undelivered Orders (Root Cause Analysis)',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildFailureRow('Customer-Related Factor (unreachable, switched-off, rescheduled, insufficient funds, absent)', failure['customerNum'], failure['customerPct'], const Color(0xFFEF4444), isDark),
              _buildFailureRow('Sales Representative Factor (dispatched without customer confirmation, address incomplete)', failure['salesRepNum'], failure['salesRepPct'], const Color(0xFFF59E0B), isDark),
              _buildFailureRow('Rider / Logistics Factor (bike breakdown, illness, heavy traffic, weather)', failure['riderNum'], failure['riderPct'], const Color(0xFF3B82F6), isDark),
              _buildFailureRow('Customer Cancelled Orders', failure['cancelledNum'], failure['cancelledPct'], const Color(0xFF64748B), isDark),
              const SizedBox(height: 12),

              // Operational Findings & Recommendations Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Executive Operational Finding:',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Customer and sales rep factors together account for 94.85% of all failed deliveries.\n'
                      '• The sales rep confirmation factor (30.93%) is within direct management control.\n'
                      '• Action: Enforce mandatory customer confirmation logs before dispatching to riders.',
                      style: GoogleFonts.inter(fontSize: 11.5, height: 1.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Rider League Scorecard Table (Section 4 in Report)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFF37021), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rider Performance League & Scorecards',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: state.riderScorecards.map((r) {
                  final score = (r['score'] as num?)?.toDouble() ?? 0.0;
                  final isTop = score >= 70.0;
                  return Container(
                    width: isDesktop ? 220 : 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r['name'].toString(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isTop ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${score.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: isTop ? const Color(0xFF10B981) : const Color(0xFFD97706))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${r['bike']} • ${r['deliveries']} deliveries', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFailureRow(String cause, dynamic number, dynamic percentage, Color barColor, bool isDark) {
    final pct = (percentage as num?)?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(cause, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ),
              Text('$number orders (${pct.toStringAsFixed(1)}%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: MOM GROWTH & COMPARISONS
  // ==========================================
  Widget _buildMomGrowthTab(DCExpendituresState state, bool isDark, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Growth Matrix Table (Table 5 in Report)
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.stacked_line_chart_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Multi-Month Growth Trends (June – Current Period)',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('METRIC')),
                    DataColumn(label: Text('JUNE')),
                    DataColumn(label: Text('JULY')),
                    DataColumn(label: Text('AUGUST')),
                    DataColumn(label: Text('SEPTEMBER')),
                    DataColumn(label: Text('CURRENT PERIOD')),
                    DataColumn(label: Text('MOM GROWTH')),
                  ],
                  rows: state.momTrends.map((m) {
                    final isPositive = m['growth'].toString().contains('↑');
                    final isNegative = m['growth'].toString().contains('↓');
                    final growColor = isPositive ? const Color(0xFF10B981) : (isNegative ? const Color(0xFFEF4444) : const Color(0xFF64748B));
                    return DataRow(
                      cells: [
                        DataCell(Text(m['metric'].toString(), style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700))),
                        DataCell(Text(m['june'].toString(), style: GoogleFonts.inter(fontSize: 12))),
                        DataCell(Text(m['july'].toString(), style: GoogleFonts.inter(fontSize: 12))),
                        DataCell(Text(m['august'].toString(), style: GoogleFonts.inter(fontSize: 12))),
                        DataCell(Text(m['september'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                        DataCell(Text(m['current'].toString(), style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: const Color(0xFFF37021)))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: growColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                            child: Text(m['growth'].toString(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: growColor)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Key Achievements & Operational Challenges Cards (Section 6 & 7 in Report)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Text('Key Business Achievements', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Highest logistics revenue achieved at ₦7,635,000.\n'
                      '• Gross margin improved to 62.75% from 61.45%.\n'
                      '• Revenue per delivered order climbed 12.0% to ₦6,238.\n'
                      '• Strategic Lagos expansion project successfully funded.\n'
                      '• Content creation hardware acquired for digital media.',
                      style: GoogleFonts.inter(fontSize: 12, height: 1.6, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Text('Key Operational Challenges', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Delivery completion rate contracted to 71.62%.\n'
                      '• 94.85% of failures caused by customer absence and sales rep dispatch issues.\n'
                      '• Rider wage entitlement per delivered order up 9.9%.\n'
                      '• Heavy single-line Capex on Other Expenses.',
                      style: GoogleFonts.inter(fontSize: 12, height: 1.6, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
