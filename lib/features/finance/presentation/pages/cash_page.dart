import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/remittance.dart';
import '../providers/finance_provider.dart';

class CashPage extends ConsumerStatefulWidget {
  const CashPage({super.key});

  @override
  ConsumerState<CashPage> createState() => _CashPageState();
}

class _CashPageState extends ConsumerState<CashPage> {
  String _selectedFilter = 'all'; // 'all', 'approved', 'submitted', 'rejected'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
      ref.read(ordersProvider.notifier).loadOrders(agentId);
      ref.read(financeProvider.notifier).loadRemittances(agentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final financeState = ref.watch(financeProvider);
    final ordersState = ref.watch(ordersProvider);
    final notifState = ref.watch(notificationsProvider);

    final user = authState.user;
    final agentName = user != null && (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
        ? '${user.firstName} ${user.lastName}'.trim()
        : (user?.fullName.isNotEmpty == true ? user!.fullName : '');
    final agentCode = user?.deliveryAgentCode ?? '';

    // Dynamically calculate from unified financial summary
    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
    );

    final approvedRemittances = financeState.remittances
        .where((r) => r.isVerified || r.status.toLowerCase() == 'approved')
        .toList();
    final pendingRemittances = financeState.remittances
        .where((r) => r.isPending || r.status.toLowerCase() == 'submitted')
        .toList();
    final int deliveredCashCount = summary.todayDeliveredOrdersCount > 0
        ? summary.todayDeliveredOrdersCount
        : summary.deliveredCashOrdersCount;

    final double cashCollected = summary.cashCollectedToday > 0 ? summary.cashCollectedToday : summary.cashCollectedAllTime;
    final double totalCommission = summary.totalCommissionRetained;
    final double totalTransport = summary.totalTransportRetained;
    final double remitted = summary.totalVerifiedRemitted;
    final double pendingApproval = summary.totalPendingApprovalRemitted;
    final double toRemit = summary.pendingRemittanceToDC;
    final double riderBalance = summary.myDirectTransfersBalance;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(authProvider).user;
          final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
          await Future.wait([
            ref.read(financeProvider.notifier).loadRemittances(agentId),
            ref.read(ordersProvider.notifier).loadOrders(agentId),
          ]);
        },
        color: AppColors.orange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BRAND BLUE TOP HEADER WITH UNIFIED METRICS, MY BALANCE CARD & QUICK ACTIONS
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Navigation & Actions Bar
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remittance & Finance',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$agentCode • $agentName',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                                  tooltip: 'Notifications',
                                  onPressed: () => context.push('/notifications'),
                                ),
                                if (notifState.unreadCount > 0)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${notifState.unreadCount}',
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                              tooltip: 'More Options',
                              onPressed: () => _showMoreMenu(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Section Header: REMITTANCE OVERVIEW (Daily Only)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'REMITTANCE OVERVIEW',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Today',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFFCBD5E1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ALL 4 METRICS IN ONE SINGLE UNIFIED CARD (NON-SLIDABLE, BALANCED ROW)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF334155)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildCompactMetricColumn(
                                  icon: Icons.account_balance_wallet_outlined,
                                  iconColor: const Color(0xFF60A5FA),
                                  label: 'Collected',
                                  amount: cashCollected,
                                ),
                              ),
                              _buildVerticalSeparator(),
                              Expanded(
                                child: _buildCompactMetricColumn(
                                  icon: Icons.near_me_outlined,
                                  iconColor: const Color(0xFFFB923C),
                                  amountColor: const Color(0xFFFB923C),
                                  label: 'To Remit',
                                  amount: toRemit,
                                ),
                              ),
                              _buildVerticalSeparator(),
                              Expanded(
                                child: _buildCompactMetricColumn(
                                  icon: Icons.payments_outlined,
                                  iconColor: const Color(0xFF4ADE80),
                                  amountColor: const Color(0xFF4ADE80),
                                  label: 'Commission',
                                  amount: totalCommission,
                                ),
                              ),
                              _buildVerticalSeparator(),
                              Expanded(
                                child: _buildCompactMetricColumn(
                                  icon: Icons.directions_car_outlined,
                                  iconColor: const Color(0xFF38BDF8),
                                  amountColor: const Color(0xFF38BDF8),
                                  label: 'Transport',
                                  amount: totalTransport,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // MY BALANCE CARD (DIRECT TRANSFER EARNINGS & PAYOUT REQUEST)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF60A5FA)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'MY BALANCE',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: const Color(0xFF93C5FD),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '(Direct Transfers)',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      CurrencyFormatter.formatNaira(riderBalance),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _showRequestPayoutModal(context, riderBalance),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.payments_outlined, size: 13, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Request Payout',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // COMPACT QUICK ACTIONS (NO "QUICK ACTIONS" HEADER)
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactQuickActionPill(
                                icon: Icons.edit_document,
                                iconColor: const Color(0xFFFB923C),
                                label: 'Remit Now',
                                onTap: () => context.push('/cash/remit'),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactQuickActionPill(
                                icon: Icons.description_outlined,
                                iconColor: const Color(0xFF60A5FA),
                                label: 'Guidelines',
                                onTap: () => _showGuidelinesModal(context),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactQuickActionPill(
                                icon: Icons.history_rounded,
                                iconColor: const Color(0xFFC084FC),
                                label: 'History',
                                onTap: () => context.push('/cash/history'),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. MAIN BODY CONTENT (Pending Remittance Card & Settled History)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DEDICATED PENDING REMITTANCE / RECONCILED CARD (CLICKABLE)
                    toRemit > 0
                        ? InkWell(
                            onTap: () => context.push('/cash/remit'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Red left vertical indicator
                                      Container(
                                        width: 4,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Warning Triangle Icon
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Text Block (Pending title & amount)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'PENDING REMITTANCE',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.6,
                                                color: const Color(0xFFEF4444),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                CurrencyFormatter.formatNaira(toRemit),
                                                style: GoogleFonts.inter(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Remit Now CTA Button
                                      ElevatedButton(
                                        onPressed: () => context.push('/cash/remit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEA580C),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Remit Now',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                  const SizedBox(height: 8),

                                  // Dynamic details line
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Collected: ${CurrencyFormatter.formatNaira(cashCollected)}',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$deliveredCashCount order${deliveredCashCount == 1 ? '' : 's'}',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Remit Cash',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFF065F46),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF064E3B).withValues(alpha: isDark ? 0.35 : 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(width: 4, height: 44, color: const Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'REMITTANCES RECONCILED',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFA7F3D0),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₦0.00',
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      const Text(
                                        'All collections accounted for.',
                                        style: TextStyle(fontSize: 11, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white70),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => context.push('/cash/history'),
                                  child: Text(
                                    'History',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 18),

                    // REMITTANCE HISTORY SECTION (DYNAMIC LIST FROM FINANCE PROVIDER)
                    Text(
                      'REMITTANCE HISTORY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dynamic Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill('All (${financeState.remittances.length})', 'all', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Approved (${approvedRemittances.length})', 'approved', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Submitted (${pendingRemittances.length})', 'submitted', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Rejected (${financeState.remittances.where((r) => r.isRejected || r.status.toLowerCase() == 'rejected').length})', 'rejected', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Settled / Approved / Rejected History Cards List
                    Builder(
                      builder: (context) {
                        final allRems = financeState.remittances;
                        List<RemittanceEntity> displayList;
                        if (_selectedFilter == 'approved') {
                          displayList = approvedRemittances;
                        } else if (_selectedFilter == 'submitted') {
                          displayList = pendingRemittances;
                        } else if (_selectedFilter == 'rejected') {
                          displayList = allRems.where((r) => r.isRejected || r.status.toLowerCase() == 'rejected').toList();
                        } else {
                          displayList = allRems;
                        }

                        if (displayList.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Text(
                                'No ${_selectedFilter.toUpperCase()} remittances found.',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final rem in displayList) ...[
                              _buildRemittanceHistoryCard(
                                rem: rem,
                                isDark: isDark,
                                theme: theme,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetricColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double amount,
    Color? amountColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyFormatter.formatNaira(amount),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: amountColor ?? Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalSeparator() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0xFF334155),
    );
  }

  Widget _buildCompactQuickActionPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRemittanceHistoryCard({
    required RemittanceEntity rem,
    required bool isDark,
    required ThemeData theme,
  }) {
    Color accentColor;
    Color badgeBg;
    Color badgeTextColor;
    String badgeLabel;

    if (rem.isVerified || rem.status.toLowerCase() == 'approved') {
      accentColor = const Color(0xFF10B981);
      badgeBg = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF16A34A);
      badgeLabel = 'APPROVED';
    } else if (rem.isPending || rem.status.toLowerCase() == 'submitted') {
      accentColor = const Color(0xFFF59E0B);
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
      badgeLabel = 'SUBMITTED';
    } else if (rem.isRejected || rem.status.toLowerCase() == 'rejected') {
      accentColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFDC2626);
      badgeLabel = 'REJECTED';
    } else {
      accentColor = const Color(0xFF64748B);
      badgeBg = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
      badgeLabel = rem.status.toUpperCase();
    }

    final formattedTime = '${rem.createdAt.day} ${_monthName(rem.createdAt.month)}, ${rem.createdAt.hour.toString().padLeft(2, '0')}:${rem.createdAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => context.push('/cash/remittance/${rem.id.isNotEmpty ? rem.id : rem.referenceNumber}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rem.referenceNumber,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.formatNaira(rem.amount),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Remitted To',
                          value: rem.verifiedByName ?? (rem.isPending ? 'Wuse DC Receiving Desk' : 'NovaExpress Main Account'),
                          isBoldValue: false,
                          theme: theme,
                        ),
                        const SizedBox(height: 5),
                        _buildDetailRow(
                          icon: Icons.credit_card_outlined,
                          label: 'Payment Method',
                          value: rem.paymentMethodDisplay,
                          isBoldValue: false,
                          theme: theme,
                        ),
                        const SizedBox(height: 5),
                        _buildDetailRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'Reference',
                          value: _extractReference(rem),
                          isBoldValue: false,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extractReference(RemittanceEntity rem) {
    if (rem.notes != null && rem.notes!.isNotEmpty) {
      if (rem.notes!.contains('Ref:')) {
        final match = RegExp(r'Ref:\s*([A-Za-z0-9\-_]+)').firstMatch(rem.notes!);
        if (match != null && match.group(1) != null) {
          return match.group(1)!;
        }
      }
      return rem.notes!;
    }
    return rem.referenceNumber;
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isBoldValue,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestPayoutModal(BuildContext context, double riderBalance) {
    final amountController = TextEditingController(text: '15000');
    final accountController = TextEditingController(text: '0123456789');
    String selectedBank = 'Zenith Bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Request Balance Payout',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Withdraw earnings accumulated from Monnify direct transfers. Subject to DC approval.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Available Balance Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Balance:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                        Text(CurrencyFormatter.formatNaira(riderBalance), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Payout Amount (₦)',
                      prefixText: '₦ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bank Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedBank,
                    decoration: InputDecoration(
                      labelText: 'Select Bank',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['Zenith Bank', 'Access Bank', 'GTBank', 'Kuda Bank', 'Opay', 'Moniepoint', 'First Bank']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedBank = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Account Number Field
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Account Number',
                      hintText: '10 digits NUBAN',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Beneficiary Name: Emeka Rider (Verified)',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Submit CTA
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final reqAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (reqAmount <= 0 || reqAmount > riderBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount within your available balance.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text(
                              'Payout request for ${CurrencyFormatter.formatNaira(reqAmount)} submitted to DC for approval.',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Submit Payout Request', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Export Statement (PDF)'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.contact_support_outlined),
              title: const Text('Finance Support Contact'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuidelinesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NovaExpress Remittance Guidelines',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('1. All POD cash collected must be remitted by 6:00 PM daily.'),
            const SizedBox(height: 6),
            const Text('2. For direct Monnify transfers, earnings accumulate in your "My Balance".'),
            const SizedBox(height: 6),
            const Text('3. Allowed remittance methods: Bank Transfer, USSD, Direct DC Cash Handover.'),
            const SizedBox(height: 6),
            const Text('4. Always retain your transaction reference or receipt screenshot.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                child: const Text('I Understand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
