import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/presentation/pages/cash_page.dart';
import '../../../orders/presentation/pages/orders_list_page.dart';
import '../../../stock/presentation/pages/stock_page.dart';
import '../../../users/presentation/pages/user_profile_page.dart';
import 'pda_home_page.dart';

class MainBottomNavShell extends ConsumerWidget {
  const MainBottomNavShell({super.key});

  static const List<Widget> _pages = [
    PdaHomePage(),
    OrdersListPage(),
    StockPage(),
    CashPage(),
    UserProfilePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'HOME',
                  isSelected: currentIndex == 0,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'ORDERS',
                  isSelected: currentIndex == 1,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'STOCK',
                  isSelected: currentIndex == 2,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.payments_outlined,
                  label: 'FINANCE',
                  isSelected: currentIndex == 3,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 3,
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'PROFILE',
                  isSelected: currentIndex == 4,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = AppColors.orange;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
