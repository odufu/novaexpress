import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

class CashPage extends ConsumerWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? user.firstName : 'Emeka';

    final orders = ordersState.orders;

    // Calculate total POD cash collected from delivered orders
    final podCashCollected = orders
        .where((o) => o.status == 'delivered' && o.isPod)
        .fold(0.0, (sum, o) => sum + o.totalAmount);

    final totalCollected = podCashCollected > 0 ? podCashCollected : 245500.0;
    const remittanceLimit = 300000.0;
    final isRemittanceDue = totalCollected >= 200000.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leadingWidth: 140,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: AppLogoWidget(
            variant: AppLogoVariant.landscape,
            height: 24,
          ),
        ),
        title: Text(
          'Finance',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  agentName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outstanding Cash Card matching remitance/cash_remittance/screen.png
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF031632),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative Circular Arc Design Pattern
                  Positioned(
                    right: -20,
                    bottom: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1A2B48),
                          width: 20,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Outstanding Cash',
                            style: TextStyle(
                              color: Color(0xFF8293B5),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2B48),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.formatNaira(totalCollected),
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (isRemittanceDue) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBA1A1A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'REMITTANCE DUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            'Limit: ${CurrencyFormatter.formatNaira(remittanceLimit)}',
                            style: const TextStyle(
                              color: Color(0xFFE0E3E5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action Buttons (LOG REMITTANCE & VIEW HISTORY) matching screen.png
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/cash/remit'),
                    child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            'LOG REMITTANCE',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/cash/history'),
                    child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, color: theme.colorScheme.onSurface, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            'VIEW HISTORY',
                            style: GoogleFonts.jetBrainsMono(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daily Goal Card matching remitance/cash_remittance/screen.png
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '75% Achieved',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 0.75,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00522A)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remitted: ${CurrencyFormatter.formatNaira(150000)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Target: ${CurrencyFormatter.formatNaira(200000)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activity Section matching remitance/cash_remittance/screen.png
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15), width: 1),
              ),
              child: Column(
                children: [
                  // Item 1: Cash Collected (+₦45,000)
                  _ActivityListItem(
                    icon: Icons.arrow_downward_rounded,
                    iconBgColor: theme.colorScheme.surfaceContainer,
                    iconColor: const Color(0xFF00522A),
                    title: 'Cash Collected',
                    subtitle: 'Order #TRK-8924',
                    amountText: '+₦45,000',
                    amountColor: const Color(0xFF00522A),
                    timeAgo: '10:42 AM',
                  ),
                  const Divider(height: 1),

                  // Item 2: Bank Remittance (-₦150,000)
                  _ActivityListItem(
                    icon: Icons.account_balance_outlined,
                    iconBgColor: theme.colorScheme.surfaceContainer,
                    iconColor: theme.colorScheme.onSurface,
                    title: 'Bank Remittance',
                    subtitle: 'Ref: GTB-491-X',
                    amountText: '-₦150,000',
                    amountColor: theme.colorScheme.onSurface,
                    timeAgo: 'Yesterday',
                  ),
                  const Divider(height: 1),

                  // Item 3: Cash Collected (+₦12,500)
                  _ActivityListItem(
                    icon: Icons.arrow_downward_rounded,
                    iconBgColor: theme.colorScheme.surfaceContainer,
                    iconColor: const Color(0xFF00522A),
                    title: 'Cash Collected',
                    subtitle: 'Order #TRK-8921',
                    amountText: '+₦12,500',
                    amountColor: const Color(0xFF00522A),
                    timeAgo: 'Yesterday',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityListItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amountText;
  final Color amountColor;
  final String timeAgo;

  const _ActivityListItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.amountColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
