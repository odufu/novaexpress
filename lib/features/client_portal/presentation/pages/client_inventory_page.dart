import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/client_stock_balance.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../../domain/entities/client_supplier_expanded.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_add_supplier_modal.dart';
import '../widgets/client_import_stock_balance_modal.dart';
import '../widgets/client_raise_stock_invoice_modal.dart';
import '../widgets/pangea_date_range_picker_modal.dart';
import '../../domain/entities/client_unit_economics.dart';
import '../widgets/pangea_excel_data_table.dart';
import '../widgets/client_operational_cost_breakdown_modal.dart';
import '../widgets/client_stock_invoice_detail_modal.dart';

class ClientInventoryPage extends ConsumerStatefulWidget {
  const ClientInventoryPage({super.key});

  @override
  ConsumerState<ClientInventoryPage> createState() => _ClientInventoryPageState();
}

class _ClientInventoryPageState extends ConsumerState<ClientInventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final _compactCurrency = NumberFormat.compact(locale: 'en_US');

  // Top Pangea Suite filter bar state (matching screenshot rows 1, 2, 3)
  late DateTime _pangeaStartDate;
  late DateTime _pangeaEndDate;
  DateRangePreset _pangeaPreset = DateRangePreset.last7Days;
  bool _pangeaCompare = false;

  String _pangeaItemGroup = 'All Item Groups';
  String _pangeaItem = 'All Items';
  String _pangeaWarehouse = 'All Warehouses';
  String _pangeaWarehouseType = 'All Types';
  String _pangeaCurrency = 'NGN (₦)';
  bool _includeUom = true;
  bool _showVariantAttributes = false;
  bool _showStockAgeingData = false;
  bool _ignoreClosingBalance = false;
  bool _includeZeroStockItems = false;
  bool _showDimensionWiseStock = false;

  // Filters for Tab 2 (Invoices)
  String _invoiceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Calculate initial date range in Lagos Time (WAT = UTC+1)
    final lagosNow = DateTime.now().toUtc().add(const Duration(hours: 1));
    final today = DateTime(lagosNow.year, lagosNow.month, lagosNow.day);
    _pangeaEndDate = today;
    _pangeaStartDate = today.subtract(const Duration(days: 6));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientPortalProvider.notifier).reloadInventoryData(
        startDate: _pangeaStartDate,
        endDate: _pangeaEndDate,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDateRangePicker() async {
    final result = await PangeaDateRangePickerModal.show(
      context,
      initialStartDate: _pangeaStartDate,
      initialEndDate: _pangeaEndDate,
      initialPreset: _pangeaPreset,
      initialCompare: _pangeaCompare,
    );
    if (result != null) {
      setState(() {
        _pangeaStartDate = result.startDate;
        _pangeaEndDate = result.endDate;
        _pangeaPreset = result.preset;
        _pangeaCompare = result.compareWithPreviousPeriod;
      });
      ref.read(clientPortalProvider.notifier).reloadInventoryData(
        startDate: result.startDate,
        endDate: result.endDate,
      );
    }
  }

  String _getDateRangeDisplayText() {
    final startStr = DateFormat('d MMM yyyy').format(_pangeaStartDate);
    final endStr = DateFormat('d MMM yyyy').format(_pangeaEndDate);
    if (_pangeaStartDate.year == _pangeaEndDate.year &&
        _pangeaStartDate.month == _pangeaEndDate.month &&
        _pangeaStartDate.day == _pangeaEndDate.day) {
      return startStr;
    }
    return '$startStr – $endStr';
  }

  void _exportCsv() {
    final csv = ref.read(clientPortalProvider.notifier).generateStockBalanceCsv();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stock balance CSV (Pangea Suite format) copied to clipboard!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientPortalProvider.notifier).reloadInventoryData(),
        color: const Color(0xFF0D9488),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero KPI Bar & Top Action Buttons
              _buildHeroHeader(context, state, isDark, isCompact),
              const SizedBox(height: 20),

              // KPI Metric Cards
              _buildKpiCards(state, isDark, isCompact),
              const SizedBox(height: 24),

              // Sub-navigation Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isCompact,
                  labelColor: const Color(0xFF0D9488),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0D9488),
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      text: 'Stock Ledger (${state.stockBalances.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      text: 'Intake Invoices (${state.stockInvoices.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.people_alt_rounded, size: 18),
                      text: 'Suppliers Directory (${state.suppliers.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.pie_chart_rounded, size: 18),
                      text: 'Unit Economics & Landed Cost',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active Tab Content
              SizedBox(
                height: 980,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStockLedgerTab(state, isDark),
                    _buildInvoicesTab(state, isDark),
                    _buildSuppliersTab(state, isDark),
                    _buildUnitEconomicsTab(state, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Header Hero
  // ===========================================================================
  Widget _buildHeroHeader(BuildContext context, ClientPortalState state, bool isDark, bool isCompact) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PANGEA SUITE COMPATIBLE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D9488),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Multi-Warehouse Logistics',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Inventory & Stock',
          style: GoogleFonts.inter(
            fontSize: isCompact ? 22 : 24,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Physical Hub Custody, Goods Receipt Ledger & Unit Economics',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => ClientImportStockBalanceModal.show(context),
          icon: const Icon(Icons.upload_file_rounded, size: 15),
          label: Text('Import CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _exportCsv,
          icon: const Icon(Icons.download_rounded, size: 15),
          label: Text('Export CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => ClientRaiseStockInvoiceModal.show(context),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(
            '+ Raise Stock Invoice',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 14),
          actionButtons,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        actionButtons,
      ],
    );
  }

  // ===========================================================================
  // KPI Cards
  // ===========================================================================
  Widget _buildKpiCards(ClientPortalState state, bool isDark, bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isCompact ? (constraints.maxWidth / 2 - 8) : (constraints.maxWidth / 4 - 12);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Total Stock Valuation',
              value: '₦${_compactCurrency.format(state.totalStockValuation)}',
              subtext: '₦${_currencyFormat.format(state.totalStockValuation)} NGN',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF0D9488),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'Total Units on Hand',
              value: NumberFormat('#,###').format(state.totalStockQuantity),
              subtext: '${state.totalReservedStock} reserved for pending orders',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF3B82F6),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'Active Warehouses / Hubs',
              value: '${state.uniqueWarehousesCount} Stations',
              subtext: '108 partner 3PLs & distribution depots',
              icon: Icons.warehouse_rounded,
              color: const Color(0xFF8B5CF6),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'Procurement Suppliers',
              value: '${state.suppliers.length} Vendors',
              subtext: '${state.stockInvoices.length} intake invoices raised',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFFF59E0B),
              width: cardWidth,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required double width,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Stock Ledger (Pangea Suite Excel Data Table with Resizable Columns)
  // ===========================================================================
  Widget _buildStockLedgerTab(ClientPortalState state, bool isDark) {
    final clientCompany = state.clientProfile.companyName;
    final warehouses = <String>['All Warehouses', ...state.uniqueWarehouses];
    final itemGroups = <String>[
      'All Item Groups',
      ...state.stockBalances.map((b) => b.itemGroup).toSet().where((g) => g.isNotEmpty),
    ];
    final itemNames = <String>[
      'All Items',
      ...state.stockBalances.map((b) => b.itemName).toSet().where((n) => n.isNotEmpty),
    ];

    final filtered = state.stockBalances.where((b) {
      if (_pangeaWarehouse != 'All Warehouses' && b.warehouse != _pangeaWarehouse) {
        return false;
      }
      if (_pangeaItemGroup != 'All Item Groups' && b.itemGroup != _pangeaItemGroup) {
        return false;
      }
      if (_pangeaItem != 'All Items' && b.itemName != _pangeaItem && b.itemCode != _pangeaItem) {
        return false;
      }
      if (!_includeZeroStockItems && b.balanceQty <= 0 && b.inQty <= 0 && b.outQty <= 0) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Bar: "Stock Balance" + refresh + more actions
          _buildPangeaHeader(state, filtered.length, isDark),
          const SizedBox(height: 14),

          // Pangea Suite 3-Row Filter Controls (from screenshot)
          _buildPangeaFilterControls(clientCompany, itemGroups, itemNames, warehouses, isDark),
          const SizedBox(height: 14),

          // Resizable Excel Spreadsheet using reusable PangeaExcelDataTable
          Expanded(
            child: PangeaExcelDataTable<ClientStockBalance>(
              items: filtered,
              columns: _buildStockLedgerColumns(isDark, const Color(0xFF0D9488)),
              enablePagination: true,
              initialPageSize: 25,
              showTopToolbar: true,
              rowHeight: 60.0,
              brandPrimary: const Color(0xFF0D9488),
              emptyMessage: 'No stock ledger positions recorded. Click "Import CSV" or "+ Raise Stock Invoice" above to add stock.',
              onRowTap: (item) => _showStockBalanceDetailModal(context, item, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPangeaHeader(ClientPortalState state, int count, bool isDark) {
    return Row(
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Stock Balance',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count positions',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => ref.read(clientPortalProvider.notifier).reloadInventoryData(),
          tooltip: 'Refresh stock balances',
          icon: const Icon(Icons.sync_rounded, size: 18),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded, size: 18),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (action) {
            if (action == 'reset_cols') {
              PangeaTablePreferencesController.instance.resetToDefaults();
            } else if (action == 'clear_filters') {
              setState(() {
                _pangeaWarehouse = 'All Warehouses';
                _pangeaItemGroup = 'All Item Groups';
                _pangeaItem = 'All Items';
                _includeZeroStockItems = false;
              });
            } else if (action == 'export') {
              _exportCsv();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reset_cols',
              child: Row(
                children: [
                  Icon(Icons.view_column_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Reset Column Widths'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_filters',
              child: Row(
                children: [
                  Icon(Icons.filter_alt_off_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Clear All Filters'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Export Pangea CSV'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPangeaFilterControls(
    String clientCompany,
    List<String> itemGroups,
    List<String> itemNames,
    List<String> warehouses,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Row 1: Company, Dates, Item Group, Items, Warehouses
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Company pill
            _buildFilterPill(
              isDark: isDark,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_rounded, size: 15, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                  Text(
                    clientCompany,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Unified Pangea Date Range Picker Button (Lagos Time WAT)
            InkWell(
              onTap: _openDateRangePicker,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 7),
                    Text(
                      _getDateRangeDisplayText(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Lagos Time',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),

            // Item Group dropdown
            _buildDropdownPill<String>(
              value: itemGroups.contains(_pangeaItemGroup) ? _pangeaItemGroup : 'All Item Groups',
              items: itemGroups,
              hint: 'Item Group',
              isDark: isDark,
              onChanged: (val) {
                if (val != null) setState(() => _pangeaItemGroup = val);
              },
            ),

            // Items dropdown
            _buildDropdownPill<String>(
              value: itemNames.contains(_pangeaItem) ? _pangeaItem : 'All Items',
              items: itemNames,
              hint: 'Items',
              isDark: isDark,
              onChanged: (val) {
                if (val != null) setState(() => _pangeaItem = val);
              },
            ),

            // Warehouses dropdown
            _buildDropdownPill<String>(
              value: warehouses.contains(_pangeaWarehouse) ? _pangeaWarehouse : 'All Warehouses',
              items: warehouses,
              hint: 'Warehouses',
              isDark: isDark,
              onChanged: (val) {
                if (val != null) setState(() => _pangeaWarehouse = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Row 2: Warehouse Type, Currency, Include UOM, Checkboxes
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDropdownPill<String>(
              value: _pangeaWarehouseType,
              items: const ['All Types', 'Stores', '3PL Hubs', 'Transit'],
              hint: 'Warehouse Type',
              isDark: isDark,
              onChanged: (val) {
                if (val != null) setState(() => _pangeaWarehouseType = val);
              },
            ),

            _buildDropdownPill<String>(
              value: _pangeaCurrency,
              items: const ['NGN (₦)', 'USD (\$)'],
              hint: 'Currency',
              isDark: isDark,
              onChanged: (val) {
                if (val != null) setState(() => _pangeaCurrency = val);
              },
            ),

            // Include UOM pill
            InkWell(
              onTap: () => setState(() => _includeUom = !_includeUom),
              borderRadius: BorderRadius.circular(10),
              child: _buildFilterPill(
                isDark: isDark,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _includeUom ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: _includeUom ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Include UOM',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _includeUom ? FontWeight.w700 : FontWeight.w500,
                        color: _includeUom
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildCheckboxFilter(
              label: 'Show Variant Attributes',
              value: _showVariantAttributes,
              isDark: isDark,
              onChanged: (val) => setState(() => _showVariantAttributes = val ?? false),
            ),

            _buildCheckboxFilter(
              label: 'Show Stock Ageing Data',
              value: _showStockAgeingData,
              isDark: isDark,
              onChanged: (val) => setState(() => _showStockAgeingData = val ?? false),
            ),

            _buildCheckboxFilter(
              label: 'Ignore Closing Balance',
              value: _ignoreClosingBalance,
              isDark: isDark,
              onChanged: (val) => setState(() => _ignoreClosingBalance = val ?? false),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Row 3: Include Zero Stock Items, Dimension Wise Stock
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCheckboxFilter(
              label: 'Include Zero Stock Items',
              value: _includeZeroStockItems,
              isDark: isDark,
              onChanged: (val) => setState(() => _includeZeroStockItems = val ?? false),
            ),

            _buildCheckboxFilter(
              label: 'Show Dimension Wise Stock',
              value: _showDimensionWiseStock,
              isDark: isDark,
              onChanged: (val) => setState(() => _showDimensionWiseStock = val ?? false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterPill({required Widget child, required bool isDark, double? width}) {
    return Container(
      height: 34,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _buildDropdownPill<T>({
    required T value,
    required List<T> items,
    required String hint,
    required bool isDark,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          isDense: true,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text('$item', overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckboxFilter({
    required String label,
    required bool value,
    required bool isDark,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF0D9488),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

    List<ExcelColumnDef<ClientStockBalance>> _buildStockLedgerColumns(bool isDark, Color brandPrimary) {
    return [
      ExcelColumnDef<ClientStockBalance>(
        key: 'index',
        label: '#',
        defaultWidth: 44.0,
        minWidth: 36.0,
        align: TextAlign.center,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'item',
        label: 'Item',
        group: 'Product Identification',
        defaultWidth: 130.0,
        minWidth: 80.0,
        searchString: (item) => item.itemCode,
        sortValue: (item) => item.itemCode,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Text(
                item.itemCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'item_name',
        label: 'Item Name',
        group: 'Product Identification',
        defaultWidth: 180.0,
        minWidth: 120.0,
        searchString: (item) => '${item.itemName} ${item.itemGroup}',
        sortValue: (item) => item.itemName,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (item.itemGroup.isNotEmpty)
                Text(
                  item.itemGroup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'warehouse',
        label: 'Warehouse',
        group: 'Warehouse & Custody',
        defaultWidth: 230.0,
        minWidth: 150.0,
        searchString: (item) => '${item.warehouse} ${item.cleanWarehouseName} ${item.custodyTypeLabel}',
        sortValue: (item) => item.cleanWarehouseName,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          final isCentral = item.isCentralWarehouse;
          final is3PL = item.is3PLPartner;
          final badgeColor = isCentral
              ? const Color(0xFF0D9488)
              : (is3PL ? const Color(0xFF6366F1) : const Color(0xFFF59E0B));

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.cleanWarehouseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                ),
              ),
              if (item.warehouse != item.cleanWarehouseName) ...[
                Text(
                  item.warehouse,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text(
                  item.custodyTypeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'opening_qty',
        label: 'Opening Qty',
        group: 'Period Movement',
        defaultWidth: 105.0,
        minWidth: 75.0,
        align: TextAlign.right,
        searchString: (item) => '${item.openingQty}',
        sortValue: (item) => item.openingQty,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          NumberFormat('#,##0').format(item.openingQty),
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'in_qty',
        label: 'In Qty',
        group: 'Period Movement',
        defaultWidth: 95.0,
        minWidth: 70.0,
        align: TextAlign.right,
        searchString: (item) => '${item.inQty}',
        sortValue: (item) => item.inQty,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          item.inQty > 0 ? '+${NumberFormat('#,##0').format(item.inQty)}' : '0',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: item.inQty > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'out_qty',
        label: 'Out Qty',
        group: 'Period Movement',
        defaultWidth: 95.0,
        minWidth: 70.0,
        align: TextAlign.right,
        searchString: (item) => '${item.outQty}',
        sortValue: (item) => item.outQty,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          item.outQty > 0 ? '-${NumberFormat('#,##0').format(item.outQty)}' : '0',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: item.outQty > 0 ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'balance_qty',
        label: 'Balance Qty',
        group: 'Current Position',
        defaultWidth: 115.0,
        minWidth: 75.0,
        align: TextAlign.right,
        searchString: (item) => '${item.balanceQty}',
        sortValue: (item) => item.balanceQty,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          NumberFormat('#,##0').format(item.balanceQty),
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'available_to_sell',
        label: 'Available to Sell',
        group: 'Current Position',
        defaultWidth: 125.0,
        minWidth: 80.0,
        align: TextAlign.right,
        searchString: (item) => '${item.availableToSell}',
        sortValue: (item) => item.availableToSell,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          final avail = item.availableToSell;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat('#,##0').format(avail),
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: avail > 0 ? const Color(0xFF0D9488) : const Color(0xFFEF4444),
                ),
              ),
              if (item.reservedStock > 0)
                Text(
                  '(${item.reservedStock.toInt()} res)',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'valuation_rate',
        label: 'Valuation Rate',
        group: 'Valuation & Economics',
        defaultWidth: 120.0,
        minWidth: 80.0,
        align: TextAlign.right,
        searchString: (item) => '${item.valuationRate}',
        sortValue: (item) => item.valuationRate,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          '₦${_currencyFormat.format(item.valuationRate)}',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'balance_value',
        label: 'Balance Value',
        group: 'Valuation & Economics',
        defaultWidth: 135.0,
        minWidth: 90.0,
        align: TextAlign.right,
        searchString: (item) => '${item.balanceValue}',
        sortValue: (item) => item.balanceValue,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          '₦${_currencyFormat.format(item.balanceValue)}',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'health_status',
        label: 'Health Status',
        group: 'Inventory Health',
        defaultWidth: 125.0,
        minWidth: 85.0,
        align: TextAlign.center,
        searchString: (item) => item.status,
        sortValue: (item) => item.status,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          Color badgeColor;
          switch (item.status) {
            case 'Healthy':
              badgeColor = const Color(0xFF10B981);
              break;
            case 'Low Stock':
              badgeColor = const Color(0xFFF59E0B);
              break;
            case 'Stagnant in Fleet':
              badgeColor = const Color(0xFF8B5CF6);
              break;
            default:
              badgeColor = const Color(0xFFEF4444);
          }
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Text(
                item.status,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientStockBalance>(
        key: 'actions',
        label: 'Actions',
        group: 'Actions',
        defaultWidth: 70.0,
        minWidth: 50.0,
        align: TextAlign.center,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Center(
          child: IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 16),
            tooltip: 'Inspect Stock Position',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _showStockBalanceDetailModal(context, item, isDark),
          ),
        ),
      ),
    ];
  }

  void _showStockBalanceDetailModal(BuildContext context, ClientStockBalance b, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  b.itemCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                b.company,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b.itemName,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.isCentralWarehouse ? Icons.warehouse_rounded : (b.is3PLPartner ? Icons.local_shipping_rounded : Icons.two_wheeler_rounded),
                        color: b.isCentralWarehouse ? const Color(0xFF0D9488) : (b.is3PLPartner ? const Color(0xFF6366F1) : const Color(0xFFF59E0B)),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.cleanWarehouseName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            Text(
                              '${b.custodyTypeLabel} • Full Key: ${b.warehouse}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildModalMetricTile('Opening Qty', NumberFormat('#,##0').format(b.openingQty), isDark),
                    _buildModalMetricTile('Inward Intake', '+${NumberFormat('#,##0').format(b.inQty)}', isDark, color: const Color(0xFF10B981)),
                    _buildModalMetricTile('Dispatched Outflow', '-${NumberFormat('#,##0').format(b.outQty)}', isDark, color: const Color(0xFFF97316)),
                    _buildModalMetricTile('Balance Qty', NumberFormat('#,##0').format(b.balanceQty), isDark, isBold: true),
                    _buildModalMetricTile('Available to Sell', NumberFormat('#,##0').format(b.availableToSell), isDark, color: const Color(0xFF0D9488)),
                    _buildModalMetricTile('Landed Cost (COGS)', '₦${_currencyFormat.format(b.valuationRate)}', isDark),
                    _buildModalMetricTile('Asset Valuation', '₦${_currencyFormat.format(b.balanceValue)}', isDark, isBold: true),
                    _buildModalMetricTile('Health Status', b.status, isDark),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalMetricTile(String label, String value, bool isDark, {Color? color, bool isBold = false}) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 2: Stock Intake Invoices
  // ===========================================================================
  Widget _buildInvoicesTab(ClientPortalState state, bool isDark) {
    final filteredInvoices = state.stockInvoices.where((inv) {
      if (_invoiceSearchQuery.isEmpty) return true;
      final q = _invoiceSearchQuery.toLowerCase();
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.supplierName.toLowerCase().contains(q) ||
          inv.targetWarehouse.toLowerCase().contains(q);
    }).toList();

    final totalValuation = filteredInvoices.fold(0.0, (sum, i) => sum + i.grandTotalLandedCost);
    final totalUnits = filteredInvoices.fold(0, (sum, i) => sum + i.totalUnits);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Action & Search Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final summaryBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${filteredInvoices.length} Bills • ${NumberFormat('#,###').format(totalUnits)} Units • ₦${_currencyFormat.format(totalValuation)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              );

              final rightActions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => ref.read(clientPortalProvider.notifier).reloadInventoryData(),
                    tooltip: 'Refresh intake bills',
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ClientRaiseStockInvoiceModal.show(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('+ New Intake Bill', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Intake Invoices',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        rightActions,
                      ],
                    ),
                    const SizedBox(height: 8),
                    summaryBadge,
                  ],
                );
              }

              return Row(
                children: [
                  Text(
                    'Intake Invoices',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  summaryBadge,
                  const Spacer(),
                  rightActions,
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Search Field
          TextFormField(
            onChanged: (v) => setState(() => _invoiceSearchQuery = v.trim()),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by invoice number, supplier or destination warehouse...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0D9488)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Pangea Excel Table for Invoices
          Expanded(
            child: PangeaExcelDataTable<ClientStockInvoice>(
              items: filteredInvoices,
              columns: _buildStockInvoiceColumns(isDark, const Color(0xFF0D9488)),
              enablePagination: true,
              initialPageSize: 25,
              showTopToolbar: true,
              rowHeight: 56.0,
              brandPrimary: const Color(0xFF0D9488),
              emptyMessage: 'No stock intake invoices found. Click "+ New Intake Bill" to raise one.',
              onRowTap: (inv) => ClientStockInvoiceDetailModal.show(context, invoice: inv),
            ),
          ),
        ],
      ),
    );
  }

  List<ExcelColumnDef<ClientStockInvoice>> _buildStockInvoiceColumns(bool isDark, Color brandPrimary) {
    return [
      ExcelColumnDef<ClientStockInvoice>(
        key: 'index',
        label: '#',
        defaultWidth: 44.0,
        minWidth: 36.0,
        align: TextAlign.center,
        cellBuilder: (context, item, index, isDark, brandPrimary) => Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'invoice_number',
        label: 'Invoice & Date',
        group: 'Invoice Details',
        defaultWidth: 170.0,
        minWidth: 130.0,
        searchString: (item) => '${item.invoiceNumber} ${DateFormat('dd MMM yyyy').format(item.entryDate)}',
        sortValue: (item) => item.invoiceNumber,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.invoiceNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D9488),
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(item.entryDate),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'supplier',
        label: 'Supplier / Vendor',
        group: 'Procurement',
        defaultWidth: 190.0,
        minWidth: 130.0,
        searchString: (item) => item.supplierName,
        sortValue: (item) => item.supplierName,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.business_rounded, size: 14, color: Color(0xFF0D9488)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.supplierName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'destination_warehouse',
        label: 'Receiving Hub',
        group: 'Logistics Custody',
        defaultWidth: 180.0,
        minWidth: 130.0,
        searchString: (item) => item.destinationWarehouse,
        sortValue: (item) => item.destinationWarehouse,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warehouse_rounded, size: 13, color: Color(0xFF0D9488)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.destinationWarehouse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'units',
        label: 'Intake Units',
        group: 'Volume & Items',
        defaultWidth: 120.0,
        minWidth: 90.0,
        align: TextAlign.right,
        searchString: (item) => item.totalUnits.toString(),
        sortValue: (item) => item.totalUnits,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,###').format(item.totalUnits)} units',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${item.items.length} line item${item.items.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'landed_cost',
        label: 'Total Landed Cost',
        group: 'Valuation & Accounting',
        defaultWidth: 160.0,
        minWidth: 120.0,
        align: TextAlign.right,
        searchString: (item) => item.grandTotalLandedCost.toString(),
        sortValue: (item) => item.grandTotalLandedCost,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          final unitRate = item.totalUnits > 0 ? (item.grandTotalLandedCost / item.totalUnits) : 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₦${_currencyFormat.format(item.grandTotalLandedCost)}',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D9488),
                ),
              ),
              if (unitRate > 0)
                Text(
                  '₦${_currencyFormat.format(unitRate)}/unit',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'receipt',
        label: 'Receipt & Proof',
        group: 'Audit Proof',
        defaultWidth: 140.0,
        minWidth: 100.0,
        align: TextAlign.center,
        searchString: (item) => item.hasPaymentReceipt ? 'attached' : 'missing',
        sortValue: (item) => item.hasPaymentReceipt ? 1 : 0,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          if (item.hasPaymentReceipt) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Receipt Attached',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    'No Receipt',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'status',
        label: 'Ledger Status',
        group: 'Audit Proof',
        defaultWidth: 130.0,
        minWidth: 100.0,
        align: TextAlign.center,
        searchString: (item) => item.status,
        sortValue: (item) => item.status,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          final isPosted = item.isProcessed;
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPosted
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPosted ? Icons.check_circle_rounded : Icons.pending_rounded,
                    size: 12,
                    color: isPosted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPosted ? 'Ledger Posted' : 'Draft Intake',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isPosted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientStockInvoice>(
        key: 'actions',
        label: 'Actions',
        defaultWidth: 90.0,
        minWidth: 70.0,
        align: TextAlign.center,
        cellBuilder: (context, item, index, isDark, brandPrimary) {
          return Center(
            child: IconButton(
              icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
              color: const Color(0xFF0D9488),
              tooltip: 'View Invoice Details & Receipts',
              onPressed: () => ClientStockInvoiceDetailModal.show(context, invoice: item),
            ),
          );
        },
      ),
    ];
  }

  // ===========================================================================
  // Tab 3: Suppliers Directory
  // ===========================================================================
  Widget _buildSuppliersTab(ClientPortalState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct Procurement Vendors & Material Suppliers',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Maintain vendor payment terms, replenishment lead times and banking details',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => ClientAddSupplierModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('+ Register Supplier', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: state.suppliers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.business_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No suppliers registered in directory',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ClientAddSupplierModal.show(context),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                          child: const Text('Add First Vendor', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final brandPrimary = state.clientProfile.brandPrimaryColor;
                      final expandedSuppliers = state.suppliers.map((s) {
                        return ClientSupplierExpanded.fromData(
                          supplier: s,
                          allProducts: state.products,
                        );
                      }).toList();

                      final columns = [
                        // Column 1: Index
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'index',
                          group: 'Vendor Identity',
                          label: '#',
                          defaultWidth: 50,
                          minWidth: 40,
                          align: TextAlign.center,
                          cellBuilder: (context, e, row, isDark, brand) => Text(
                            '$row',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),

                        // Column 2: Supplier / Vendor Name & Category
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'supplierName',
                          group: 'Vendor Identity',
                          label: 'SUPPLIER / VENDOR',
                          defaultWidth: 230,
                          minWidth: 170,
                          searchString: (e) => '${e.supplier.name} ${e.supplier.category} ${e.supplier.contactPerson}',
                          sortValue: (e) => e.supplier.name,
                          cellBuilder: (context, e, row, isDark, brand) => Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.business_rounded, color: Color(0xFF0D9488), size: 14),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      e.supplier.name,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${e.supplier.category}${e.supplier.contactPerson.isNotEmpty ? ' • ${e.supplier.contactPerson}' : ''}',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Column 3: Supplied Products
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'suppliedProducts',
                          group: 'Catalog',
                          label: 'LINKED PRODUCTS',
                          defaultWidth: 210,
                          minWidth: 150,
                          searchString: (e) => e.linkedProducts.map((p) => '${p.name} ${p.sku}').join(' '),
                          cellBuilder: (context, e, row, isDark, brand) {
                            if (e.linkedProducts.isEmpty) {
                              return Text(
                                'No linked products',
                                style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                              );
                            }
                            final names = e.linkedProducts.map((p) => p.name).take(2).join(', ');
                            final extra = e.linkedProducts.length > 2 ? ' +${e.linkedProducts.length - 2}' : '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '$names$extra',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),

                        // Column 4: Network Stock
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'networkStock',
                          group: 'Inventory',
                          label: 'NETWORK STOCK',
                          defaultWidth: 130,
                          minWidth: 100,
                          align: TextAlign.right,
                          sortValue: (e) => e.totalUnitsRemaining,
                          cellBuilder: (context, e, row, isDark, brand) => Text(
                            '${NumberFormat('#,###').format(e.totalUnitsRemaining)} units',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: e.hasCriticalLowStock ? const Color(0xFFDC2626) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),

                        // Column 5: Inventory Health
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'healthStatus',
                          group: 'Inventory',
                          label: 'INVENTORY HEALTH',
                          defaultWidth: 155,
                          minWidth: 130,
                          align: TextAlign.center,
                          sortValue: (e) => e.stockHealthStatus,
                          cellBuilder: (context, e, row, isDark, brand) {
                            Color bg;
                            Color fg;
                            IconData icon;
                            switch (e.stockHealthStatus) {
                              case 'CRITICAL REORDER':
                                bg = const Color(0xFFFEE2E2);
                                fg = const Color(0xFFDC2626);
                                icon = Icons.error_outline_rounded;
                                break;
                              case 'LOW STOCK':
                                bg = const Color(0xFFFEF3C7);
                                fg = const Color(0xFFD97706);
                                icon = Icons.warning_amber_rounded;
                                break;
                              case 'HEALTHY':
                                bg = const Color(0xFFDCFCE7);
                                fg = const Color(0xFF16A34A);
                                icon = Icons.check_circle_outline_rounded;
                                break;
                              default:
                                bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
                                fg = const Color(0xFF64748B);
                                icon = Icons.help_outline_rounded;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 12, color: fg),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.stockHealthStatus,
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Column 6: Lead Time & Terms
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'leadTimeTerms',
                          group: 'Procurement',
                          label: 'LEAD TIME & TERMS',
                          defaultWidth: 160,
                          minWidth: 130,
                          sortValue: (e) => e.supplier.leadTimeDays,
                          cellBuilder: (context, e, row, isDark, brand) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${e.supplier.leadTimeDays}d Lead Time',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                e.supplier.paymentTerms,
                                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Column 7: Direct Contact
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'contact',
                          group: 'Procurement',
                          label: 'DIRECT CONTACT',
                          defaultWidth: 200,
                          minWidth: 160,
                          searchString: (e) => '${e.supplier.phone} ${e.supplier.email}',
                          cellBuilder: (context, e, row, isDark, brand) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (e.supplier.phone.isNotEmpty) ...[
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: e.supplier.phone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Copied ${e.supplier.phone} to clipboard'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 10, color: Color(0xFF25D366)),
                                        const SizedBox(width: 3),
                                        Text(
                                          e.supplier.phone,
                                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF25D366)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (e.supplier.email.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    e.supplier.email,
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Column 8: Actions
                        ExcelColumnDef<ClientSupplierExpanded>(
                          key: 'actions',
                          group: 'Actions',
                          label: 'ACTIONS',
                          defaultWidth: 170,
                          minWidth: 150,
                          align: TextAlign.center,
                          cellBuilder: (context, e, row, isDark, brand) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  minimumSize: Size.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  ClientRaiseStockInvoiceModal.show(
                                    context,
                                    initialSupplierId: e.supplier.id,
                                    initialProduct: e.linkedProducts.isNotEmpty ? e.linkedProducts.first : null,
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_rounded, size: 11),
                                label: Text('Intake', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Edit Supplier',
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => ClientAddSupplierModal.show(context, existingSupplier: e.supplier),
                              ),
                            ],
                          ),
                        ),
                      ];

                      return PangeaExcelDataTable<ClientSupplierExpanded>(
                        items: expandedSuppliers,
                        columns: columns,
                        brandPrimary: brandPrimary,
                        emptyMessage: 'No suppliers found matching current filter',
                        showFilterRow: true,
                        enablePagination: true,
                        initialPageSize: 25,
                        rowHeight: 48.0,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 4: Unit Economics & Landed Cost Matrix
  // ===========================================================================
  Widget _buildUnitEconomicsTab(ClientPortalState state, bool isDark) {
    final matrix = state.unitEconomicsList;
    final brandPrimary = state.clientProfile.brandPrimaryColor;

    final columns = [
      // Group: Product
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'productName',
        group: 'Product',
        label: 'PRODUCT NAME',
        defaultWidth: 200,
        minWidth: 140,
        searchString: (e) => e.productName,
        sortValue: (e) => e.productName,
        cellBuilder: (context, e, row, isDark, brand) => Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 14, color: brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.productName,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'productSku',
        group: 'Product',
        label: 'SKU',
        defaultWidth: 100,
        minWidth: 75,
        searchString: (e) => e.productSku,
        sortValue: (e) => e.productSku,
        cellBuilder: (context, e, row, isDark, brand) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
          child: Text(
            e.productSku.isNotEmpty ? e.productSku : '—',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),

      // Group: Landed Cost Matrix
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'baseCost',
        group: 'Landed Cost Matrix',
        label: 'BASE COST',
        defaultWidth: 110,
        minWidth: 85,
        align: TextAlign.right,
        sortValue: (e) => e.baseSupplierPrice,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.baseSupplierPrice)}',
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'packaging',
        group: 'Landed Cost Matrix',
        label: 'PACKAGING',
        defaultWidth: 105,
        minWidth: 80,
        align: TextAlign.right,
        sortValue: (e) => e.packagingAddon,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.packagingAddon)}',
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'freight',
        group: 'Landed Cost Matrix',
        label: 'FREIGHT',
        defaultWidth: 105,
        minWidth: 80,
        align: TextAlign.right,
        sortValue: (e) => e.transportationAddon,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.transportationAddon)}',
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'handling',
        group: 'Landed Cost Matrix',
        label: 'HANDLING',
        defaultWidth: 105,
        minWidth: 80,
        align: TextAlign.right,
        sortValue: (e) => e.handlingAddon,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.handlingAddon)}',
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'effectiveLanded',
        group: 'Landed Cost Matrix',
        label: 'EFFECTIVE LANDED',
        defaultWidth: 135,
        minWidth: 100,
        align: TextAlign.right,
        sortValue: (e) => e.totalLandedCost,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.totalLandedCost)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: brand,
          ),
        ),
      ),

      // Group: Packages & Sales
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'sellingPrice',
        group: 'Packages & Sales',
        label: 'CATALOG PRICE',
        defaultWidth: 120,
        minWidth: 90,
        align: TextAlign.right,
        sortValue: (e) => e.catalogRetailPrice,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.catalogRetailPrice)}',
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'quantitySold',
        group: 'Packages & Sales',
        label: 'QUANTITY SOLD',
        defaultWidth: 125,
        minWidth: 95,
        align: TextAlign.right,
        sortValue: (e) => e.quantitySold,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '${e.quantitySold} units',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'valueSold',
        group: 'Packages & Sales',
        label: 'VALUE SOLD (PKGS)',
        defaultWidth: 155,
        minWidth: 110,
        align: TextAlign.right,
        sortValue: (e) => e.valueSold,
        cellBuilder: (context, e, row, isDark, brand) => Tooltip(
          message: 'Recovered cash revenue across delivered promo deals and packages (₦${_currencyFormat.format(e.valueSold)})',
          child: Text(
            '₦${_currencyFormat.format(e.valueSold)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16A34A),
            ),
          ),
        ),
      ),

      // Group: Operations Cost (MAIN COLUMN as requested by User)
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'totalOperationsCost',
        group: 'Operations Cost',
        label: 'OPERATIONS COST',
        defaultWidth: 175,
        minWidth: 140,
        align: TextAlign.right,
        sortValue: (e) => e.totalOperationsCost,
        cellBuilder: (context, e, row, isDark, brand) => ClientOperationalCostCell(
          economics: e,
          brandPrimary: brand,
          isDark: isDark,
        ),
      ),

      // Group: Net Profitability
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'cogs',
        group: 'Net Profitability',
        label: 'LANDED COGS',
        defaultWidth: 130,
        minWidth: 95,
        align: TextAlign.right,
        sortValue: (e) => e.cogsDispatched,
        cellBuilder: (context, e, row, isDark, brand) => Text(
          '₦${_currencyFormat.format(e.cogsDispatched)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'netProfit',
        group: 'Net Profitability',
        label: 'REALIZED NET PROFIT',
        defaultWidth: 155,
        minWidth: 110,
        align: TextAlign.right,
        sortValue: (e) => e.netRealizedProfit,
        cellBuilder: (context, e, row, isDark, brand) {
          final isPositive = e.netRealizedProfit >= 0;
          return Text(
            '${isPositive ? '' : '-'}₦${_currencyFormat.format(e.netRealizedProfit.abs())}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          );
        },
      ),
      ExcelColumnDef<ClientUnitEconomics>(
        key: 'netMargin',
        group: 'Net Profitability',
        label: 'NET MARGIN',
        defaultWidth: 115,
        minWidth: 85,
        align: TextAlign.center,
        sortValue: (e) => e.netMarginPercent,
        cellBuilder: (context, e, row, isDark, brand) {
          final isHealthy = e.netMarginPercent >= 30.0;
          final isModerate = e.netMarginPercent >= 10.0 && e.netMarginPercent < 30.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isHealthy
                  ? const Color(0xFFF0FDF4)
                  : (isModerate ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${e.netMarginPercent.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isHealthy
                    ? const Color(0xFF16A34A)
                    : (isModerate ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
              ),
            ),
          );
        },
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Landed Cost vs Wholesale Pricing Matrix & Package Economics',
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Recovered cash from packages, landed COGS, dynamic operations cost (delivery + failed attempts + platform fees), and realized net margin',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${matrix.length} Catalog Products Analyzed',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: brandPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: PangeaExcelDataTable<ClientUnitEconomics>(
              items: matrix,
              columns: columns,
              brandPrimary: brandPrimary,
              emptyMessage: 'No catalog products found for unit economics analysis',
            ),
          ),
        ],
      ),
    );
  }
}

