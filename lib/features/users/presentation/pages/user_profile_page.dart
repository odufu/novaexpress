import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? user.fullName : 'Emeka Rider';
    final agentInitials = user != null && user.firstName.isNotEmpty ? user.firstName.substring(0, 1).toUpperCase() : 'E';
    final agentCode = user?.deliveryAgentCode ?? 'PDA-7000';
    final dcName = user?.distributionCenterName ?? 'Wuse Distribution Center';
    final phone = user != null && user.phone.isNotEmpty ? user.phone : '+234 803 999 8877';
    final email = user != null && user.email.isNotEmpty ? user.email : 'emeka.rider@novaexpress.ng';

    final deliveredOrders = ordersState.orders.where((o) => o.status == 'delivered').toList();
    final totalOrders = ordersState.orders.length;

    final String lifetimeDrops = totalOrders > 0
        ? NumberFormat('#,###').format(deliveredOrders.isNotEmpty ? deliveredOrders.length : (user?.lifetimeDeliveriesCount ?? 4892))
        : NumberFormat('#,###').format(user?.lifetimeDeliveriesCount ?? 4892);

    final double computedRating = totalOrders > 0
        ? ((deliveredOrders.length / totalOrders) * 5.0).clamp(4.0, 5.0)
        : (user?.rating ?? 4.9);
    final String performanceRating = computedRating.toStringAsFixed(1);

    final double commissionRate = user?.commissionRate ?? 1000.0;
    final double transportAllowance = user?.isPda == false ? (user?.fuelAllowance ?? 800.0) : (user?.transportAllowance ?? 1500.0);
    final double totalEarningPerOrder = commissionRate + transportAllowance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              ref.read(bottomNavIndexProvider.notifier).state = 0;
            }
          },
        ),
        title: Text(
          'PROFILE & SETTINGS',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFF8928) : AppColors.primary,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final agentId = user?.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111';
          await ref.read(ordersProvider.notifier).loadOrders(agentId);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // User Info Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          agentInitials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        agentName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PDA ID: $agentCode • $dcName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Performance KPI Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            lifetimeDrops,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'LIFETIME DROPS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                performanceRating,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const Icon(Icons.star_rounded, color: Color(0xFFF37021), size: 20),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PERFORMANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dynamic Account & Contract Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: AppColors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Agent Account & Contract Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phone Number:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text(phone, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Email Address:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text(email, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Personnel Type:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text(
                            user?.isPda == false ? 'In-House Rider (Company Bike)' : 'Freelance PDA (Own Vehicle)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Commission Rate:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text('₦${commissionRate.toStringAsFixed(0)} / order', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transport Allowance:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text('₦${transportAllowance.toStringAsFixed(0)} / order', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Rider Earning:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          Text('₦${totalEarningPerOrder.toStringAsFixed(0)} / delivery', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00522A))),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bank Payout Settlement:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          const Text('Kuda MFB • 2019847291', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Settings Tile Options
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? const Color(0xFFFF8928) : AppColors.primary,
                      ),
                      title: Text(
                        'Dark Mode Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        isDark ? 'Industrial Dark Mode Active' : 'Light Mode Active',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: isDark,
                      activeColor: AppColors.orange,
                      onChanged: (val) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.onSurface),
                      title: Text('Notifications Preferences', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.onSurface),
                      title: Text('Security & Password', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.help_outline_rounded, color: theme.colorScheme.onSurface),
                      title: Text('Help & Field Support', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Logout of Terminal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
