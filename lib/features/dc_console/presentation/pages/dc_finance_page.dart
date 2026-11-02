import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/audit_logging_service.dart';
import '../../../../core/widgets/nova_tooltip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/domain/entities/business_expenditure.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../../client_portal/presentation/widgets/client_settlement_detail_modal.dart';
import '../../../client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';
import '../providers/dc_expenditures_provider.dart';
import '../services/dc_finance_excel_exporter.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../widgets/dc_transaction_audit_modal.dart';
import '../widgets/dc_create_expenditure_modal.dart';
import '../widgets/dc_daily_merchant_settlement_modal.dart';
import '../widgets/dc_receipt_preview_modal.dart';
import 'dc_order_payment_matching_page.dart';

/// Unified DC Finance Hub Page
/// Modularized into 3 sub-tabs: Dashboard, Income, and Expenses.
/// Re-implements Rider Remittance verification inside Income for clean ergonomics.
class DCFinancePage extends ConsumerStatefulWidget {
  final int initialSubtab;
  final String initialIncomeView;

  const DCFinancePage({
    super.key,
    this.initialSubtab = 0,
    this.initialIncomeView = 'breakdown',
  });

  @override
  ConsumerState<DCFinancePage> createState() => _DCFinancePageState();
}

class _DCFinancePageState extends ConsumerState<DCFinancePage> {
  late int _activeSubtab;
  late String _incomeView; // 'breakdown' or 'remittances'

  // Global Financial Filters
  String _datePreset = '30D';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedMerchantId;
  String? _selectedProductName;

  // Search & Tab-Specific Filters
  final TextEditingController _searchController = TextEditingController();
  String _incomeStatusFilter = 'all'; // 'all', 'unsettled', 'awaiting_validation', 'settled'
  String _expenseCategoryFilter = 'all';

