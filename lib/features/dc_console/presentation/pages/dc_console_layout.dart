import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../providers/dc_console_provider.dart';
import 'dc_dashboard_page.dart';
import 'dc_finance_page.dart';
import 'dc_orders_page.dart';
import 'dc_payouts_page.dart';
import 'dc_returns_page.dart';
import 'dc_riders_page.dart';
import 'dc_stock_page.dart';

class DCConsoleLayout extends ConsumerStatefulWidget {
  const DCConsoleLayout({super.key});

  @override
  ConsumerState<DCConsoleLayout> createState() => _DCConsoleLayoutState();
}

class _DCConsoleLayoutState extends ConsumerState<DCConsoleLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);
    final notifState = ref.watch(notificationsProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final pages = [
      const DCDashboardPage(),
      const DCOrdersPage(),
      const DCStockPage(),
      const DCFinancePage(),
      const DCReturnsPage(),
      const DCPayoutsPage(),
      const DCRidersPage(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, dcState, dcNotifier, isDark, user, isDrawer: true)),
      body: Row(
        children: [
          // Collapsible Desktop Sidebar
          if (isDesktop)
            _buildSidebar(context, dcState, dcNotifier, isDark, user, isDrawer: false),

          // Main Screen Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                _buildTopAppBar(context, isDesktop, isDark, dcState, dcNotifier, notifState.unreadCount, user),

                // Active Tab Screen
                Expanded(
                  child: IndexedStack(
                    index: dcState.activeTabIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    DCConsoleState state,
    DCConsoleNotifier notifier,
    bool isDark,
    dynamic user, {
    required bool isDrawer,
  }) {
    final isCollapsed = !isDrawer && state.isSidebarCollapsed;
    final width = isCollapsed ? 76.0 : 255.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isDrawer ? 280.0 : width,
      decoration: const BoxDecoration(
        color: Color(0xFF031632), // NovaExpress Enterprise Deep Navy
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar App Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 20),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021), // NovaExpress Signature Orange
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 20),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NovaExpress DC',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Hub Operations Command',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8293B5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isDrawer)
                    IconButton(
                      icon: const Icon(Icons.menu_open_rounded, color: Color(0xFF8293B5), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => notifier.toggleSidebar(),
                    ),
                ],
              ],
            ),
          ),

          if (isCollapsed)
            Center(
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF8293B5), size: 20),
                onPressed: () => notifier.toggleSidebar(),
              ),
            ),

          const SizedBox(height: 8),

          // Menu Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded, state.activeTabIndex == 0, isCollapsed, isDrawer),
                _buildNavItem(1, 'Deliveries & Orders', Icons.local_shipping_rounded, state.activeTabIndex == 1, isCollapsed, isDrawer),
                _buildNavItem(2, 'Inventory & Stock', Icons.inventory_2_rounded, state.activeTabIndex == 2, isCollapsed, isDrawer),
                _buildNavItem(3, 'Cash & Remittances', Icons.account_balance_wallet_rounded, state.activeTabIndex == 3, isCollapsed, isDrawer),
                _buildNavItem(4, 'Returns & QC Desk', Icons.assignment_return_rounded, state.activeTabIndex == 4, isCollapsed, isDrawer),
                _buildNavItem(5, 'Rider Payouts', Icons.payments_rounded, state.activeTabIndex == 5, isCollapsed, isDrawer),
                _buildNavItem(6, 'Riders & Fleet', Icons.badge_rounded, state.activeTabIndex == 6, isCollapsed, isDrawer),
              ],
            ),
          ),

          // Bottom Supervisor Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF020E20),
              border: Border(top: BorderSide(color: Color(0xFF1A2B48))),
            ),
            child: isCollapsed
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Logout of DC Console',
                      onPressed: () => _confirmDcLogout(context, ref),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2B48),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.5)),
                        ),
                        child: const Center(
                          child: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF37021), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user != null && user.fullName.isNotEmpty ? user.fullName : 'Adekunle Supervisor',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.distributionCenterName ?? 'Wuse DC Manager',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF8293B5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                        tooltip: 'Logout of DC Console',
                        onPressed: () => _confirmDcLogout(context, ref),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String title,
    IconData icon,
    bool isSelected,
    bool isCollapsed,
    bool isDrawer,
  ) {
    final notifier = ref.read(dcConsoleProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? const Color(0xFF1A2B48) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            notifier.setActiveTab(index);
            if (isDrawer) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 14,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFFF37021) : const Color(0xFF8293B5),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF37021),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    bool isDesktop,
    bool isDark,
    DCConsoleState dcState,
    DCConsoleNotifier dcNotifier,
    int unreadCount,
    dynamic user,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          // Hub Selector Dropdown Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dcState.activeHubName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${dcState.activeHubCode})',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Search Field
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => dcNotifier.setSearchQuery(val),
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search orders, waybills, packages, or riders...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Theme Switcher Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: const Color(0xFF64748B),
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),

          // Notifications Bell with Unread Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF64748B)),
                onPressed: () => context.push('/notifications'),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 8),

          // DC Supervisor Profile & Logout Menu
          PopupMenuButton<String>(
            tooltip: 'Supervisor Account',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            offset: const Offset(0, 48),
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF031632),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF37021), size: 14),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    Text(
                      user != null && user.fullName.isNotEmpty ? user.fullName : 'Adekunle Supervisor',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ],
                ],
              ),
            ),
            onSelected: (val) {
              if (val == 'logout') {
                _confirmDcLogout(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user != null && user.fullName.isNotEmpty ? user.fullName : 'Adekunle Supervisor',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF031632)),
                    ),
                    Text(
                      user?.email ?? 'dc.supervisor@novaexpress.ng',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DC Manager',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFF37021), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Logout of DC Console',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDcLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Confirm DC Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of the Distribution Center Management Console?',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
