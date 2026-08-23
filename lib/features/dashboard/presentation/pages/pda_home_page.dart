import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../../core/widgets/offline_sync_banner.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/domain/entities/financial_summary.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

class PdaHomePage extends ConsumerStatefulWidget {
  const PdaHomePage({super.key});

  @override
  ConsumerState<PdaHomePage> createState() => _PdaHomePageState();
}

class _PdaHomePageState extends ConsumerState<PdaHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final agentId = user?.deliveryAgentId ?? user?.id ?? '';
      ref.read(ordersProvider.notifier).loadOrders(agentId);
      ref.read(financeProvider.notifier).loadRemittances(agentId);
      ref.read(notificationsProvider.notifier).fetchNotifications(agentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);
    final notifState = ref.watch(notificationsProvider);

    final user = authState.user;
    final bool isSalaried = user?.compensationType == 'salary' || user?.personnelType == 'inhouse';
    final agentName = user != null && (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
        ? '${user.firstName} ${user.lastName}'.trim()
        : (user?.fullName.isNotEmpty == true ? user!.fullName : '');
    final agentId = user?.deliveryAgentCode ?? '';
    final agentRole = isSalaried ? 'In-House Staff' : 'Freelance PDA';

    final orders = ordersState.orders;

    // Real-time calculations dynamically bound to live state
    final totalAssignedToday = orders.length;
    final successfulOrders = orders.where((o) => o.status == 'delivered').toList();
    final successfulCount = successfulOrders.length;
    final failedOrders = orders.where((o) => o.status == 'failed' || o.status == 'call_back').toList();
    final failedCount = failedOrders.length;
    final pendingOrders = orders.where((o) => o.status == 'accepted' || o.status == 'in_transit' || o.status == 'pending').toList();
    final pendingCount = pendingOrders.length;
    final completedCount = successfulCount + failedCount;

    final successRate = totalAssignedToday > 0
        ? ((successfulCount / totalAssignedToday) * 100).round()
        : 0;

    final summary = FinancialSummary.calculate(
      orders: orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
    );

    final double cashCollectedToday = summary.cashCollectedToday;
    final double pendingRemittance = summary.pendingRemittanceToDC;
    final double riderBalance = summary.myDirectTransfersBalance;
    final double monthlyEarnings = summary.totalMonthEarnings;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leadingWidth: 44,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogoWidget(
            variant: AppLogoVariant.square,
            height: 28,
          ),
        ),
        centerTitle: true,
        title: GestureDetector(
          onTap: () => context.push('/profile'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  agentName.isNotEmpty ? agentName.substring(0, 1).toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSalaried ? const Color(0xFF00522A) : const Color(0xFF003056),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            agentId,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• $agentRole',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurface, size: 24),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (notifState.unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBA1A1A),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '${notifState.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const OfflineSyncBanner(
            status: SyncStatus.online,
            pendingQueueCount: 0,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. GREETING STATUS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, $agentName 👋',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF008844), size: 8),
                              SizedBox(width: 5),
                              Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF008844),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF008844)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last sync: 08:45 AM',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. HERO REMITTANCE STATUS CARD
            pendingRemittance > 0
                ? Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(width: 4, color: const Color(0xFFEA580C)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'REMITTANCE REQUIRED',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFFB923C),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              CurrencyFormatter.formatNaira(pendingRemittance),
                                              style: GoogleFonts.inter(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Text(
                                            'Cash collected is awaiting remittance.',
                                            style: TextStyle(fontSize: 11, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEA580C),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => context.push('/cash/remit'),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Remit Now',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF064E3B).withValues(alpha: isDark ? 0.35 : 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(width: 4, color: const Color(0xFF10B981)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
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
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Text(
                                            'No pending cash in physical custody.',
                                            style: TextStyle(fontSize: 11, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white70),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => context.push('/cash/history'),
                                      child: Text(
                                        'History',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
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
            const SizedBox(height: 12),

            // 2B. HERO CARD: DUAL PERSONA (IN-HOUSE SALARIED VS FREELANCE PDA)
            isSalaried
                ? Container(
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
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Color(0xFFA7F3D0),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'MONTHLY SALARY',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFA7F3D0),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '(In-House)',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: const Color(0xFFD1FAE5),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatNaira(riderBalance),
                                  style: GoogleFonts.inter(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 13, color: Color(0xFFA7F3D0)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Payday: 28th',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user != null
                                    ? 'Fuel: ${CurrencyFormatter.formatNaira(user.fuelAllowance)}/day'
                                    : 'Fuel: ₦800/day',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    onTap: () => context.push('/finance/payouts'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.3 : 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: isDark ? 0.35 : 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: Color(0xFF93C5FD),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'MY BALANCE',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF93C5FD),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '(Direct Transfers)',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          color: const Color(0xFFCBD5E1),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    CurrencyFormatter.formatNaira(riderBalance),
                                    style: GoogleFonts.inter(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => context.push('/finance/payouts'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payments_outlined, size: 15, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  'Request Payout',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 14),

            // 3. GENERAL PERFORMANCE CONTAINER CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PerformanceMetricItem(
                      icon: Icons.speed_rounded,
                      iconBgColor: const Color(0xFF008844),
                      title: 'Success',
                      subtitle: '($successfulCount/$completedCount Done)',
                      value: '$successRate%',
                      valueColor: const Color(0xFF008844),
                    ),
                  ),
                  Container(height: 42, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _PerformanceMetricItem(
                      icon: Icons.assignment_outlined,
                      iconBgColor: const Color(0xFF38608F),
                      title: 'Assigned',
                      subtitle: '(Today)',
                      value: '$totalAssignedToday',
                      valueColor: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(height: 42, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _PerformanceMetricItem(
                      icon: Icons.check_circle_rounded,
                      iconBgColor: const Color(0xFF008844),
                      title: 'Delivered',
                      subtitle: '(Successful)',
                      value: '$successfulCount',
                      valueColor: const Color(0xFF008844),
                    ),
                  ),
                  Container(height: 42, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _PerformanceMetricItem(
                      icon: Icons.pending_actions_rounded,
                      iconBgColor: AppColors.orange,
                      title: 'Pending',
                      subtitle: '($failedCount Failed)',
                      value: '$pendingCount',
                      valueColor: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. FINANCIAL SUMMARY (WITH DIRECT ROUTE TO TRANSACTION BREAKDOWN)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FINANCIAL SUMMARY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/finance/transactions'),
                  child: const Row(
                    children: [
                      Text(
                        'View breakdown',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/finance/payouts'),
                      child: _FinancialItem(
                        icon: Icons.account_balance_rounded,
                        iconBgColor: const Color(0xFF2563EB),
                        title: 'My Balance',
                        subtitle: '(Direct Transfers)',
                        amount: CurrencyFormatter.formatNaira(riderBalance),
                        amountColor: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  Container(height: 44, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _FinancialItem(
                      icon: Icons.account_balance_wallet_rounded,
                      iconBgColor: const Color(0xFF008844),
                      title: 'My Earnings',
                      subtitle: '(This month)',
                      amount: CurrencyFormatter.formatNaira(monthlyEarnings),
                      amountColor: const Color(0xFF008844),
                    ),
                  ),
                  Container(height: 44, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _FinancialItem(
                      icon: Icons.payments_rounded,
                      iconBgColor: const Color(0xFF38608F),
                      title: 'Cash Collect...',
                      subtitle: '(Today)',
                      amount: CurrencyFormatter.formatNaira(cashCollectedToday),
                      amountColor: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(height: 44, width: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                  Expanded(
                    child: _FinancialItem(
                      icon: Icons.north_east_rounded,
                      iconBgColor: AppColors.orange,
                      title: 'Pending Re...',
                      subtitle: '(To remit)',
                      amount: CurrencyFormatter.formatNaira(pendingRemittance),
                      amountColor: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. DELIVERIES SECTION (EXACT OPERATIONAL DELIVERY CARDS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TODAY'S DELIVERIES",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ref.read(bottomNavIndexProvider.notifier).state = 2;
                  },
                  child: const Row(
                    children: [
                      Text(
                        'View more',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Delivery cards list mirroring orders_list_page.dart with skeleton loading
            if (ordersState.isLoading) ...[
              const OrderCardSkeleton(),
              const OrderCardSkeleton(),
            ] else if (orders.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 36,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No deliveries assigned yet for today',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check back when your Distribution Center dispatches new routes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Builder(
                builder: (context) {
                  final sortedOrders = [...orders];
                  sortedOrders.sort((a, b) {
                    int getStatusPriority(String status) {
                      switch (status.toLowerCase()) {
                        case 'in_transit':
                        case 'picked_up':
                          return 0; // Top: Active in progress
                        case 'pending':
                        case 'assigned':
                        case 'accepted':
                        case 'new':
                          return 1; // Next: Pending dispatch
                        case 'call_back':
                        case 'contacting':
                        case 'upsell_pending':
                          return 2; // Next: Call back
                        case 'delivered':
                          return 3; // Delivered (WhatsApp green)
                        case 'failed':
                        case 'cancelled':
                        case 'returned':
                          return 4; // Bottom
                        default:
                          return 2;
                      }
                    }

                    final pA = getStatusPriority(a.status);
                    final pB = getStatusPriority(b.status);
                    if (pA != pB) {
                      return pA.compareTo(pB);
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  return Column(
                    children: sortedOrders.take(3).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final o = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HomeDeliveryOperationalCard(order: o, index: idx),
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            const SizedBox(height: 6),

            // "View All Deliveries" Outlined Button linking to Deliveries tab
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(bottomNavIndexProvider.notifier).state = 2;
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text(
                  'View All Deliveries',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ],
),
);
  }
}

class _HomeDeliveryOperationalCard extends StatelessWidget {
  final OrderEntity order;
  final int index;

  const _HomeDeliveryOperationalCard({
    required this.order,
    required this.index,
  });

  void _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(' ', '').trim();
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isDelivered = order.status == 'delivered';
    final isFailed = order.status == 'failed' || order.status == 'cancelled';

    // Status-specific Left Accent Border Color
    Color statusLeftColor;
    Color statusBg;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (order.status) {
      case 'delivered':
        statusLeftColor = const Color(0xFF10B981); // WhatsApp Emerald
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'DELIVERED';
        statusIcon = Icons.done_all_rounded; // WhatsApp double check
        break;
      case 'in_transit':
        statusLeftColor = const Color(0xFF2563EB); // Electric Blue
        statusBg = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusLabel = 'IN PROGRESS';
        statusIcon = Icons.directions_bike_rounded;
        break;
      case 'failed':
        statusLeftColor = const Color(0xFFEF4444); // Crimson
        statusBg = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFB91C1C);
        statusLabel = 'FAILED';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'call_back':
        statusLeftColor = const Color(0xFF8B5CF6); // Purple
        statusBg = const Color(0xFFEDE9FE);
        statusTextColor = const Color(0xFF6D28D9);
        statusLabel = 'CALL BACK';
        statusIcon = Icons.phone_callback_rounded;
        break;
      case 'accepted':
      case 'pending':
      default:
        statusLeftColor = AppColors.orange; // Amber Orange
        statusBg = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFB45309);
        statusLabel = 'PENDING';
        statusIcon = Icons.schedule_rounded;
        break;
    }

    // Card background tint & border styling (WhatsApp read green for delivered)
    final cardBgColor = isDelivered
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.22) : const Color(0xFFF0FDF4))
        : (isFailed
            ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.15) : const Color(0xFFFEF2F2))
            : theme.cardColor);

    final cardBorder = isDelivered
        ? Border.all(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFF86EFAC).withValues(alpha: 0.7), width: 1.2)
        : (isFailed
            ? Border.all(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.3) : const Color(0xFFFECACA))
            : Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)));

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
            color: isDelivered
                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.1 : 0.06)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
              // Dynamic Status-Coded Left Accent Border Bar
              Container(
                width: 4.5,
                color: statusLeftColor,
              ),

              // Main Card Content
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/orders/${order.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Left: Customer Name, Status Badge, and Product
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Customer Name + Status Badge
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      order.customerName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: isDelivered ? 13 : 11, color: statusTextColor),
                                        const SizedBox(width: 3),
                                        Text(
                                          statusLabel,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: statusTextColor,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Address Info
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      order.deliveryAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Product Info
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      order.freeQuantity > 0
                                          ? '${order.productName} x ${order.totalPhysicalQuantity}'
                                          : '${order.productName} x ${order.quantity}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Obvious, High-Contrast Call Action Button
                        if (order.customerPhone.isNotEmpty)
                          Material(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(10),
                            elevation: 1,
                            child: InkWell(
                              onTap: () => _callCustomer(order.customerPhone),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 15, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Call',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceMetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String value;
  final Color valueColor;

  const _PerformanceMetricItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 15, color: iconBgColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}

class _FinancialItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  const _FinancialItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 15, color: iconBgColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: amountColor),
          ),
        ),
      ],
    );
  }
}