  bool _isExporting = false;
  String _auditCategoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _activeSubtab = widget.initialSubtab.clamp(0, 2);
    _incomeView = widget.initialIncomeView;
    _applyPreset('30D');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final activeHubId = ref.read(dcConsoleProvider).activeHubId;
        ref.read(ordersProvider.notifier).loadDcOrders(activeHubId);
        ref.read(financeProvider.notifier).loadRemittances(activeHubId);
        ref.read(dcExpendituresProvider.notifier).loadExpenditures();
        ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements();
        ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
        ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    switch (preset) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case '7D':
        start = now.subtract(const Duration(days: 7));
        break;
      case '30D':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'All Time':
        start = null;
        end = null;
        break;
      case 'Custom':
        // Keep existing custom dates
        return;
    }

    setState(() {
      _datePreset = preset;
      _startDate = start;
      _endDate = end;
    });
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

  Future<void> _exportExcel(
    DCConsoleState dcState,
    DCExpendituresState expState,
    List<OrderEntity> orders,
  ) async {
    setState(() => _isExporting = true);
    try {
      final activeOrders = _filterOrders(orders, dcState);
      final deliveredOrders = activeOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
      final totalRevenue = deliveredOrders.fold(0.0, (s, o) => s + o.clientDeliveryFee);
      final riderWages = deliveredOrders.length * dcState.financeSettings.defaultCommissionRate;
      final fuelCost = deliveredOrders.length * (dcState.financeSettings.defaultTransportAllowance / 10.0).clamp(100.0, 800.0);
      final filteredExp = _filterExpenditures(expState.expenditures, dcState);
      final totalOpex = filteredExp.fold(0.0, (s, e) => s + e.amount);

      final ok = await DcFinanceExcelExporter.exportFinancialReport(
        periodName: _datePreset,
        stationName: dcState.activeHubName,
        totalRevenue: totalRevenue,
        riderWages: riderWages,
        fuelAndMaintenance: fuelCost,
        airtimeAndData: 0.0,
        totalDirectCosts: riderWages + fuelCost,
        grossProfit: totalRevenue - (riderWages + fuelCost),
        grossProfitMargin: totalRevenue > 0 ? ((totalRevenue - (riderWages + fuelCost)) / totalRevenue) * 100 : 0.0,
        adminSalaries: 0.0,
        officeExpenses: totalOpex,
        otherExpenses: 0.0,
        totalOpex: totalOpex,
        netProfit: totalRevenue - (riderWages + fuelCost + totalOpex),
        netProfitMargin: totalRevenue > 0 ? ((totalRevenue - (riderWages + fuelCost + totalOpex)) / totalRevenue) * 100 : 0.0,
        adjustedNetProfit: totalRevenue - (riderWages + fuelCost + totalOpex),
        totalOrdersAssigned: activeOrders.length,
        totalOrdersDelivered: deliveredOrders.length,
        deliverySuccessRate: activeOrders.isNotEmpty ? (deliveredOrders.length / activeOrders.length) * 100 : 0.0,
        expenditures: filteredExp,
        dcs: dcState.distributionCenters,
        failureBreakdown: {},
        riderScorecards: [],
        momTrends: [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Excel report generated successfully' : 'Could not export Excel report'),
            backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<OrderEntity> _filterOrders(List<OrderEntity> allOrders, DCConsoleState dcState) {
    final isGrandDcCumulative = dcState.isCurrentHubGrandDc && dcState.selectedDcId == null;
    final activeDc = dcState.distributionCenters.where(
      (d) => d.id == dcState.activeHubId || d.code == dcState.activeHubCode,
    ).firstOrNull;

    return allOrders.where((order) {
      if (!isGrandDcCumulative && activeDc != null) {
        if (!OrderRoutingService.doesOrderBelongToDc(
          order: order,
          currentDc: activeDc,
          allDcs: dcState.distributionCenters,
        )) {
          return false;
        }
      }

      if (_selectedMerchantId != null && _selectedMerchantId!.isNotEmpty) {
        if (order.merchantId != _selectedMerchantId && order.clientId != _selectedMerchantId) {
          return false;
        }
      }

      if (_selectedProductName != null && _selectedProductName!.isNotEmpty) {
        final prod = order.productName.toLowerCase();
        if (!prod.contains(_selectedProductName!.toLowerCase())) {
          return false;
        }
      }

      if (_startDate != null && order.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && order.createdAt.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<BusinessExpenditureEntity> _filterExpenditures(
    List<BusinessExpenditureEntity> allExp,
    DCConsoleState dcState,
  ) {
    final isGrandDcCumulative = dcState.isCurrentHubGrandDc && dcState.selectedDcId == null;
    final activeDcId = dcState.activeDcId;

    return allExp.where((exp) {
      if (!isGrandDcCumulative) {
        if (exp.distributionCenterId != null && exp.distributionCenterId!.isNotEmpty) {
          if (exp.distributionCenterId != activeDcId) return false;
        }
      }

      if (_startDate != null && exp.expenditureDate.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && exp.expenditureDate.isAfter(_endDate!)) {
        return false;
      }

      if (_expenseCategoryFilter != 'all') {
        if (exp.category.name.toLowerCase() != _expenseCategoryFilter.toLowerCase()) {
          return false;
        }
      }

      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchVendor = (exp.vendorName ?? '').toLowerCase().contains(query);
        final matchVoucher = (exp.invoiceNumber ?? '').toLowerCase().contains(query);
        final matchDesc = (exp.description ?? '').toLowerCase().contains(query);
        if (!matchVendor && !matchVoucher && !matchDesc) return false;
      }

      return true;
    }).toList();
  }

  List<DCTransactionRecord> _filterTransactions(
    List<DCTransactionRecord> allTxns,
    DCConsoleState dcState,
  ) {
    final isGrandDcCumulative = dcState.isCurrentHubGrandDc && dcState.selectedDcId == null;
    final dcRiderIds = isGrandDcCumulative
        ? dcState.drivers.map((d) => d.id).toSet()
        : dcState.dcDrivers.map((d) => d.id).toSet();
    final dcRiderCodes = isGrandDcCumulative
        ? dcState.drivers.map((d) => d.driverCode.toLowerCase()).toSet()
        : dcState.dcDrivers.map((d) => d.driverCode.toLowerCase()).toSet();

    return allTxns.where((txn) {
      if (!isGrandDcCumulative) {
        final matchesRider = dcRiderIds.contains(txn.riderId) || dcRiderCodes.contains(txn.riderCode.toLowerCase());
        if (!matchesRider) return false;
      }

      if (_selectedProductName != null && _selectedProductName!.isNotEmpty) {
        final prod = (txn.productName ?? '').toLowerCase();
        if (!prod.contains(_selectedProductName!.toLowerCase())) {
          return false;
        }
      }

      if (_startDate != null && txn.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && txn.createdAt.isAfter(_endDate!)) {
        return false;
      }

      if (_auditCategoryFilter != 'all') {
        if (_auditCategoryFilter == 'cash' && !txn.isCashPod) return false;
        if (_auditCategoryFilter == 'gateway' && !txn.isPaystack) return false;
        if (_auditCategoryFilter == 'remittance' && !txn.isRemittance) return false;
      }

      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchRef = txn.transactionCode.toLowerCase().contains(query);
        final matchOrder = (txn.orderNumber ?? '').toLowerCase().contains(query);
        final matchRider = txn.riderName.toLowerCase().contains(query);
        final matchCust = (txn.customerName ?? '').toLowerCase().contains(query);
        if (!matchRef && !matchOrder && !matchRider && !matchCust) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<RemittanceEntity> _filterRemittances(
    List<RemittanceEntity> allRem,
    DCConsoleState dcState,
  ) {
    final isGrandDcCumulative = dcState.isCurrentHubGrandDc && dcState.selectedDcId == null;
    final activeDcId = dcState.activeDcId;
    final dcRiderIds = isGrandDcCumulative
        ? dcState.drivers.map((d) => d.id).toSet()
        : dcState.dcDrivers.map((d) => d.id).toSet();

    return allRem.where((rem) {
      if (!isGrandDcCumulative) {
        if (rem.distributionCenterId != null && rem.distributionCenterId!.isNotEmpty) {
          if (rem.distributionCenterId != activeDcId) return false;
        } else if (!dcRiderIds.contains(rem.deliveryAgentId)) {
          return false;
        }
      }

      if (_startDate != null && rem.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && rem.createdAt.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 850;

    final dcState = ref.watch(dcConsoleProvider);
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);
    final expState = ref.watch(dcExpendituresProvider);
    final settlementsAsync = ref.watch(dcClientSettlementsProvider(dcState.activeDcId));
    final settlements = settlementsAsync.valueOrNull ?? const [];

    final scopedOrders = _filterOrders(ordersState.orders, dcState);
    final scopedExpenditures = _filterExpenditures(expState.expenditures, dcState);
    final scopedRemittances = _filterRemittances(financeState.remittances, dcState);
    final scopedTransactions = _filterTransactions(dcState.transactions, dcState);

    // Collect Unique Products for filter dropdown
    final productNames = <String>{};
    for (final o in ordersState.orders) {
      if (o.productName.isNotEmpty) {
        productNames.add(o.productName);
      }
    }
    for (final b in dcState.warehouseBatches) {
      if (b.productName.isNotEmpty) {
        productNames.add(b.productName);
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF031632) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Sleek Unified Top Header & Global Filter Bar
          _buildMasterHeader(
            isDark: isDark,
            isCompact: isCompact,
            dcState: dcState,
            expState: expState,
            orders: ordersState.orders,
            productNames: productNames.toList(),
          ),

          // 2. Active Sub-Tab View (Dashboard, Income, Expenses)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildSubtabBody(
                isDark: isDark,
                isCompact: isCompact,
                dcState: dcState,
                expState: expState,
                orders: scopedOrders,
                expenditures: scopedExpenditures,
                remittances: scopedRemittances,
                settlements: settlements,
                transactions: scopedTransactions,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MASTER HEADER & GLOBAL CONTROLS
  // ==========================================
  Widget _buildMasterHeader({
    required bool isDark,
    required bool isCompact,
    required DCConsoleState dcState,
    required DCExpendituresState expState,
    required List<OrderEntity> orders,
    required List<String> productNames,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 22, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071B39) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title, Subtabs Selector, and Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title + Sub-Tabs Pill Ribbon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF37021), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Finance',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 18 : 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const NovaInfoIcon(
                    tooltip: 'Financial hub combining revenue, merchant settlements, rider remittances and station OpEx',
                    size: 15,
                  ),
                  const SizedBox(width: 16),

                  // Subtabs Switcher: [ Dashboard | Income | Expenses ]
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSubtabPill(0, 'Dashboard', Icons.insights_rounded, isDark),
                        _buildSubtabPill(1, 'Income', Icons.trending_up_rounded, isDark),
                        _buildSubtabPill(2, 'Expenses', Icons.trending_down_rounded, isDark),
                      ],
                    ),
                  ),
                ],
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activeSubtab == 2)
                    NovaTooltip(
                      message: 'Record a new operational expense voucher or station receipt',
                      child: ElevatedButton.icon(
                        onPressed: () => DCCreateExpenditureModal.show(context, initialDcId: dcState.activeDcId),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Record OpEx',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF37021),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    )
                  else if (_activeSubtab == 1 && _incomeView == 'breakdown')
                    NovaTooltip(
                      message: 'Initiate merchant settlement payout and upload transfer receipt',
                      child: ElevatedButton.icon(
                        onPressed: () => _openMerchantSettlementPicker(context, dcState, orders),
                        icon: const Icon(Icons.payments_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Settle Client',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  NovaTooltip(
                    message: 'Export financial statement and audit ledger to Excel',
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : () => _exportExcel(dcState, expState, orders),
                      icon: _isExporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.table_view_rounded, size: 15),
                      label: Text(
                        'Export Excel',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Date Range Capsule Ribbon, Merchant Filter, and Product Filter
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Range Capsule Ribbon
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDatePill('Today', isDark),
                    _buildDatePill('7D', isDark),
                    _buildDatePill('30D', isDark),
                    _buildDatePill('This Month', isDark),
                    _buildDatePill('All Time', isDark),
                    IconButton(
                      tooltip: 'Pick custom date range',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                        color: _datePreset == 'Custom' ? const Color(0xFFF37021) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      onPressed: () async {
                        final result = await PangeaDateRangePickerModal.show(
                          context,
                          initialStartDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                          initialEndDate: _endDate ?? DateTime.now(),
                          initialPreset: DateRangePreset.custom,
                        );
                        if (result != null) {
                          setState(() {
                            _datePreset = 'Custom';
                            _startDate = result.startDate;
                            _endDate = result.endDate;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Merchant Filter Dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedMerchantId,
                    hint: Text('All Merchants', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Merchants', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                      ...dcState.clients.map((c) {
                        return DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            c.companyName,
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedMerchantId = val),
                  ),
                ),
              ),

              // Product Filter Dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedProductName,
                    hint: Text('All Products', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Products', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                      ...productNames.map((p) {
                        return DropdownMenuItem<String?>(
                          value: p,
                          child: Text(
                            p,
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedProductName = val),
                  ),
                ),
              ),

              // Reset Filters if applied
              if (_selectedMerchantId != null || _selectedProductName != null || _datePreset != '30D')
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMerchantId = null;
                      _selectedProductName = null;
                      _applyPreset('30D');
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          'Reset',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtabPill(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeSubtab == index;
    return InkWell(
      onTap: () => setState(() => _activeSubtab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E2D4A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? const Color(0xFFF37021)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePill(String label, bool isDark) {
    final isSelected = _datePreset == label;
    return InkWell(
      onTap: () => _applyPreset(label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFFF37021) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BODY SWITCHER
  // ==========================================
  Widget _buildSubtabBody({
    required bool isDark,
    required bool isCompact,
    required DCConsoleState dcState,
    required DCExpendituresState expState,
    required List<OrderEntity> orders,
    required List<BusinessExpenditureEntity> expenditures,
    required List<RemittanceEntity> remittances,
    required List<ClientSettlement> settlements,
    required List<DCTransactionRecord> transactions,
  }) {
    switch (_activeSubtab) {
      case 0:
        return _buildDashboardSubtab(
          isDark: isDark,
          isCompact: isCompact,
          dcState: dcState,
          orders: orders,
          expenditures: expenditures,
          remittances: remittances,
          settlements: settlements,
          transactions: transactions,
        );
      case 1:
        return _buildIncomeSubtab(
          isDark: isDark,
          isCompact: isCompact,
          dcState: dcState,
          orders: orders,
          remittances: remittances,
          settlements: settlements,
        );
      case 2:
        return _buildExpensesSubtab(
          isDark: isDark,
          isCompact: isCompact,
          dcState: dcState,
          expState: expState,
          expenditures: expenditures,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // SUB-TAB 1: FINANCE DASHBOARD
  // ==========================================
  Widget _buildDashboardSubtab({
    required bool isDark,
    required bool isCompact,
    required DCConsoleState dcState,
    required List<OrderEntity> orders,
    required List<BusinessExpenditureEntity> expenditures,
    required List<RemittanceEntity> remittances,
    required List<ClientSettlement> settlements,
    required List<DCTransactionRecord> transactions,
  }) {
    final deliveredOrders = orders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final grossInflow = deliveredOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final deliveryFeesCollected = deliveredOrders.fold(0.0, (s, o) => s + o.clientDeliveryFee);
    final riderWages = deliveredOrders.length * dcState.financeSettings.defaultCommissionRate;
    final fuelCost = deliveredOrders.length * (dcState.financeSettings.defaultTransportAllowance / 10.0).clamp(100.0, 800.0);
    final totalOpex = expenditures.fold(0.0, (s, e) => s + e.amount);

    final netMargin = deliveryFeesCollected - (riderWages + fuelCost + totalOpex);
    final marginPct = deliveryFeesCollected > 0 ? (netMargin / deliveryFeesCollected) * 100 : 0.0;
    final vaultCash = remittances.where((r) => r.isVerified).fold(0.0, (s, r) => s + r.amount);
    final unsettledSettlements = settlements.where((s) => !s.isCompleted).fold(0.0, (s, st) => s + st.netPayoutAmount);

    // Audit / Fund Movement Telemetry (Fused from Audit)
    final totalTxnVolume = transactions.fold(0.0, (s, t) => s + t.amount);
    final grossVolume = totalTxnVolume > 0 ? totalTxnVolume : grossInflow;
    final cashHandled = transactions.where((t) => t.isCashPod).fold(0.0, (s, t) => s + t.amount);
    final totalRiderEntitlements = transactions.fold(0.0, (s, t) => s + t.totalRiderEntitlement);
    final effectiveRiderEarnings = totalRiderEntitlements > 0 ? totalRiderEntitlements : (riderWages + fuelCost);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Telemetry Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 600
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 1100
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Net Margin',
                      CurrencyFormatter.formatNaira(netMargin),
                      '${marginPct.toStringAsFixed(1)}% Margin',
                      Icons.insights_rounded,
                      netMargin >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      isDark,
                      tooltip: 'Delivery billing fees minus driver commissions, fuel allowance, and station OpEx',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Gross Inflow',
                      CurrencyFormatter.formatNaira(grossInflow),
                      '${deliveredOrders.length} Delivered',
                      Icons.payments_rounded,
                      const Color(0xFF0284C7),
                      isDark,
                      tooltip: 'Total delivery value and collections from completed orders',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Total OpEx',
                      CurrencyFormatter.formatNaira(totalOpex),
                      '${expenditures.length} Vouchers',
                      Icons.receipt_long_rounded,
                      const Color(0xFFF97316),
                      isDark,
                      tooltip: 'Total operating expenses recorded across this distribution facility',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Vault Cash',
                      CurrencyFormatter.formatNaira(vaultCash),
                      '${remittances.length} Settlements',
                      Icons.account_balance_rounded,
                      const Color(0xFF8B5CF6),
                      isDark,
                      tooltip: 'Total verified cash collections deposited into station vault',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Secondary Fused Audit Telemetry Row (Fund Movement & Rider Entitlements)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 600
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 1100
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Gross Fund Volume',
                      CurrencyFormatter.formatNaira(grossVolume),
                      '${transactions.isNotEmpty ? transactions.length : deliveredOrders.length} Transactions',
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF2563EB),
                      isDark,
                      tooltip: 'Cumulative monetary volume across all customer orders and collection events',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Cash Handled (POD)',
                      CurrencyFormatter.formatNaira(cashHandled > 0 ? cashHandled : (grossInflow - deliveryFeesCollected)),
                      'Courier Handover Cash 💵',
                      Icons.payments_rounded,
                      const Color(0xFF10B981),
                      isDark,
                      tooltip: 'Physical cash collected from customers by dispatch riders at delivery',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Rider Earnings',
                      CurrencyFormatter.formatNaira(effectiveRiderEarnings),
                      'Commissions & Wages 🛵',
                      Icons.two_wheeler_rounded,
                      const Color(0xFFF37021),
                      isDark,
                      tooltip: 'Total courier commission entitlements and transport allowances',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Pending Settlements',
                      CurrencyFormatter.formatNaira(unsettledSettlements),
                      '${settlements.where((s) => !s.isCompleted).length} Awaiting Sign-off ⏳',
                      Icons.hourglass_top_rounded,
                      const Color(0xFFF59E0B),
                      isDark,
                      tooltip: 'Merchant remittances currently pending sign-off or accountant clearance',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Inflow vs Outflow Visual Telemetry Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF071B39) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded, color: Color(0xFFF37021), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Financial Pulse',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        const NovaInfoIcon(tooltip: 'Proportional comparison of revenue inflow vs operating outflows'),
                      ],
                    ),
                    Text(
                      'Audited Cashflow',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Proportion Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        // Net Margin Bar (Green)
                        Expanded(
                          flex: (netMargin > 0 ? netMargin : 0).toInt().clamp(1, 1000000),
                          child: Container(color: const Color(0xFF10B981)),
                        ),
                        // OpEx Bar (Orange)
                        Expanded(
                          flex: totalOpex.toInt().clamp(1, 1000000),
                          child: Container(color: const Color(0xFFF97316)),
                        ),
                        // Fleet Commission Bar (Sky)
                        Expanded(
                          flex: riderWages.toInt().clamp(1, 1000000),
                          child: Container(color: const Color(0xFF0284C7)),
                        ),
                        // Fuel Bar (Amber)
                        Expanded(
                          flex: fuelCost.toInt().clamp(1, 1000000),
                          child: Container(color: const Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem('Net Margin', CurrencyFormatter.formatNaira(netMargin), const Color(0xFF10B981)),
                    _buildLegendItem('Station OpEx', CurrencyFormatter.formatNaira(totalOpex), const Color(0xFFF97316)),
                    _buildLegendItem('Fleet Wages', CurrencyFormatter.formatNaira(riderWages), const Color(0xFF0284C7)),
                    _buildLegendItem('Fleet Fuel', CurrencyFormatter.formatNaira(fuelCost), const Color(0xFFF59E0B)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Two-Column Grid: Revenue Stream Breakdown & OpEx Distribution
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 900;
              final colWidth = isTwoCol ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Revenue Streams Card
                  SizedBox(
                    width: colWidth,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF071B39) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Text('Revenue Streams', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildStreamRow('Delivery Billings', deliveryFeesCollected, grossInflow, const Color(0xFF10B981)),
                          _buildStreamRow('COD Collections', grossInflow - deliveryFeesCollected, grossInflow, const Color(0xFF0284C7)),
                          _buildStreamRow('Vault Remittances', vaultCash, grossInflow, const Color(0xFF8B5CF6)),
                          _buildStreamRow('Pending Settlement', unsettledSettlements, grossInflow, const Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                  ),

                  // OpEx Category Allocation Card
                  SizedBox(
                    width: colWidth,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF071B39) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_rounded, color: Color(0xFFF97316), size: 18),
                              const SizedBox(width: 8),
                              Text('OpEx Allocation', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const Divider(height: 20),
                          if (expenditures.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No expenditures recorded', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                              ),
                            )
                          else
                            ...ExpenditureCategory.values.take(4).map((cat) {
                              final catTotal = expenditures.where((e) => e.category == cat).fold(0.0, (s, e) => s + e.amount);
                              return _buildStreamRow(cat.name.toUpperCase(), catTotal, totalOpex, _getCategoryColor(cat));
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 22),

          // 4. Fused Audit & Fund Movement Ledger
          _buildFundMovementAuditSection(
            isDark: isDark,
            isCompact: isCompact,
            transactions: transactions,
            dcState: dcState,
          ),
        ],
      ),
    );
  }


  // ==========================================
  // FUSED AUDIT & FUND MOVEMENT LEDGER
  // ==========================================
  Widget _buildFundMovementAuditSection({
    required bool isDark,
    required bool isCompact,
    required List<DCTransactionRecord> transactions,
    required DCConsoleState dcState,
  }) {
    final cashCount = transactions.where((t) => t.isCashPod).length;
    final gatewayCount = transactions.where((t) => t.isPaystack).length;
    final remittanceCount = transactions.where((t) => t.isRemittance).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071B39) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
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
        children: [
          // Header Row: Title, Subtitle, and Sync Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fund Movement & Audit Trail',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Live audited movement of customer collections, remittances, and merchant settlements',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transactions audit ledger refreshed from database.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF0284C7),
                    ),
                  );
                },
                icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Sync Live',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Filter Pills Row (Reactively switches categories)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildAuditFilterChip('all', 'All Movements (${transactions.length})', _auditCategoryFilter == 'all', isDark),
                const SizedBox(width: 8),
                _buildAuditFilterChip('cash', 'Cash POD ($cashCount)', _auditCategoryFilter == 'cash', isDark),
                const SizedBox(width: 8),
                _buildAuditFilterChip('gateway', 'Gateway / Bank ($gatewayCount)', _auditCategoryFilter == 'gateway', isDark),
                const SizedBox(width: 8),
                _buildAuditFilterChip('remittance', 'Rider Remittances ($remittanceCount)', _auditCategoryFilter == 'remittance', isDark),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Audit Ledger Items
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No Audit Transactions Found',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No financial movement recorded for the selected date range or criteria.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.take(15).length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return _buildAuditTransactionRow(context, txn, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAuditFilterChip(String key, String label, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _auditCategoryFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : (isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditTransactionRow(BuildContext context, DCTransactionRecord txn, bool isDark) {
    final isCash = txn.isCashPod;
    final isRemittance = txn.isRemittance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCash
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : (isRemittance
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                      : const Color(0xFF0284C7).withValues(alpha: 0.12)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCash
                  ? Icons.payments_rounded
                  : (isRemittance ? Icons.account_balance_rounded : Icons.bolt_rounded),
              size: 18,
              color: isCash
                  ? const Color(0xFF10B981)
                  : (isRemittance ? const Color(0xFF8B5CF6) : const Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(width: 12),

          // Reference & Customer Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      txn.transactionCode,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF031632) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        txn.category.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                Text(
                  txn.orderNumber != null
                      ? 'Order #${txn.orderNumber} • ${txn.customerName ?? "General Consignment"}'
                      : (txn.customerName ?? 'Direct Settlement Entry'),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Courier & Channel
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.riderName,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${txn.channel} • ${DateFormat("MMM dd, hh:mm a").format(txn.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatNaira(txn.amount),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rider: ${CurrencyFormatter.formatNaira(txn.totalRiderEntitlement)}',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Action Button
          OutlinedButton(
            onPressed: () => DCTransactionAuditModal.show(context, txn, isDark: isDark),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFCBD5E1)),
            ),
            child: Text(
              'Audit',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamRow(String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ==========================================
  // SUB-TAB 2: INCOME (BREAKDOWN + REMITTANCES)
  // ==========================================
  Widget _buildIncomeSubtab({
    required bool isDark,
    required bool isCompact,
    required DCConsoleState dcState,
    required List<OrderEntity> orders,
    required List<RemittanceEntity> remittances,
    required List<ClientSettlement> settlements,
  }) {
    // If user toggled into the integrated Remittances flow, render the full DCOrderPaymentMatchingPage!
    if (_incomeView == 'remittances') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF071B39) : const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFFF37021), size: 18),
                    const SizedBox(width: 8),
                    Text('Rider Remittances', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _incomeView = 'breakdown'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 14),
                  label: Text('Back Breakdown', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Expanded(child: DCOrderPaymentMatchingPage()),
        ],
      );
    }

    // Otherwise render the 8-Column Income Breakdown Matrix
    final deliveredOrders = orders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final failedOrders = orders.where((o) =>
        o.status.toLowerCase() == 'failed' ||
        o.status.toLowerCase() == 'returned' ||
        o.status.toLowerCase() == 'cancelled'
    ).toList();

    final deliveredVal = deliveredOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final failedVal = failedOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final totalSettlementAmount = settlements.fold(0.0, (s, st) => s + st.netPayoutAmount);

    // Group orders by Merchant / Client
    final Map<String, List<OrderEntity>> ordersByClient = {};
    for (final o in orders) {
      final key = (o.merchantId != null && o.merchantId!.isNotEmpty)
          ? o.merchantId!
          : (o.clientId != null && o.clientId!.isNotEmpty ? o.clientId! : 'other');
      ordersByClient.putIfAbsent(key, () => []).add(o);
    }

    // Build client rows
    final clientRows = dcState.clients.map((client) {
      final clientOrders = ordersByClient[client.id] ?? [];
      final del = clientOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
      final fail = clientOrders.where((o) =>
          o.status.toLowerCase() == 'failed' ||
          o.status.toLowerCase() == 'returned' ||
          o.status.toLowerCase() == 'cancelled'
      ).toList();

      final delCount = del.length;
      final delValue = del.fold(0.0, (s, o) => s + o.totalAmount);
      final failCount = fail.length;
      final failValue = fail.fold(0.0, (s, o) => s + o.totalAmount);

      // Delivery fee deduction
      final feePerOrder = client.customDeliveryFee ?? dcState.financeSettings.defaultClientDeliveryFee;
      final totalDeductions = delCount * feePerOrder;
      final settlementAmount = (delValue - totalDeductions).clamp(0.0, delValue);

      // Fuel money: ₦0 for PDA riders, accounted for in-house
      double fuelMoney = 0.0;
      for (final o in del) {
        final driver = dcState.drivers.where((d) => d.id == o.deliveryAgentId || d.driverCode.toLowerCase() == o.deliveryAgentCode?.toLowerCase()).firstOrNull;
        final isPda = driver?.isPda == true;
        if (!isPda) {
          fuelMoney += (dcState.financeSettings.defaultTransportAllowance / 10.0).clamp(100.0, 800.0);
        }
      }

      // Rider commission
      final riderCommission = del.fold(0.0, (s, o) => s + (o.agentEntitlement > 0 ? o.agentEntitlement : dcState.financeSettings.defaultCommissionRate));

      // Settlement status check
      final clientSettlements = settlements.where((s) => s.clientId == client.id).toList();
      String status = 'Unsettled';
      ClientSettlement? activeSettlement;

      if (clientSettlements.isNotEmpty) {
        final latest = clientSettlements.first;
        activeSettlement = latest;
        if (latest.isCompleted) {
          status = 'Settled';
        } else if (latest.isRemitted || latest.isPending) {
          status = 'Awaiting Validation';
        }
      } else if (del.isEmpty) {
        status = 'No Dues';
      }

      return {
        'client': client,
        'delCount': delCount,
        'delValue': delValue,
        'failCount': failCount,
        'failValue': failValue,
        'settlement': settlementAmount,
        'fuel': fuelMoney,
        'commission': riderCommission,
        'status': status,
        'eligibleOrders': del.where((o) => !o.isClientSettled && o.financialSettlementStatus != 'client_settled').toList(),
        'settlementRecord': activeSettlement,
      };
    }).where((row) {
      if (_incomeStatusFilter == 'all') return true;
      final st = row['status'].toString().toLowerCase().replaceAll(' ', '_');
      return st == _incomeStatusFilter.toLowerCase();
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top KPI Summary Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 650
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 1100
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Delivered Value',
                      CurrencyFormatter.formatNaira(deliveredVal),
                      '${deliveredOrders.length} Completed',
                      Icons.check_circle_rounded,
                      const Color(0xFF10B981),
                      isDark,
                      tooltip: 'Total delivery value of successfully delivered parcels',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Failed Value',
                      CurrencyFormatter.formatNaira(failedVal),
                      '${failedOrders.length} Attempts',
                      Icons.cancel_rounded,
                      const Color(0xFFEF4444),
                      isDark,
                      tooltip: 'Value of undelivered or failed delivery attempt consignments',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Settlement',
                      CurrencyFormatter.formatNaira(totalSettlementAmount),
                      '${settlements.length} Batches',
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF0284C7),
                      isDark,
                      tooltip: 'Total merchant settlements disbursed or queued for verification',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Fleet Fuel',
                      CurrencyFormatter.formatNaira(deliveredOrders.length * 400.0),
                      'In-House Only',
                      Icons.local_gas_station_rounded,
                      const Color(0xFFF59E0B),
                      isDark,
                      tooltip: 'Fuel allowances allocated for in-house riders (₦0 for external PDA)',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // View Selector & Table Header Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented Sub-View Toggle: [ Breakdown | Remittances ]
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF071B39) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIncomeTogglePill('breakdown', 'Breakdown', Icons.table_chart_rounded, isDark),
                    _buildIncomeTogglePill('remittances', 'Remittances', Icons.two_wheeler_rounded, isDark),
                  ],
                ),
              ),

              // Status Filter Chips: [ All | Unsettled | Awaiting Validation | Settled ]
              Wrap(
                spacing: 6,
                children: [
                  _buildStatusChip('all', 'All', isDark),
                  _buildStatusChip('unsettled', 'Unsettled', isDark),
                  _buildStatusChip('awaiting_validation', 'Awaiting', isDark),
                  _buildStatusChip('settled', 'Settled', isDark),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // The 8-Column Data Table Container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF071B39) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 22,
                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF031632) : const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Merchant', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Delivered', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Delivered Value', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Failed', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Failed Value', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Settlement', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Fuel', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Commission', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: clientRows.map((row) {
                    final client = row['client'] as ClientProfile;
                    final delCount = row['delCount'] as int;
                    final delVal = row['delValue'] as double;
                    final failCount = row['failCount'] as int;
                    final failVal = row['failValue'] as double;
                    final settlement = row['settlement'] as double;
                    final fuel = row['fuel'] as double;
                    final commission = row['commission'] as double;
                    final status = row['status'] as String;
                    final eligible = row['eligibleOrders'] as List<OrderEntity>;
                    final activeSettlement = row['settlementRecord'] as ClientSettlement?;

                    return DataRow(
                      cells: [
                        // 1. Merchant Identity
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.15),
                                child: Text(
                                  client.companyName.isNotEmpty ? client.companyName[0].toUpperCase() : 'M',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFFF37021)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(client.companyName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  Text(client.bankName.isNotEmpty ? client.bankName : 'Direct Transfer', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // 2. Delivered Count
                        DataCell(Text('$delCount', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12))),
                        // 3. Delivered Value
                        DataCell(Text(CurrencyFormatter.formatNaira(delVal), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF10B981)))),
                        // 4. Failed Attempt Count
                        DataCell(Text('$failCount', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12))),
                        // 5. Failed Attempt Value
                        DataCell(Text(CurrencyFormatter.formatNaira(failVal), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFEF4444)))),
                        // 6. Merchant Settlement
                        DataCell(Text(CurrencyFormatter.formatNaira(settlement), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF0284C7)))),
                        // 7. Fuel Money (₦0 for PDA, accounted for in-house)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.formatNaira(fuel), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12)),
                              if (fuel == 0.0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: NovaTooltip(
                                    message: 'External PDA courier: ₦0 fuel allowance allocated',
                                    child: Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade400),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 8. Rider Commission
                        DataCell(Text(CurrencyFormatter.formatNaira(commission), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 12))),
                        // 9. Settlement Status
                        DataCell(_buildStatusBadge(status)),
                        // 10. Action Button
                        DataCell(
                          _buildSettlementActionButton(
                            context: context,
                            client: client,
                            status: status,
                            eligibleOrders: eligible,
                            settlement: activeSettlement,
                            dcState: dcState,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeTogglePill(String viewKey, String label, IconData icon, bool isDark) {
    final isSelected = _incomeView == viewKey;
    return InkWell(
      onTap: () => setState(() => _incomeView = viewKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E2D4A) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 1))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFFF37021) : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String key, String label, bool isDark) {
    final isSelected = _incomeStatusFilter == key;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
      selected: isSelected,
      onSelected: (val) => setState(() => _incomeStatusFilter = key),
      selectedColor: const Color(0xFFF37021),
      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'settled':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        break;
      case 'awaiting validation':
      case 'awaiting_validation':
        bg = const Color(0xFF0284C7).withValues(alpha: 0.15);
        fg = const Color(0xFF0284C7);
        break;
      case 'unsettled':
        bg = const Color(0xFFF97316).withValues(alpha: 0.15);
        fg = const Color(0xFFF97316);
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildSettlementActionButton({
    required BuildContext context,
    required ClientProfile client,
    required String status,
    required List<OrderEntity> eligibleOrders,
    required ClientSettlement? settlement,
    required DCConsoleState dcState,
  }) {
    if (status == 'Unsettled' && eligibleOrders.isNotEmpty) {
      return ElevatedButton.icon(
        onPressed: () {
          DCDailyMerchantSettlementModal.show(
            context: context,
            client: client,
            eligibleOrders: eligibleOrders,
          );
        },
        icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
        label: Text('Settle', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
      );
    } else if (settlement != null) {
      return OutlinedButton.icon(
        onPressed: () {
          ClientSettlementDetailModal.show(
            context: context,
            settlement: settlement,
            isDcView: true,
            clientName: client.companyName,
          );
        },
        icon: const Icon(Icons.receipt_long_rounded, size: 13),
        label: Text(status == 'Settled' ? 'Receipt' : 'Inspect', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }

    return Text('-', style: GoogleFonts.inter(color: Colors.grey));
  }

  // ==========================================
  // SUB-TAB 3: EXPENSES (EXPENDITURES LEDGER)
  // ==========================================
  Widget _buildExpensesSubtab({
    required bool isDark,
    required bool isCompact,
    required DCConsoleState dcState,
    required DCExpendituresState expState,
    required List<BusinessExpenditureEntity> expenditures,
  }) {
    final totalOpex = expenditures.fold(0.0, (s, e) => s + e.amount);
    final daysInPreset = _startDate != null && _endDate != null
        ? _endDate!.difference(_startDate!).inDays.clamp(1, 365)
        : 30;
    final dailyBurn = totalOpex / daysInPreset;

    // Determine Top Category
    final Map<ExpenditureCategory, double> spendByCategory = {};
    for (final e in expenditures) {
      spendByCategory[e.category] = (spendByCategory[e.category] ?? 0.0) + e.amount;
    }
    ExpenditureCategory topCategory = ExpenditureCategory.dieselFuel;
    double topCategorySpend = 0.0;
    spendByCategory.forEach((cat, spend) {
      if (spend > topCategorySpend) {
        topCategorySpend = spend;
        topCategory = cat;
      }
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top OpEx KPI Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 650
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 1100
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Total OpEx',
                      CurrencyFormatter.formatNaira(totalOpex),
                      '${expenditures.length} Vouchers',
                      Icons.trending_down_rounded,
                      const Color(0xFFF97316),
                      isDark,
                      tooltip: 'Cumulative operational expenditures logged across this station',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Daily Burn',
                      CurrencyFormatter.formatNaira(dailyBurn),
                      'Average Burn',
                      Icons.local_fire_department_rounded,
                      const Color(0xFFEF4444),
                      isDark,
                      tooltip: 'Average daily operating expenditure burn across current period',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Top Category',
                      topCategory.name.toUpperCase(),
                      CurrencyFormatter.formatNaira(topCategorySpend),
                      _getCategoryIcon(topCategory),
                      _getCategoryColor(topCategory),
                      isDark,
                      tooltip: 'Largest operational expense allocation category',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Vouchers',
                      '${expenditures.length} Logged',
                      'Audited Ledger',
                      Icons.receipt_rounded,
                      const Color(0xFF10B981),
                      isDark,
                      tooltip: 'Total receipts and verified station expenditure records',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Search, Category Filters, and Record Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search Input
              SizedBox(
                width: isCompact ? 200 : 280,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search vouchers...',
                    hintStyle: GoogleFonts.inter(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ),

              // Category Filter Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF071B39) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _expenseCategoryFilter,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                      ...ExpenditureCategory.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name.toUpperCase()))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _expenseCategoryFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Expenditures Data Table
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF071B39) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: expenditures.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('No expenditure records found', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF031632) : const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Voucher', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: expenditures.map((exp) {
                          final categoryColor = _getCategoryColor(exp.category);
                          return DataRow(
                            cells: [
                              DataCell(Text(exp.invoiceNumber ?? 'VOUCHER', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 12))),
                              DataCell(Text(DateFormat('MMM dd, yyyy').format(exp.expenditureDate), style: GoogleFonts.inter(fontSize: 12))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getCategoryIcon(exp.category), size: 12, color: categoryColor),
                                      const SizedBox(width: 5),
                                      Text(
                                        exp.category.name.toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: categoryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(exp.vendorName ?? 'General Vendor', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12))),
                              DataCell(Text(CurrencyFormatter.formatNaira(exp.amount), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFFEF4444)))),
                              DataCell(
                                exp.hasReceipt
                                    ? IconButton(
                                        icon: const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF0284C7)),
                                        tooltip: 'View attached receipt voucher',
                                        onPressed: () => DCReceiptPreviewModal.show(context, exp, dcName: dcState.activeHubName),
                                      )
                                    : Text('-', style: GoogleFonts.inter(color: Colors.grey)),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  tooltip: 'Delete expenditure voucher',
                                  onPressed: () => _confirmDeleteExpenditure(context, exp, dcState),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExpenditure(
    BuildContext context,
    BusinessExpenditureEntity exp,
    DCConsoleState dcState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voucher?'),
        content: Text('Permanently remove expense ${exp.invoiceNumber} (₦${exp.amount.toStringAsFixed(2)}) from station records?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = ref.read(authProvider).user;
      final ok = await ref.read(dcExpendituresProvider.notifier).deleteExpenditure(exp.id);
      if (ok && mounted) {
        await AuditLoggingService.instance.logAction(
          actorId: user?.id,
          actorName: user?.fullName ?? 'DC Supervisor',
          actorEmail: user?.email ?? 'dc.supervisor@novaxpress.ng',
          actorRole: user?.role ?? 'dc_manager',
          action: 'DELETE_EXPENDITURE_VOUCHER',
          resource: 'EXPENDITURES_LEDGER',
          details: 'Deleted expenditure voucher ${exp.invoiceNumber} (₦${exp.amount}) from ${dcState.activeHubName}',
          distributionCenterId: dcState.activeDcId,
          distributionCenterName: dcState.activeHubName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher deleted from station ledger'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  // ==========================================
  // REUSABLE METRIC TILE
  // ==========================================
  Widget _buildMetricTile(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark, {
    String? tooltip,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071B39) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0)),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (tooltip != null) ...[
                      const SizedBox(width: 4),
                      NovaInfoIcon(tooltip: tooltip, size: 13),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openMerchantSettlementPicker(
    BuildContext context,
    DCConsoleState dcState,
    List<OrderEntity> allOrders,
  ) {
    if (dcState.clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No merchant clients registered yet.')),
      );
      return;
    }

    if (dcState.clients.length == 1) {
      final client = dcState.clients.first;
      final eligible = allOrders.where((o) =>
          (o.merchantId == client.id || o.clientId == client.id) &&
          o.status.toLowerCase() == 'delivered' &&
          !o.isClientSettled
      ).toList();
      DCDailyMerchantSettlementModal.show(
        context: context,
        client: client,
        eligibleOrders: eligible,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF071B39) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Select Merchant', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 380,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dcState.clients.length,
              itemBuilder: (ctx, i) {
                final client = dcState.clients[i];
                final eligible = allOrders.where((o) =>
                    (o.merchantId == client.id || o.clientId == client.id) &&
                    o.status.toLowerCase() == 'delivered' &&
                    !o.isClientSettled
                ).toList();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.15),
                    child: Text(client.companyName.isNotEmpty ? client.companyName[0].toUpperCase() : 'M'),
                  ),
                  title: Text(client.companyName, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  subtitle: Text('${eligible.length} unsettled orders'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    DCDailyMerchantSettlementModal.show(
                      context: context,
                      client: client,
                      eligibleOrders: eligible,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
