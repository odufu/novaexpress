import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/nova_tooltip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../../domain/entities/distribution_center.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_driver_manifest_table.dart';
import '../widgets/dc_city_map_widget.dart';
import '../widgets/dc_rider_detail_modal.dart';
import '../widgets/dc_onboard_rider_modal.dart';
import '../../../client_portal/data/repositories/expenditure_repository.dart';
import '../../../client_portal/presentation/widgets/client_add_expenditure_modal.dart';
import '../../../client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';

class DCDashboardPage extends ConsumerStatefulWidget {
  const DCDashboardPage({super.key});

  @override
  ConsumerState<DCDashboardPage> createState() => _DCDashboardPageState();
}

class _DCDashboardPageState extends ConsumerState<DCDashboardPage> {
  final ExpenditureRepository _repo = ExpenditureRepository();
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // DC Filter state: null represents "🌐 All Distribution Centers (Cumulative Network Control Tower)"
  String? _selectedDcId;

  // Date range filter
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedQuickRange = '30d';

  // Live RPC Financial & Operational Metrics
  bool _isLoadingFinancials = true;
  Map<String, dynamic> _financialData = {};

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));

    final dcState = ref.read(dcConsoleProvider);
    final authUser = ref.read(authProvider).user;
    final isSuperAdmin = authUser != null && (authUser.isSuperAdmin == true || authUser.role == 'super_admin' || authUser.role == 'admin');
    final isGrandDc = dcState.isCurrentHubGrandDc;

    if (!isSuperAdmin && !isGrandDc) {
      _selectedDcId = authUser?.distributionCenterId ?? dcState.activeHubId;
    } else {
      _selectedDcId = dcState.selectedDcId ?? (isGrandDc ? dcState.activeHubId : authUser?.distributionCenterId);
    }
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() => _isLoadingFinancials = true);
    try {
      final dcState = ref.read(dcConsoleProvider);
      final authUser = ref.read(authProvider).user;
      final isSuperAdmin = authUser != null && (authUser.isSuperAdmin == true || authUser.role == 'super_admin' || authUser.role == 'admin');
      final isGrandDc = dcState.isCurrentHubGrandDc;
      final canViewCumulative = isSuperAdmin || isGrandDc;

      final targetDcId = !canViewCumulative
          ? (authUser?.distributionCenterId ?? dcState.activeHubId)
          : _selectedDcId;

      final res = await _repo.fetchDcLogisticsDashboard(
        dcId: targetDcId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _financialData = res;
          _isLoadingFinancials = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFinancials = false);
      }
    }
  }

  void _applyQuickRange(String rangeKey) {
    final now = DateTime.now();
    setState(() {
      _selectedQuickRange = rangeKey;
      _endDate = now;
      if (rangeKey == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
      } else if (rangeKey == '7d') {
        _startDate = now.subtract(const Duration(days: 7));
      } else if (rangeKey == '30d') {
        _startDate = now.subtract(const Duration(days: 30));
      } else if (rangeKey == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
      } else if (rangeKey == 'all_time') {
        _startDate = DateTime(2024, 1, 1);
      }
    });
    _loadFinancialData();
  }

  Future<void> _selectCustomDateRange() async {
    final result = await PangeaDateRangePickerModal.show(
      context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
      initialPreset: DateRangePreset.custom,
    );

    if (result != null) {
      setState(() {
        _selectedQuickRange = 'custom';
        _startDate = result.startDate;
        _endDate = result.endDate;
      });
      _loadFinancialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);

    final authUser = ref.watch(authProvider).user;
    final isSuperAdmin = authUser != null && (authUser.isSuperAdmin == true || authUser.role == 'super_admin' || authUser.role == 'admin');
    final isGrandDc = dcState.isCurrentHubGrandDc;
    final canViewCumulative = isSuperAdmin || isGrandDc;

    // 2-way sync with global DC provider
    ref.listen<String?>(
      dcConsoleProvider.select((s) => s.selectedDcId),
      (previous, next) {
        if (!canViewCumulative) return;
        if (previous != next && next != _selectedDcId) {
          setState(() {
            _selectedDcId = next;
          });
          _loadFinancialData();
        }
      },
    );

    final effectiveDcId = !canViewCumulative
        ? (authUser?.distributionCenterId ?? dcState.activeHubId)
        : _selectedDcId;

    final allDcs = dcState.distributionCenters;

    // Selected DC resolution
    final activeDc = effectiveDcId == null
        ? null
        : (allDcs.where((d) => d.id == effectiveDcId).firstOrNull ??
            allDcs.where((d) => d.id == dcState.activeHubId).firstOrNull);

    // Filter orders according to selected DC scope
    final scopedOrders = ordersState.orders.where((o) {
      if (effectiveDcId == null) {
        return true; // Cumulative Network View: all orders
      }
      if (activeDc != null) {
        return OrderRoutingService.doesOrderBelongToDc(
          order: o,
          currentDc: activeDc,
          allDcs: allDcs,
        );
      }
      return o.distributionCenterId == effectiveDcId;
    }).toList();

    // Order counts for the selected scope
    final inTransitCount = scopedOrders.where((o) => o.status == 'in_transit' || o.status == 'assigned').length;
    final unassignedCount = scopedOrders.where((o) =>
        (o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty) &&
        o.status != 'delivered' &&
        o.status != 'cancelled' &&
        o.status != 'failed').length;
    final pendingReturnsCount = scopedOrders.where((o) => o.status == 'failed' || o.status == 'call_back').length;

    // Filter drivers according to selected DC scope
    final scopedDrivers = dcState.drivers.where((d) {
      if (effectiveDcId == null) return true; // All drivers across network
      return d.distributionCenterId == effectiveDcId ||
          (activeDc != null && d.distributionCenterId == activeDc.code);
    }).toList();

    // Scoped Pending COD Remittances
    final scopedRemittances = financeState.remittances.where((r) {
      if (effectiveDcId == null) return true;
      if (r.distributionCenterId != null && r.distributionCenterId!.isNotEmpty) {
        return r.distributionCenterId == effectiveDcId;
      }
      final driverIds = scopedDrivers.map((d) => d.id).toSet();
      return driverIds.contains(r.deliveryAgentId);
    }).toList();
    final scopedPendingRemittance = scopedRemittances
        .where((r) => r.isPending)
        .fold(0.0, (sum, r) => sum + r.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ORGANIC COMMAND BANNER (Tactile Facility Switcher & Capsule Controls)
          _buildOrganicCommandBanner(
            context: context,
            isDark: isDark,
            allDcs: allDcs,
            activeDc: activeDc,
            activeHubId: dcState.activeHubId,
          ),

          const SizedBox(height: 24),

          // 2. FLUID TELEMETRY STREAM (Unified Hero Flow - No Boxy Repeating Cards)
          _buildFluidTelemetryStream(
            context: context,
            isDark: isDark,
            inTransitCount: inTransitCount,
            unassignedCount: unassignedCount,
            pendingReturnsCount: pendingReturnsCount,
            totalPendingRemittance: scopedPendingRemittance,
          ),

          const SizedBox(height: 28),

          // 3. AMBIENT OPERATIONS CANVAS (Regional Matrix / Station Flow vs Living Radar)
          _buildOperationsCanvas(
            context: context,
            isDark: isDark,
            allDcs: allDcs,
            activeDc: activeDc,
            scopedDrivers: scopedDrivers,
            activeHubId: dcState.activeHubId,
            canViewCumulative: canViewCumulative,
          ),

          const SizedBox(height: 32),

          // 4. INTEGRATED PERSONNEL MANIFEST STREAM
          _buildFleetManifestSurface(
            context: context,
            isDark: isDark,
            scopedDrivers: scopedDrivers,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. ORGANIC COMMAND BANNER (Tactile Facility Switcher & Capsule Controls)
  // ===========================================================================
  Widget _buildOrganicCommandBanner({
    required BuildContext context,
    required bool isDark,
    required List<DistributionCenter> allDcs,
    required DistributionCenter? activeDc,
    required String activeHubId,
  }) {
    final isCumulative = _selectedDcId == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCumulative ? const Color(0xFF0284C7) : const Color(0xFF059669))
                .withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Segmented Date Capsule Ribbon (Today | 7D | 30D | This Month | All Time | 📅)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 0.6,
              ),
            ),
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildSegmentedDatePill('Today', 'today', isDark),
                _buildSegmentedDatePill('7D', '7d', isDark),
                _buildSegmentedDatePill('30D', '30d', isDark),
                _buildSegmentedDatePill('This Month', 'this_month', isDark),
                _buildSegmentedDatePill('All Time', 'all_time', isDark),
                IconButton(
                  tooltip: 'Custom Calendar Range',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    size: 17,
                    color: _selectedQuickRange == 'custom'
                        ? const Color(0xFF38BDF8)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  onPressed: _selectCustomDateRange,
                ),
              ],
            ),
          ),

          // Tactile Action Pills: Record OpEx & Onboard Rider
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NovaTooltip(
                message: isCumulative ? 'Record network operational expenditures' : 'Record operational expenses for ${activeDc?.name ?? "this station"}',
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await ClientAddExpenditureModal.show(
                      context,
                      distributionCenterId: _selectedDcId ?? activeHubId,
                      entityType: 'grand_dc',
                    );
                    if (result != null) {
                      _loadFinancialData();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    'Record OpEx',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              NovaTooltip(
                message: 'Onboard a new PDA or in-house delivery rider',
                child: OutlinedButton.icon(
                  onPressed: () => DCOnboardRiderModal.show(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(
                    'Onboard Rider',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedDatePill(String label, String key, bool isDark) {
    final isSelected = _selectedQuickRange == key;
    return InkWell(
      onTap: () => _applyQuickRange(key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0284C7) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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

  // ===========================================================================
  // 2. FLUID TELEMETRY STREAM (Unified Hero Flow - No Boxy Repeating Cards)
  // ===========================================================================
  Widget _buildFluidTelemetryStream({
    required BuildContext context,
    required bool isDark,
    required int inTransitCount,
    required int unassignedCount,
    required int pendingReturnsCount,
    required double totalPendingRemittance,
  }) {
    if (_isLoadingFinancials) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    final gross = (_financialData['logistics_gross_revenue'] is num)
        ? (_financialData['logistics_gross_revenue'] as num).toDouble()
        : 0.0;
    final opex = (_financialData['network_opex'] is num)
        ? (_financialData['network_opex'] as num).toDouble()
        : 0.0;
    final parcels = (_financialData['total_parcels_handled'] is num)
        ? (_financialData['total_parcels_handled'] as num).toInt()
        : 0;
    final netMargin = (_financialData['net_logistics_margin'] is num)
        ? (_financialData['net_logistics_margin'] as num).toDouble()
        : 0.0;
    final vault = (_financialData['vault_inventory'] is num)
        ? (_financialData['vault_inventory'] as num).toInt()
        : 0;
    final riderPayout = (_financialData['rider_allowances'] is num)
        ? (_financialData['rider_allowances'] as num).toDouble()
        : 0.0;

    final marginPct = gross > 0 ? ((netMargin / gross) * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEVEL 1: HERO FINANCIAL STREAM (Gross Rev -> HERO MARGIN -> Hub OpEx)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // A. Logistics Gross Revenue
                    Expanded(
                      flex: 3,
                      child: _buildFinancialFlowUnit(
                        title: _selectedDcId == null ? 'Gross Revenue' : 'Station Revenue',
                        value: '₦${_currencyFormat.format(gross)}',
                        subtext: 'Delivery Billings',
                        icon: Icons.local_shipping_rounded,
                        accentColor: const Color(0xFF10B981),
                        isDark: isDark,
                        tooltip: 'Consolidated delivery fee billings and logistics revenue stream',
                      ),
                    ),

                    Container(
                      height: 60,
                      width: 1,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),

                    // B. HERO HIGHLIGHT: Net Platform Margin (Ambient Aura)
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF0284C7).withValues(alpha: 0.15),
                                    const Color(0xFF059669).withValues(alpha: 0.08),
                                  ]
                                : [
                                    const Color(0xFF0284C7).withValues(alpha: 0.06),
                                    const Color(0xFF059669).withValues(alpha: 0.04),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Net Margin',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF38BDF8),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const NovaInfoIcon(
                                      tooltip: 'Consolidated operating profit after OpEx & payouts',
                                      size: 13,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$marginPct% Margin',
                                    style: GoogleFonts.firaCode(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₦${_currencyFormat.format(netMargin)}',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Operating Margin',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      height: 60,
                      width: 1,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),

                    // C. Hub OpEx
                    Expanded(
                      flex: 3,
                      child: _buildFinancialFlowUnit(
                        title: _selectedDcId == null ? 'Network OpEx' : 'Station OpEx',
                        value: '₦${_currencyFormat.format(opex)}',
                        subtext: 'Station Upkeep',
                        icon: Icons.receipt_long_rounded,
                        accentColor: const Color(0xFFF43F5E),
                        isDark: isDark,
                        tooltip: 'Generator diesel, leases, utilities, and hub maintenance upkeep',
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildFinancialFlowUnit(
                      title: _selectedDcId == null ? 'Gross Revenue' : 'Station Revenue',
                      value: '₦${_currencyFormat.format(gross)}',
                      subtext: 'Delivery Billings',
                      icon: Icons.local_shipping_rounded,
                      accentColor: const Color(0xFF10B981),
                      isDark: isDark,
                      tooltip: 'Consolidated delivery fee billings and logistics revenue stream',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Net Margin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                              const SizedBox(width: 4),
                              const NovaInfoIcon(tooltip: 'Consolidated operating profit after OpEx & payouts', size: 13, color: Color(0xFF38BDF8)),
                            ],
                          ),
                          Text('₦${_currencyFormat.format(netMargin)}', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text('$marginPct% Net Profit', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFinancialFlowUnit(
                      title: _selectedDcId == null ? 'Network OpEx' : 'Station OpEx',
                      value: '₦${_currencyFormat.format(opex)}',
                      subtext: 'Station Upkeep',
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFFF43F5E),
                      isDark: isDark,
                      tooltip: 'Generator diesel, leases, utilities, and hub maintenance upkeep',
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 24),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            thickness: 0.8,
          ),
          const SizedBox(height: 20),

          // LEVEL 2: CONNECTED OPERATIONAL TELEMETRY STREAM
          Wrap(
            spacing: 20,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // 1. Vault Stock
              _buildOperationalStreamPill(
                label: 'Vault Stock',
                value: '$vault pcs',
                subtext: 'In Storage',
                icon: Icons.warehouse_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                tooltip: 'Total client and company inventory currently held in warehouse custody',
              ),

              // 2. Cash in Fleet Custody
              _buildOperationalStreamPill(
                label: 'Fleet Cash',
                value: CurrencyFormatter.formatNaira(totalPendingRemittance),
                subtext: 'Pending COD',
                icon: Icons.payments_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
                tooltip: 'Total unremitted Cash on Delivery (COD) collected by riders on active delivery routes',
                onTap: () => ref.read(dcConsoleProvider.notifier).setActiveTab(2),
              ),

              // 3. Active Field Routes
              _buildOperationalStreamPill(
                label: 'Active Routes',
                value: '$inTransitCount Active',
                subtext: '$unassignedCount Pending',
                icon: Icons.route_rounded,
                color: const Color(0xFF38BDF8),
                isDark: isDark,
                tooltip: 'Live delivery routes currently being fulfilled across regional dispatch zones',
                onTap: () => ref.read(dcConsoleProvider.notifier).setActiveTab(1),
              ),

              // 4. Rider Payout Entitlements
              _buildOperationalStreamPill(
                label: 'Fleet Payouts',
                value: '₦${_currencyFormat.format(riderPayout)}',
                subtext: 'Allowances & Fuel',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFFF97316),
                isDark: isDark,
                tooltip: 'Accrued rider commissions, drop allowances, and fuel compensation disbursements',
                onTap: () => ref.read(dcConsoleProvider.notifier).setActiveTab(7),
              ),

              // 5. Consignments Handled
              _buildOperationalStreamPill(
                label: 'Throughput',
                value: '$parcels items',
                subtext: 'Delivered',
                icon: Icons.all_inbox_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                tooltip: 'Total successful delivery consignments completed across the logistics network',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialFlowUnit({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    String? tooltip,
  }) {
    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tooltip != null) ...[
                    const SizedBox(width: 4),
                    NovaInfoIcon(tooltip: tooltip, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtext,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return NovaTooltip(message: tooltip, child: content);
    }
    return content;
  }

  Widget _buildOperationalStreamPill({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    final pill = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return NovaTooltip(message: tooltip, child: pill);
    }
    return pill;
  }

  // ===========================================================================
  // 3. AMBIENT OPERATIONS CANVAS (Regional Matrix / Station Profile vs Living Radar)
  // ===========================================================================
  Widget _buildOperationsCanvas({
    required BuildContext context,
    required bool isDark,
    required List<DistributionCenter> allDcs,
    required DistributionCenter? activeDc,
    required List<DCFleetDriver> scopedDrivers,
    required String activeHubId,
    bool canViewCumulative = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        final isCumulativeView = _selectedDcId == null && canViewCumulative;
        final leftWidget = isCumulativeView
            ? _buildRegionalHubMatrixSurface(isDark: isDark, allDcs: allDcs)
            : _buildStationProfileSurface(
                isDark: isDark,
                activeDc: activeDc,
                canReturnToMatrix: canViewCumulative,
              );

        final rightWidget = _buildSpatialTelemetryRadarSurface(
          isDark: isDark,
          scopedDrivers: scopedDrivers,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: leftWidget),
              const SizedBox(width: 22),
              Expanded(flex: 5, child: rightWidget),
            ],
          );
        } else {
          return Column(
            children: [
              leftWidget,
              const SizedBox(height: 22),
              rightWidget,
            ],
          );
        }
      },
    );
  }

  Widget _buildRegionalHubMatrixSurface({
    required bool isDark,
    required List<DistributionCenter> allDcs,
  }) {
    final rawBreakdown = _financialData['dc_breakdown'];
    final List list = (rawBreakdown is List) ? rawBreakdown : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_location_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Hub Network',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const NovaInfoIcon(
                    tooltip: 'Regional network performance across all registered distribution hubs',
                    size: 14,
                    color: Color(0xFF38BDF8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${allDcs.length} Hubs',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (allDcs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No distribution centers registered yet.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allDcs.length,
              separatorBuilder: (context, index) =>
                  Divider(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), height: 18),
              itemBuilder: (context, index) {
                final dc = allDcs[index];
                // Match with RPC breakdown metrics
                final match = list.where((b) => b['dc_id'] == dc.id || b['dc_code'] == dc.code).firstOrNull;
                final rev = (match != null && match['revenue'] is num)
                    ? (match['revenue'] as num).toDouble()
                    : 0.0;
                final parcels = (match != null && match['parcels'] is num)
                    ? (match['parcels'] as num).toInt()
                    : 0;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDcId = dc.id;
                    });
                    ref.read(dcConsoleProvider.notifier).selectDistributionCenter(dc.id);
                    _loadFinancialData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: dc.isGrandDc
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            dc.isGrandDc ? Icons.stars_rounded : Icons.location_city_rounded,
                            color: dc.isGrandDc ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    dc.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dc.code,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 10,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dc.city.isNotEmpty ? dc.city : dc.state} • $parcels consignments handled',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₦${_currencyFormat.format(rev)}',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Focus →',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStationProfileSurface({
    required bool isDark,
    required DistributionCenter? activeDc,
    bool canReturnToMatrix = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Dispatch Focus',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const NovaInfoIcon(
                    tooltip: 'Scoped dispatch and operational telemetry for selected distribution center',
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                ],
              ),
              if (canReturnToMatrix)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDcId = null; // Return to Cumulative Network view
                    });
                    ref.read(dcConsoleProvider.notifier).selectDistributionCenter(null);
                    _loadFinancialData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 13, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Text(
                          'All Hubs',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Displaying scoped metrics for ${activeDc?.name ?? "Selected Station"}. All revenue, OpEx, and route allocations above reflect this facility exclusively.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Jurisdiction Zones:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (activeDc?.operatingZones ?? ['Abuja Municipal (AMAC)', 'Wuse 2', 'Maitama', 'Garki']).map((zone) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  zone,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpatialTelemetryRadarSurface({
    required bool isDark,
    required List<DCFleetDriver> scopedDrivers,
  }) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DCCityMapWidget(
          drivers: scopedDrivers,
          onDriverSelected: (driver) => DCRiderDetailModal.show(context, driver),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. INTEGRATED PERSONNEL MANIFEST STREAM
  // ===========================================================================
  Widget _buildFleetManifestSurface({
    required BuildContext context,
    required bool isDark,
    required List<DCFleetDriver> scopedDrivers,
  }) {
    return DCDriverManifestTable(
      drivers: scopedDrivers,
      onAddDriver: () => DCOnboardRiderModal.show(context),
      onExportCSV: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Scoped Rider Manifest exported as CSV.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      },
      onDriverTap: (driver) => DCRiderDetailModal.show(context, driver),
    );
  }
}
