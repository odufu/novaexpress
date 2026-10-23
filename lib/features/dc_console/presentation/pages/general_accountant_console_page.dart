import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_staff_profile_settings_tab.dart';

/// Accounting Model for Unreconciled Delivered Orders
class PendingReconciliationOrder {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String riderId;
  final String riderName;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final double packagePrice; // Order total_amount
  final double deliveryFee; // Delivery fee arranged with merchant
  final double transactionFee; // Transaction / platform fee
  final double riderCommission; // Commission given to rider
  final double riderTransport; // Fuel / transport given to rider
  final double failedAttemptPrice; // Failed delivery attempt price
  final String destinationBankName;
  final String destinationAccountNumber;
  final String destinationAccountName;
  final DateTime? deliveredAt;

  PendingReconciliationOrder({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.riderId,
    required this.riderName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.packagePrice,
    required this.deliveryFee,
    required this.transactionFee,
    required this.riderCommission,
    required this.riderTransport,
    this.failedAttemptPrice = 0.0,
    required this.destinationBankName,
    required this.destinationAccountNumber,
    required this.destinationAccountName,
    this.deliveredAt,
  });

  /// Formula: order package price - Delivery fee (as arranged with the merchant) - Transaction fee = reconciliation price
  double get reconciliationPrice =>
      (packagePrice - deliveryFee - transactionFee).clamp(0.0, 99999999.0);

  /// Everything given to rider for successful delivery (commissions, allowances)
  double get riderTotalEntitlement => riderCommission + riderTransport;

  /// Formula: DC center interest = Delivery fee (as collected from Merchants) - Rider's delivery fee - failed delivery attempt price
  double get dcCenterInterest =>
      (deliveryFee - riderTotalEntitlement - failedAttemptPrice);
}

/// Grouping of pending reconciliations by merchant / client
class ClientReconciliationGroup {
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final List<PendingReconciliationOrder> orders;

  ClientReconciliationGroup({
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.orders,
  });

  double get totalPackagePrice => orders.fold(0.0, (sum, o) => sum + o.packagePrice);
  double get totalDeliveryFee => orders.fold(0.0, (sum, o) => sum + o.deliveryFee);
  double get totalTransactionFee => orders.fold(0.0, (sum, o) => sum + o.transactionFee);
  double get totalReconciliationPrice => orders.fold(0.0, (sum, o) => sum + o.reconciliationPrice);
  double get totalDcCenterInterest => orders.fold(0.0, (sum, o) => sum + o.dcCenterInterest);
}

class GeneralAccountantConsolePage extends ConsumerStatefulWidget {
  const GeneralAccountantConsolePage({super.key});

  @override
  ConsumerState<GeneralAccountantConsolePage> createState() =>
      _GeneralAccountantConsolePageState();
}

