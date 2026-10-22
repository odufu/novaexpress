import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_remittance_detail_modal.dart';
import '../widgets/dc_staff_profile_settings_tab.dart';
import '../widgets/dc_audit_logs_tab_view.dart';

class DCFinanceOperationsPage extends ConsumerStatefulWidget {
  const DCFinanceOperationsPage({super.key});

  @override
  ConsumerState<DCFinanceOperationsPage> createState() => _DCFinanceOperationsPageState();
}

class _DCFinanceOperationsPageState extends ConsumerState<DCFinanceOperationsPage> {
  int _activeTab = 0; // 0: Approvals Queue, 1: Rider Cash Liabilities, 2: Audit History, 3: Profile & Settings
  final TextEditingController _searchController = TextEditingController();
  String _riderLiabilityFilter = 'all'; // 'all', 'holding_cash', 'high_balance'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final currentUser = ref.read(authProvider).user;
    final dcState = ref.read(dcConsoleProvider);
    final activeHubId = dcState.activeHubId.isNotEmpty
        ? dcState.activeHubId
        : (currentUser?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222');
    ref.read(financeProvider.notifier).loadRemittances(activeHubId);
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
    if (activeHubId.isNotEmpty) {
      ref.read(ordersProvider.notifier).loadDcOrders(activeHubId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRemittanceDetails(
    BuildContext context,
    RemittanceEntity rem,
    DCFleetDriver? driver,
    bool isDark,
  ) {
    final allOrders = ref.read(ordersProvider).orders;
    final matchingOrders = allOrders.where((o) =>
      rem.associatedOrders.any((ao) => ao.orderId == o.id) ||
      (rem.deliveryAgentId.isNotEmpty && o.deliveryAgentId == rem.deliveryAgentId)
    ).toList();

    DCRemittanceDetailModal.showFromRemittanceEntity(
      context,
      rem,
      driver: driver,
      orders: matchingOrders,
    );
  }

  void _openRiderCashDossier(
    BuildContext context,
    DCFleetDriver driver,
    List<RemittanceEntity> riderPending,
    double grossCustody,
    double unrequestedNet,
    double commDeduction,
    double fuelDeduction,
    double posDeduction,
    int deliveredOrdersCount,
    bool isDark,
  ) {
    final allOrders = ref.read(ordersProvider).orders;
    final riderOrders = allOrders.where((o) =>
      o.deliveryAgentId == driver.id || o.deliveryAgentId == driver.driverCode
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  UserAvatarWidget(fullName: driver.name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${driver.driverCode} • ${driver.phone}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF00522A)),
                    onPressed: () => _callPhone(driver.phone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Financial Deduction Breakdown Card (Accounting for Commission, Fuel & POS Fee)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF00522A)),
                            const SizedBox(width: 8),
                            Text(
                              'Remittance Calculation & Deductions',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBreakdownRow('Gross Orders Collection', CurrencyFormatter.formatNaira(grossCustody), isDark),
                        const SizedBox(height: 6),
                        _buildBreakdownRow(
                          'Less: Delivery Commission ($deliveredOrdersCount orders)',
                          '-${CurrencyFormatter.formatNaira(commDeduction)}',
                          isDark,
                          isDeduction: true,
                        ),
                        const SizedBox(height: 6),
                        _buildBreakdownRow(
                          'Less: Fuel & Route Allowance',
                          '-${CurrencyFormatter.formatNaira(fuelDeduction)}',
                          isDark,
                          isDeduction: true,
                        ),
                        const SizedBox(height: 6),
                        _buildBreakdownRow(
                          'Less: POS / Bank Transfer Fee',
                          '-${CurrencyFormatter.formatNaira(posDeduction)}',
                          isDark,
                          isDeduction: true,
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Net Remittance Due to DC:',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              CurrencyFormatter.formatNaira(unrequestedNet),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: unrequestedNet > 0 ? const Color(0xFF00522A) : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Section: REMITTANCES REQUESTED FOR CLEARANCE
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFEA580C)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Requested for Clearance (${riderPending.length})',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (riderPending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'No clearance requests currently submitted by this rider.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    )
                  else
                    ...riderPending.map((rem) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                CurrencyFormatter.formatNaira(rem.amount),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00522A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏳ REQUESTED FOR CLEARANCE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ref: ${rem.referenceNumber.isNotEmpty ? rem.referenceNumber : rem.id.substring(0, 8)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(rem.createdAt)}',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00522A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.verified_rounded, size: 16),
                              label: const Text('Review & Verify Clearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openRemittanceDetails(context, rem, driver, isDark);
                              },
                            ),
                          ),
                        ],
                      ),
                    )),

                  const SizedBox(height: 20),

                  // 3. Section: UNREQUESTED FOR CLEARANCE (FIELD CASH)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unrequested Net Cash Payable',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: unrequestedNet > 0
                          ? const Color(0xFFDC2626).withValues(alpha: isDark ? 0.12 : 0.05)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: unrequestedNet > 0
                            ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CurrencyFormatter.formatNaira(unrequestedNet),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: unrequestedNet > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🛑 UNREQUESTED FOR CLEARANCE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⚠️ Accounts Policy: Finance staff can ONLY perform actions on remittances requested for clearance with bank proof. Since the rider has not submitted a remittance request for this cash, NO CLEARANCE ACTION is permitted for finance persons.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (unrequestedNet > 0) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                              label: const Text('Call Rider to Request Remittance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _callPhone(driver.phone),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. View Delivered Orders Button
                  if (riderOrders.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: Text('View ${riderOrders.length} Assigned Orders in Hub', style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          DCRemittanceDetailModal.showUnrequestedRiderCash(context, driver, riderOrders);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, bool isDark, {bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDeduction ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);

    final currentUser = authState.user;
    final officerName = currentUser != null && currentUser.firstName.isNotEmpty
        ? currentUser.firstName
        : (currentUser?.fullName.isNotEmpty == true ? currentUser!.fullName.split(' ').first : 'Officer');

    final allRemittances = financeState.remittances;
    final pendingRemittances = allRemittances.where((r) => r.isPending).toList();
    final approvedRemittances = allRemittances.where((r) => !r.isPending).toList();

    final allDrivers = dcState.drivers;
    final allOrders = ordersState.orders;

    // Calculate Gross and Net Field Liabilities accounting for Commissions, Fuel, and POS
    double totalNetFieldLiability = 0.0;

    for (final d in allDrivers) {
      if (d.cashInCustody <= 0) continue;

      final riderDelivered = allOrders.where((o) =>
        (o.deliveryAgentId == d.id || o.deliveryAgentId == d.driverCode) && o.isDelivered
      ).toList();
      final count = riderDelivered.isNotEmpty ? riderDelivered.length : 1;
      final commRate = d.commissionRate > 0 ? d.commissionRate : 1000.0;
      final fuelRate = d.transportAllowance > 0 ? d.transportAllowance : 1500.0;
      final comm = count * commRate;
      final fuel = count > 0 ? fuelRate : 0.0;
      const pos = 350.0;
      final net = (d.cashInCustody - comm - fuel - pos).clamp(0.0, double.infinity);
      totalNetFieldLiability += net;
    }

    final double totalPendingVerification = pendingRemittances.fold(
      0.0,
      (sum, r) => sum + r.amount,
    );

    final now = DateTime.now();
    final approvedToday = approvedRemittances.where((r) {
      return r.createdAt.year == now.year &&
          r.createdAt.month == now.month &&
          r.createdAt.day == now.day;
    }).toList();

    // Personalized KPIs to measure this finance officer's works
    final myClearedToday = approvedToday.where((r) {
      final myId = currentUser?.id ?? '';
      final myName = currentUser?.fullName.toLowerCase() ?? '';
      return (r.verifiedByUserId != null && r.verifiedByUserId == myId) ||
          (r.verifiedByName != null && r.verifiedByName!.toLowerCase() == myName);
    }).toList();

    final double myClearedTodayAmount = myClearedToday.isNotEmpty
        ? myClearedToday.fold(0.0, (s, r) => s + r.amount)
        : approvedToday.fold(0.0, (s, r) => s + r.amount);

    final int myClearedCount = myClearedToday.isNotEmpty
        ? myClearedToday.length
        : approvedToday.length;

    final int totalProcessedToday = myClearedCount + pendingRemittances.length;
    final int clearanceRate = totalProcessedToday > 0
        ? ((myClearedCount / totalProcessedToday) * 100).round()
        : 100;

    final currentDc = dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.firstOrNull;

    // Time-based greeting
    final hour = now.hour;
    final timeGreeting = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance Admin Console',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '${dcState.activeHubName} • Cash Remittances & Audit',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF00522A), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'DC Activity Logs',
            icon: const Icon(Icons.manage_history_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  height: MediaQuery.of(context).size.height * 0.9,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: DCAuditLogsTabView(officerDc: currentDc, isDark: isDark),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
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
            selectedItemColor: const Color(0xFF00522A),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingRemittances.isNotEmpty,
                  label: Text('${pendingRemittances.length}'),
                  backgroundColor: const Color(0xFFEA580C),
                  child: const Icon(Icons.pending_actions_rounded),
                ),
                label: 'Approvals',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: allDrivers.any((d) => d.cashInCustody > 0),
                  label: Text('${allDrivers.where((d) => d.cashInCustody > 0).length}'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.account_balance_wallet_rounded),
                ),
                label: 'Rider Cash',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_rounded),
                label: 'Audit History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Personalized Finance Ops Dashboard & 2x2 Fixed KPI Grid (Only on Tabs 0, 1, 2)
          if (_activeTab != 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Personalized Greeting & Shift Status
                  Row(
                    children: [
                      UserAvatarWidget(
                        fullName: currentUser?.fullName ?? 'Finance Admin',
                        radius: 17,
                        showBorder: true,
                        borderColor: const Color(0xFF00522A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good $timeGreeting, $officerName! 👋',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Finance Ops Terminal • Verification Shift Active',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Online',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Responsive 2x2 KPI Grid (No Horizontal Scroll - Zero Overflows)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildGridKpiCard(
                            'APPROVALS QUEUE',
                            CurrencyFormatter.formatNaira(totalPendingVerification),
                            '${pendingRemittances.length} submissions waiting',
                            Icons.hourglass_top_rounded,
                            const Color(0xFFEA580C),
                            cardWidth,
                            isDark,
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                          _buildGridKpiCard(
                            'VERIFIED TODAY',
                            CurrencyFormatter.formatNaira(myClearedTodayAmount),
                            '$myClearedCount cleared by you',
                            Icons.verified_rounded,
                            const Color(0xFF16A34A),
                            cardWidth,
                            isDark,
                            onTap: () => setState(() => _activeTab = 2),
                          ),
                          _buildGridKpiCard(
                            'NET FIELD CASH',
                            CurrencyFormatter.formatNaira(totalNetFieldLiability),
                            'After rider commissions',
                            Icons.account_balance_wallet_rounded,
                            const Color(0xFFDC2626),
                            cardWidth,
                            isDark,
                            onTap: () => setState(() => _activeTab = 1),
                          ),
                          _buildGridKpiCard(
                            'CLEARANCE VELOCITY',
                            '$clearanceRate%',
                            '$myClearedCount of $totalProcessedToday processed',
                            Icons.insights_rounded,
                            const Color(0xFF7C3AED),
                            cardWidth,
                            isDark,
                            onTap: () => setState(() => _activeTab = 2),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

          // Main Tab Body
          Expanded(
            child: _buildActiveTabBody(
              pendingRemittances,
              allDrivers,
              approvedRemittances,
              allOrders,
              currentDc,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabBody(
    List<RemittanceEntity> pendingRemittances,
    List<DCFleetDriver> allDrivers,
    List<RemittanceEntity> approvedRemittances,
    List<dynamic> allOrders,
    DistributionCenter? currentDc,
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildApprovalsQueueView(pendingRemittances, allDrivers, isDark);
      case 1:
        return _buildRiderLiabilitiesView(allDrivers, pendingRemittances, allOrders, isDark);
      case 2:
        return _buildAuditHistoryView(approvedRemittances, allDrivers, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'Station Finance Admin',
          departmentLabel: 'FINANCE & CASH REMITTANCES',
          accentColor: const Color(0xFF00522A),
          roleIcon: Icons.account_balance_wallet_rounded,
          station: currentDc,
        );
      default:
        return _buildApprovalsQueueView(pendingRemittances, allDrivers, isDark);
    }
  }

  Widget _buildGridKpiCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    double width,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: APPROVALS QUEUE (REQUESTED FOR CLEARANCE)
  // ==========================================
  Widget _buildApprovalsQueueView(
    List<RemittanceEntity> pendingList,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (pendingList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 16),
              Text(
                'Approvals Queue is Clear! 🎉',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'No pending rider cash remittances awaiting verification.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rem = pendingList[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');
        final riderCode = driver != null ? driver.driverCode : 'RDR';
        final hasReceipt = rem.depositReceiptUrl != null && rem.depositReceiptUrl!.isNotEmpty;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openRemittanceDetails(context, rem, driver, isDark),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFEA580C)),
                            const SizedBox(width: 4),
                            Text(
                              'REQUESTED FOR CLEARANCE',
                              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Tap to inspect breakdown ›',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Rider & Amount Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatarWidget(fullName: riderName, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    riderName,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    riderCode,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Submitted ${DateFormat('MMM dd, yyyy • hh:mm a').format(rem.createdAt)}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF00522A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rem.paymentMethodDisplay.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Reference & Receipt Indicator
                  Row(
                    children: [
                      Icon(
                        hasReceipt ? Icons.attachment_rounded : Icons.money_rounded,
                        size: 15,
                        color: hasReceipt ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasReceipt ? 'Bank Deposit Receipt Attached ✓' : 'Physical Cash Handover at Station',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasReceipt ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        rem.referenceNumber.isNotEmpty ? rem.referenceNumber : 'Ref: N/A',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      if (hasReceipt)
                        OutlinedButton.icon(
                          onPressed: () => _openReceiptViewerModal(context, rem.depositReceiptUrl!, riderName),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: const Text('View Slip', style: TextStyle(fontSize: 12)),
                        ),
                      if (hasReceipt) const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openRemittanceDetails(context, rem, driver, isDark),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00522A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: Text(
                            'Review & Verify (${CurrencyFormatter.formatNaira(rem.amount)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: RIDER CASH LIABILITIES (DEDUCTIONS ACCOUNTED FOR)
  // ==========================================
  Widget _buildRiderLiabilitiesView(
    List<DCFleetDriver> drivers,
    List<RemittanceEntity> pendingRemittances,
    List<dynamic> allOrders,
    bool isDark,
  ) {
    var filtered = drivers;
    if (_riderLiabilityFilter == 'holding_cash') {
      filtered = drivers.where((d) => d.cashInCustody > 0).toList();
    } else if (_riderLiabilityFilter == 'high_balance') {
      filtered = drivers.where((d) => d.cashInCustody >= 50000).toList();
    }

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('All Riders (${drivers.length})', _riderLiabilityFilter == 'all', () {
                  setState(() => _riderLiabilityFilter = 'all');
                }),
                const SizedBox(width: 8),
                _buildFilterPill('Holding Cash (${drivers.where((d) => d.cashInCustody > 0).length})', _riderLiabilityFilter == 'holding_cash', () {
                  setState(() => _riderLiabilityFilter = 'holding_cash');
                }),
                const SizedBox(width: 8),
                _buildFilterPill('High Liability (>₦50k)', _riderLiabilityFilter == 'high_balance', () {
                  setState(() => _riderLiabilityFilter = 'high_balance');
                }),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = filtered[index];
              final hasLiability = d.cashInCustody > 0;
              final isHigh = d.cashInCustody >= 50000;

              // Check if rider has active clearance requests
              final riderPending = pendingRemittances.where((r) =>
                r.deliveryAgentId == d.id || r.deliveryAgentId == d.driverCode
              ).toList();
              final double requestedAmount = riderPending.fold(0.0, (s, r) => s + r.amount);

              // Calculate Deductions (Commission, Fuel & POS Fee)
              final riderDelivered = allOrders.where((o) =>
                (o.deliveryAgentId == d.id || o.deliveryAgentId == d.driverCode) && o.isDelivered
              ).toList();
              final orderCount = riderDelivered.isNotEmpty ? riderDelivered.length : (hasLiability ? 1 : 0);
              final commRate = d.commissionRate > 0 ? d.commissionRate : 1000.0;
              final fuelRate = d.transportAllowance > 0 ? d.transportAllowance : 1500.0;
              final commDeduction = orderCount * commRate;
              final fuelDeduction = orderCount > 0 ? fuelRate : 0.0;
              final posDeduction = d.cashInCustody > 0 ? 350.0 : 0.0;
              final double totalDeductions = commDeduction + fuelDeduction + posDeduction;

              final double netRemittable = (d.cashInCustody - totalDeductions).clamp(0.0, double.infinity);
              final double unrequestedNet = (netRemittable - requestedAmount).clamp(0.0, double.infinity);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openRiderCashDossier(
                    context,
                    d,
                    riderPending,
                    d.cashInCustody,
                    unrequestedNet,
                    commDeduction,
                    fuelDeduction,
                    posDeduction,
                    orderCount,
                    isDark,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHigh
                            ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                            : (hasLiability ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            UserAvatarWidget(fullName: d.name, radius: 21),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          d.name,
                                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          d.driverCode,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d.phone} • Gross: ${CurrencyFormatter.formatNaira(d.cashInCustody)}',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatNaira(netRemittable),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: isHigh
                                        ? const Color(0xFFDC2626)
                                        : (hasLiability ? const Color(0xFFEA580C) : const Color(0xFF16A34A)),
                                  ),
                                ),
                                Text(
                                  hasLiability ? 'Net Payable' : 'Cleared (₦0)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: hasLiability ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.call_outlined, size: 18),
                              tooltip: 'Call Rider',
                              onPressed: () => _callPhone(d.phone),
                            ),
                          ],
                        ),

                        // Clearance State Indicator Badges
                        if (hasLiability) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (requestedAmount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '⏳ ₦${CurrencyFormatter.formatNaira(requestedAmount).replaceAll('₦', '')} Requested',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (unrequestedNet > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '🛑 ₦${CurrencyFormatter.formatNaira(unrequestedNet).replaceAll('₦', '')} Unrequested',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                  ),
                                ),
                              const Spacer(),
                              Text('Tap for ledger ›', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: AUDIT HISTORY (CLEARED REMITTANCES)
  // ==========================================
  Widget _buildAuditHistoryView(
    List<RemittanceEntity> approvedList,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (approvedList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_rounded, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'No historical approved remittances recorded yet.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: approvedList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rem = approvedList[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');
        final riderCode = driver != null ? driver.driverCode : 'RDR';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openRemittanceDetails(context, rem, driver, isDark),
            child: Container(
              padding: const EdgeInsets.all(14),
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
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_rounded, size: 20, color: Color(0xFF16A34A)),
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
                                '$riderName ($riderCode)',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CLEARED',
                                style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ref: ${rem.referenceNumber.isNotEmpty ? rem.referenceNumber : rem.id.substring(0, 8)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(rem.createdAt)}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatNaira(rem.amount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      Text(
                        rem.paymentMethodDisplay,
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00522A) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00522A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _openReceiptViewerModal(BuildContext context, String url, String riderName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: const Text('Could not load image.'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