class _GeneralAccountantConsolePageState
    extends ConsumerState<GeneralAccountantConsolePage> {
  int _activeTab = 0; // 0: Stations, 1: Settlements & Reconciliations, 2: Cash Ledger, 3: Profile & Settings
  int _settlementSegment = 0; // 0: Pending Reconciliations, 1: Settlement History
  final TextEditingController _searchController = TextEditingController();

  List<ClientSettlement> _settlements = [];
  List<PendingReconciliationOrder> _pendingReconOrders = [];
  bool _isLoadingPendingRecon = false;

  SupabaseClient? _cachedAdminClient;
  SupabaseClient _getAdminClient() {
    return _cachedAdminClient ??= SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNationalData();
    });
  }

  Future<void> _loadNationalData() async {
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadClientsFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
    final activeHubId = ref.read(dcConsoleProvider).activeHubId;
    ref.read(financeProvider.notifier).loadRemittances(activeHubId);

    // 1. Load historical settlements
    try {
      final fetched =
          await ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements();
      if (mounted) {
        setState(() => _settlements = fetched);
      }
    } catch (_) {}

    // 2. Load pending delivered orders awaiting reconciliation
    await _fetchPendingReconciliations();
  }

  Future<void> _fetchPendingReconciliations() async {
    if (!mounted) return;
    setState(() => _isLoadingPendingRecon = true);

    try {
      final client = _getAdminClient();

      // Query delivered orders not yet reconciled to clients
      final ordersRes = await client
          .from('orders')
          .select(
              'id, order_number, customer_name, total_amount, client_delivery_fee, agent_entitlement, client_id, client_name, client_company, status, remittance_status, financial_settlement_status, delivery_agent_id, delivered_at, created_at')
          .eq('status', 'delivered')
          .neq('financial_settlement_status', 'reconciled')
          .neq('financial_settlement_status', 'settled');

      // Query clients for banking and fee terms
      final clientsRes = await client.from('clients').select(
          'id, name, company_name, email, bank_name, account_number, account_name, custom_delivery_fee, custom_platform_fee, custom_failed_attempt_fee');
      final Map<String, Map<String, dynamic>> clientMap = {};
      for (final c in (clientsRes as List)) {
        final cMap = Map<String, dynamic>.from(c as Map);
        clientMap[cMap['id']?.toString() ?? ''] = cMap;
      }

      // Query drivers to resolve rider names
      final driversRes = await client
          .from('delivery_agents')
          .select('id, agent_code, users(first_name, last_name)');
      final Map<String, String> driverMap = {};
      for (final d in (driversRes as List)) {
        final dMap = Map<String, dynamic>.from(d as Map);
        final u = dMap['users'] as Map<String, dynamic>? ?? {};
        final first = u['first_name']?.toString() ?? '';
        final last = u['last_name']?.toString() ?? '';
        driverMap[dMap['id']?.toString() ?? ''] = '$first $last'.trim();
      }

      final List<PendingReconciliationOrder> list = [];
      for (final o in (ordersRes as List)) {
        final oMap = Map<String, dynamic>.from(o as Map);
        final cId = oMap['client_id']?.toString() ?? '';
        final cl = clientMap[cId] ?? {};
        final rId = oMap['delivery_agent_id']?.toString() ?? '';
        final riderName = driverMap[rId] ?? 'Field Fleet Rider';

        final pkgPrice = (oMap['total_amount'] as num?)?.toDouble() ?? 0.0;
        final delFee = (cl['custom_delivery_fee'] as num?)?.toDouble() ??
            (oMap['client_delivery_fee'] as num?)?.toDouble() ??
            5000.0;
        final txFee = (cl['custom_platform_fee'] as num?)?.toDouble() ?? 500.0;

        // Rider delivery entitlement (commission 700 + transport 800)
        double rCommission = 700.0;
        double rTransport = 800.0;
        final ent = (oMap['agent_entitlement'] as num?)?.toDouble();
        if (ent != null && ent > 0) {
          rCommission = ent * 0.45;
          rTransport = ent * 0.55;
        }

        final cName = (cl['name']?.toString() ?? oMap['client_name']?.toString() ?? 'Merchant').trim();
        final cEmail = (cl['email']?.toString() ?? 'merchant@novaxpress.ng').trim();
        final bName = (cl['bank_name']?.toString() ?? 'Access Bank').trim();
        final bAcct = (cl['account_number']?.toString() ?? '0000000000').trim();
        final bTitle = (cl['account_name']?.toString() ?? cName).trim();

        list.add(PendingReconciliationOrder(
          orderId: oMap['id']?.toString() ?? '',
          orderNumber: oMap['order_number']?.toString() ?? 'ORD-000',
          customerName: oMap['customer_name']?.toString() ?? 'Customer',
          riderId: rId,
          riderName: riderName.isNotEmpty ? riderName : 'Oladele Omowaye',
          clientId: cId.isNotEmpty ? cId : '00000000-0000-4000-8000-791731264594',
          clientName: cName,
          clientEmail: cEmail,
          packagePrice: pkgPrice,
          deliveryFee: delFee,
          transactionFee: txFee,
          riderCommission: rCommission,
          riderTransport: rTransport,
          failedAttemptPrice: 0.0,
          destinationBankName: bName,
          destinationAccountNumber: bAcct,
          destinationAccountName: bTitle,
          deliveredAt: DateTime.tryParse(oMap['delivered_at']?.toString() ?? oMap['created_at']?.toString() ?? ''),
        ));
      }

      if (mounted) {
        setState(() {
          _pendingReconOrders = list;
          _isLoadingPendingRecon = false;
        });
      }
    } catch (e) {
      debugPrint('[GENERAL_ACCOUNTANT] ❌ _fetchPendingReconciliations error: $e');
      if (mounted) setState(() => _isLoadingPendingRecon = false);
    }
  }

  List<ClientReconciliationGroup> _groupPendingReconciliations() {
    final Map<String, List<PendingReconciliationOrder>> grouped = {};
    for (final o in _pendingReconOrders) {
      grouped.putIfAbsent(o.clientId, () => []).add(o);
    }

    final List<ClientReconciliationGroup> groups = [];
    for (final entry in grouped.entries) {
      final orders = entry.value;
      final first = orders.first;
      groups.add(ClientReconciliationGroup(
        clientId: entry.key,
        clientName: first.clientName,
        clientEmail: first.clientEmail,
        bankName: first.destinationBankName,
        accountNumber: first.destinationAccountNumber,
        accountName: first.destinationAccountName,
        orders: orders,
      ));
    }
    return groups;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final financeState = ref.watch(financeProvider);

    final dcs = dcState.distributionCenters;
    final drivers = dcState.drivers;
    final settlements = _settlements;
    final remittances = financeState.remittances;

    final reconGroups = _groupPendingReconciliations();

    // National Aggregated Financials
    final double totalFieldCashLiability = drivers.fold(
      0.0,
      (sum, d) => sum + (d.cashInCustody > 0 ? d.cashInCustody : 0.0),
    );
    final double totalRemittancesCleared = remittances
        .where((r) => !r.isPending)
        .fold(0.0, (sum, r) => sum + r.amount);

    final double totalPendingReconAmount = reconGroups.fold(
      0.0,
      (sum, g) => sum + g.totalReconciliationPrice,
    );

    final double totalDcInterestEarned = reconGroups.fold(
      0.0,
      (sum, g) => sum + g.totalDcCenterInterest,
    );

    final currentDc = dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Accountant Console',
              style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'National Financial Oversight • DC Audits & Disbursements',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh National Ledger',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _loadNationalData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: const Color(0xFF7C3AED),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.5),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: dcs.isNotEmpty,
                  label: Text('${dcs.length}'),
                  backgroundColor: const Color(0xFF7C3AED),
                  child: const Icon(Icons.hub_outlined),
                ),
                label: 'Stations',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: reconGroups.isNotEmpty || settlements.isNotEmpty,
                  label: Text('${reconGroups.isNotEmpty ? reconGroups.length : settlements.length}'),
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                label: 'Reconcile',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: remittances.isNotEmpty,
                  label: Text('${remittances.length}'),
                  backgroundColor: const Color(0xFF16A34A),
                  child: const Icon(Icons.account_balance_outlined),
                ),
                label: 'Cash Ledger',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Responsive 2x2 KPI Grid (NO Horizontal Slides, Zero Pixel Overflow)
              if (_activeTab != 3)
                _buildKpiGrid(
                  totalFieldCashLiability: totalFieldCashLiability,
                  totalRemittancesCleared: totalRemittancesCleared,
                  totalPendingReconAmount: totalPendingReconAmount,
                  totalDcInterestEarned: totalDcInterestEarned,
                  activeDriversCount: drivers.where((d) => d.cashInCustody > 0).length,
                  isDark: isDark,
                ),

              // Active Tab Content
              Expanded(
                child: _buildActiveAccountantTabBody(
                  dcs,
                  drivers,
                  settlements,
                  remittances,
                  reconGroups,
                  currentDc,
                  isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RESPONSIVE 2x2 KPI GRID (NO SCROLLING)
  // ==========================================
  Widget _buildKpiGrid({
    required double totalFieldCashLiability,
    required double totalRemittancesCleared,
    required double totalPendingReconAmount,
    required double totalDcInterestEarned,
    required int activeDriversCount,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'FIELD CASH LIABILITY',
                  value: CurrencyFormatter.formatNaira(totalFieldCashLiability),
                  subtitle: '$activeDriversCount active riders holding cash',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFEA580C),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'CLEARED REMITTANCES',
                  value: CurrencyFormatter.formatNaira(totalRemittancesCleared),
                  subtitle: 'Banked into DC treasury',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF16A34A),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'PENDING RECONCILIATIONS',
                  value: CurrencyFormatter.formatNaira(totalPendingReconAmount),
                  subtitle: 'Net payable to merchants',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'DC CENTER INTEREST',
                  value: CurrencyFormatter.formatNaira(totalDcInterestEarned),
                  subtitle: 'Station logistics margin',
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFF0D9488),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB ROUTER
  // ==========================================
  Widget _buildActiveAccountantTabBody(
    List<DistributionCenter> dcs,
    List<DCFleetDriver> drivers,
    List<ClientSettlement> settlements,
    List<RemittanceEntity> remittances,
    List<ClientReconciliationGroup> reconGroups,
    DistributionCenter? currentDc,
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildMultiStationView(dcs, drivers, isDark);
      case 1:
        return _buildReconciliationAndSettlementsView(
          reconGroups,
          settlements,
          isDark,
        );
      case 2:
        return _buildNationalLedgerView(remittances, drivers, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'General Accountant',
          departmentLabel: 'NATIONAL TREASURY & ACCOUNTS',
          accentColor: const Color(0xFF7C3AED),
          roleIcon: Icons.account_balance_rounded,
          station: currentDc,
        );
      default:
        return _buildMultiStationView(dcs, drivers, isDark);
    }
  }

  // ==========================================
  // TAB 0: MULTI-STATION BREAKDOWN (OVERFLOW FIXED)
  // ==========================================
  Widget _buildMultiStationView(
    List<DistributionCenter> dcs,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (dcs.isEmpty) {
      return const Center(child: Text('No Distribution Centers found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: dcs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final dc = dcs[index];
        final stationDrivers =
            drivers.where((d) => d.distributionCenterId == dc.id).toList();
        final stationCashLiability = stationDrivers.fold(
          0.0,
          (sum, d) => sum + (d.cashInCustody > 0 ? d.cashInCustody : 0.0),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF00522A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.warehouse_rounded,
                    color: Color(0xFF00522A), size: 22),
              ),
              const SizedBox(width: 12),

              // Center Station Info - Flexibly constrained to completely eliminate 104px/175px overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dc.name,
                            style: GoogleFonts.inter(
                                fontSize: 13.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dc.code,
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${dc.city}, ${dc.state} • ${stationDrivers.length} Fleet Drivers',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(stationCashLiability),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: stationCashLiability > 0
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    stationCashLiability > 0 ? 'Field Cash' : 'Zero Liability ✓',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: stationCashLiability > 0
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),

            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: RECONCILIATIONS & CLIENT SETTLEMENTS
  // ==========================================
  Widget _buildReconciliationAndSettlementsView(
    List<ClientReconciliationGroup> reconGroups,
    List<ClientSettlement> settlements,
    bool isDark,
  ) {
    return Column(
      children: [
        // Sub-Tab Switcher Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _settlementSegment = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _settlementSegment == 0
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pending_actions_rounded,
                          size: 15,
                          color: _settlementSegment == 0 ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pending Reconciliations (${reconGroups.length})',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _settlementSegment == 0 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _settlementSegment = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _settlementSegment == 1
                          ? const Color(0xFF00522A)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: _settlementSegment == 1 ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Settlement History (${settlements.length})',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _settlementSegment == 1 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sub-Tab Body
        Expanded(
          child: _settlementSegment == 0
              ? _buildPendingReconciliationsList(reconGroups, isDark)
              : _buildHistoricalSettlementsList(settlements, isDark),
        ),
      ],
    );
  }

  // ==========================================
  // SUB-TAB 1.A: PENDING RECONCILIATIONS LIST
  // ==========================================
  Widget _buildPendingReconciliationsList(
    List<ClientReconciliationGroup> groups,
    bool isDark,
  ) {
    if (_isLoadingPendingRecon) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
            const SizedBox(height: 12),
            Text('All Deliveries Reconciled ✓', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'No delivered orders are currently pending merchant reconciliation.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = groups[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.4 : 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Header & Bank Account
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatarWidget(fullName: group.clientName, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.clientName,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ENTERPRISE',
                                style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${group.clientEmail} • ${group.bankName} (${group.accountNumber})',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${group.orders.length} DELIVERIES',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Orders Itemized List
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivered Orders Ready for Reconciliation:',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...group.orders.map((o) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${o.orderNumber} • ${o.customerName}',
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Rider: ${o.riderName}',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatNaira(o.packagePrice),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // The Official Accounting Formula Breakdown Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B132B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF93C5FD).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reconciliation Accounting Formula', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                        const Icon(Icons.calculate_outlined, size: 15, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFormulaRow('Gross Package Price:', CurrencyFormatter.formatNaira(group.totalPackagePrice), isDark),
                    _buildFormulaRow('(-) Delivery Fee (from Merchant):', '-${CurrencyFormatter.formatNaira(group.totalDeliveryFee)}', isDark, isDeduction: true),
                    _buildFormulaRow('(-) Transaction / Platform Fee:', '-${CurrencyFormatter.formatNaira(group.totalTransactionFee)}', isDark, isDeduction: true),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reconciliation Price (Net Payout):',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(group.totalReconciliationPrice),
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DC Center Interest (Station Net Margin):',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(group.totalDcCenterInterest),
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action button to execute reconciliation
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => _openExecuteReconciliationModal(context, group, isDark),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: Text(
                    'Reconcile & Settle ${CurrencyFormatter.formatNaira(group.totalReconciliationPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormulaRow(String label, String value, bool isDark, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDeduction ? const Color(0xFFDC2626) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUB-TAB 1.B: HISTORICAL SETTLEMENTS LIST
  // ==========================================
  Widget _buildHistoricalSettlementsList(
    List<ClientSettlement> settlements,
    bool isDark,
  ) {
    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No Client Settlement Batches', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Completed reconciliation payout batches will appear here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = settlements[index];
        final isCompleted = s.status.toLowerCase() == 'completed';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: s.isRejected
                  ? const Color(0xFFDC2626)
                  : (isCompleted
                      ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                      : const Color(0xFF2563EB).withValues(alpha: 0.4)),
              width: s.isRejected ? 1.5 : 1.0,
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
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.settlementNumber,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                          : const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.status.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross Collections:', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      Text(CurrencyFormatter.formatNaira(s.grossCollections), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Logistics Fees:', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      Text('-${CurrencyFormatter.formatNaira(s.logisticsFeesDeducted)}', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Net Payout Settled:', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      Text(
                        CurrencyFormatter.formatNaira(s.netPayoutAmount),
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${s.destinationBankName} • ${s.destinationAccountNumber} (${s.destinationAccountName})',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s.proofOfPaymentUrl != null)
                    TextButton.icon(
                      onPressed: () => _viewAdviceModal(context, s.proofOfPaymentUrl!),
                      icon: const Icon(Icons.visibility_outlined, size: 13),
                      label: const Text('View Advice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: NATIONAL CASH LEDGER
  // ==========================================
  Widget _buildNationalLedgerView(
    List<RemittanceEntity> remittances,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (remittances.isEmpty) {
      return const Center(child: Text('No national remittances recorded yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: remittances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rem = remittances[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rem.isPending
                      ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                      : const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  rem.isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                  size: 19,
                  color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riderName,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${rem.referenceNumber.isNotEmpty ? rem.referenceNumber : rem.id.substring(0, 8)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(rem.createdAt)}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(rem.amount),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    rem.isPending ? 'Pending Audit' : 'Banked & Verified',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // MODAL: EXECUTE RECONCILIATION & RECORD DISBURSEMENT
  // ==========================================
  void _openExecuteReconciliationModal(
    BuildContext context,
    ClientReconciliationGroup group,
    bool isDark,
  ) {
    final randId = 1000 + Random().nextInt(9000);
    final settleNumber = 'SETTLE-NOV-${DateTime.now().year}-$randId';
    final refController = TextEditingController(text: 'NIP-REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    String? proofUrl;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Execute Client Reconciliation', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.bold)),
                            Text('Batch: $settleNumber • ${group.clientName}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Destination Bank Account Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Destination Bank:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                            Text(group.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('NUBAN Account:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                            Row(
                              children: [
                                Text(group.accountNumber, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: group.accountNumber));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number copied!')));
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Account Name:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                            Text(group.accountName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net Reconciliation Payout:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              CurrencyFormatter.formatNaira(group.totalReconciliationPrice),
                              style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Formula Verification
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildFormulaRow('Gross Package Collections:', CurrencyFormatter.formatNaira(group.totalPackagePrice), isDark),
                        _buildFormulaRow('Delivery Fee Deducted:', '-${CurrencyFormatter.formatNaira(group.totalDeliveryFee)}', isDark, isDeduction: true),
                        _buildFormulaRow('Transaction Fee Deducted:', '-${CurrencyFormatter.formatNaira(group.totalTransactionFee)}', isDark, isDeduction: true),
                        const Divider(height: 8),
                        _buildFormulaRow('DC Station Retained Interest:', CurrencyFormatter.formatNaira(group.totalDcCenterInterest), isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Upload Debit Slip
                  Text('Attach Bank Debit Advice / Slip (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePickerPlatform.instance.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'pdf']);
                        if (result.isNotEmpty) {
                          final file = result.first;
                          final bytes = await file.readAsBytes();
                          if (bytes.isNotEmpty) {
                            setModalState(() => isUploading = true);
                            final url = await SignatureStorageService.uploadSettlementReceipt(
                              bytes: bytes,
                              settlementNumber: settleNumber,
                              extension: file.extension ?? 'png',
                            );
                            setModalState(() {
                              proofUrl = url;
                              isUploading = false;
                            });
                          }
                        }
                      } catch (e) {
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: proofUrl != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                      ),
                      child: isUploading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              children: [
                                Icon(proofUrl != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: proofUrl != null ? const Color(0xFF16A34A) : const Color(0xFF64748B), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    proofUrl != null ? 'Bank Payment Slip Attached ✓' : 'Tap to upload bank debit receipt',
                                    style: TextStyle(fontSize: 11.5, color: proofUrl != null ? const Color(0xFF16A34A) : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bank Reference
                  Text('Bank Payment Reference (NIP / Transfer Narration)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirm Disbursement Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final adminClient = _getAdminClient();

                        try {
                          // 1. Insert into client_settlements
                          await adminClient.from('client_settlements').insert({
                            'settlement_number': settleNumber,
                            'client_id': group.clientId,
                            'company_id': '11111111-1111-4111-8111-111111111111',
                            'period_start': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
                            'period_end': DateTime.now().toIso8601String(),
                            'total_orders_count': group.orders.length,
                            'gross_collections': group.totalPackagePrice,
                            'logistics_fees_deducted': group.totalDeliveryFee,
                            'platform_fees_deducted': group.totalTransactionFee,
                            'net_payout_amount': group.totalReconciliationPrice,
                            'destination_bank_name': group.bankName,
                            'destination_account_number': group.accountNumber,
                            'destination_account_name': group.accountName,
                            'payout_reference': refController.text.trim(),
                            'proof_of_payment_url': proofUrl,
                            'status': 'pending_merchant_confirmation',
                            'notes': 'Reconciled to ${group.clientName} (${group.clientEmail}). DC Interest retained: ₦${group.totalDcCenterInterest.toStringAsFixed(2)}',
                            'settled_at': DateTime.now().toIso8601String(),
                            'created_at': DateTime.now().toIso8601String(),
                          });

                          // 2. Mark orders as reconciled in database
                          final orderIds = group.orders.map((o) => o.orderId).toList();
                          await adminClient.from('orders').update({
                            'financial_settlement_status': 'reconciled',
                            'updated_at': DateTime.now().toIso8601String(),
                          }).inFilter('id', orderIds);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF16A34A),
                                content: Text('Reconciliation of ${CurrencyFormatter.formatNaira(group.totalReconciliationPrice)} to ${group.clientName} successfully finalized!'),
                              ),
                            );
                            _loadNationalData();
                          }
                        } catch (e) {
                          debugPrint('[ACCOUNTANT] ❌ Reconciliation execution error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFFDC2626),
                                content: Text('Error recording reconciliation: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Confirm Reconciliation & Record Disbursement',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewAdviceModal(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Could not load payment advice.'),
          ),
        ),
      ),
    );
  }
}
