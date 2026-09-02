import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_create_order_modal.dart';
import 'client_closer_workspace_page.dart';
import 'client_closers_page.dart';
import 'client_dashboard_page.dart';
import 'client_orders_page.dart';
import 'client_products_page.dart';

final clientActiveTabProvider = StateProvider<String>((ref) {
  final user = ref.watch(authProvider).user;
  if (user?.isCloser == true) {
    return 'leads';
  }
  return 'dashboard';
});

final clientSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class ClientPortalLayout extends ConsumerStatefulWidget {
  const ClientPortalLayout({super.key});

  @override
  ConsumerState<ClientPortalLayout> createState() => _ClientPortalLayoutState();
}

class _ClientPortalLayoutState extends ConsumerState<ClientPortalLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(clientActiveTabProvider);
    final state = ref.watch(clientPortalProvider);
    final authUser = ref.watch(authProvider).user;
    final isCloser = authUser?.isCloser == true;
    final isCollapsed = ref.watch(clientSidebarCollapsedProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      drawer: isDesktop
          ? null
          : Drawer(
              child: _buildSidebar(
                context,
                activeTab,
                state,
                isCloser,
                authUser,
                isCollapsed: false,
                isDrawer: true,
                isDark: isDark,
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            // Collapsible Desktop Sidebar
            if (isDesktop)
              _buildSidebar(
                context,
                activeTab,
                state,
                isCloser,
                authUser,
                isCollapsed: isCollapsed,
                isDrawer: false,
                isDark: isDark,
              ),

            // Main Screen Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header Bar
                  _buildTopAppBar(
                    context,
                    isDesktop,
                    isDark,
                    activeTab,
                    state,
                    authUser,
                    isCloser,
                  ),

                  // Active Tab Screen
                  Expanded(
                    child: _buildActivePage(ref, activeTab, isCloser),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePage(WidgetRef ref, String activeTab, bool isCloser) {
    switch (activeTab) {
      case 'leads':
        return const ClientCloserWorkspacePage();
      case 'closers':
        return const ClientClosersPage();
      case 'orders':
        return const ClientOrdersPage();
      case 'products':
        return const ClientProductsPage();
      case 'dashboard':
      default:
        if (isCloser) {
          return const ClientCloserWorkspacePage();
        }
        return ClientDashboardPage(
          onNavigateToOrders: () => ref.read(clientActiveTabProvider.notifier).state = 'orders',
          onNavigateToProducts: () => ref.read(clientActiveTabProvider.notifier).state = 'products',
        );
    }
  }

  Widget _buildSidebar(
    BuildContext context,
    String activeTab,
    ClientPortalState state,
    bool isCloser,
    dynamic authUser, {
    required bool isCollapsed,
    required bool isDrawer,
    required bool isDark,
  }) {
    final width = isCollapsed ? 76.0 : 255.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isDrawer ? 280.0 : width,
      decoration: const BoxDecoration(
        color: Color(0xFF031632), // NovaExpress Enterprise Deep Navy matching DC Console
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
                  child: Icon(
                    isCloser ? Icons.headset_mic_rounded : Icons.storefront_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCloser ? 'NovaExpress Sales' : 'NovaExpress Merchant',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCloser ? 'Telesales Closer Command' : 'Merchant Operations Hub',
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
                      tooltip: 'Collapse sidebar',
                      onPressed: () {
                        ref.read(clientSidebarCollapsedProvider.notifier).state = true;
                      },
                    ),
                ],
              ],
            ),
          ),

          if (isCollapsed)
            Center(
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF8293B5), size: 20),
                tooltip: 'Expand sidebar',
                onPressed: () {
                  ref.read(clientSidebarCollapsedProvider.notifier).state = false;
                },
              ),
            ),

          const SizedBox(height: 8),

          // Menu Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (isCloser) ...[
                  _buildNavItem(
                    key: 'leads',
                    title: 'My Leads & Dialer',
                    icon: Icons.headset_mic_rounded,
                    badge: state.leads.isNotEmpty ? '${state.leads.length}' : null,
                    isSelected: activeTab == 'leads',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildNavItem(
                    key: 'orders',
                    title: 'Booked Orders',
                    icon: Icons.shopping_bag_rounded,
                    badge: state.orders.isNotEmpty ? '${state.orders.length}' : null,
                    isSelected: activeTab == 'orders',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildNavItem(
                    key: 'products',
                    title: 'Product Catalog',
                    icon: Icons.inventory_2_rounded,
                    isSelected: activeTab == 'products',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                ] else ...[
                  _buildNavItem(
                    key: 'dashboard',
                    title: 'Dashboard & KPIs',
                    icon: Icons.dashboard_rounded,
                    isSelected: activeTab == 'dashboard',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildNavItem(
                    key: 'orders',
                    title: 'Deliveries & Orders',
                    icon: Icons.local_shipping_rounded,
                    badge: state.totalOrdersCount > 0 ? '${state.totalOrdersCount}' : null,
                    isSelected: activeTab == 'orders',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildNavItem(
                    key: 'products',
                    title: 'Products & Deals',
                    icon: Icons.inventory_2_rounded,
                    isSelected: activeTab == 'products',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  if (state.clientProfile.isEnterprise)
                    _buildNavItem(
                      key: 'closers',
                      title: 'Closers & Team',
                      icon: Icons.people_alt_rounded,
                      badge: state.closers.isNotEmpty ? '${state.closers.length}' : null,
                      isSelected: activeTab == 'closers',
                      isCollapsed: isCollapsed,
                      isDrawer: isDrawer,
                    ),
                ],
              ],
            ),
          ),

          // Bottom Closer / Client Profile Card matching DC Console
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
                      tooltip: 'Sign Out',
                      onPressed: () => _confirmLogout(context),
                    ),
                  )
                : Row(
                    children: [
                      UserAvatarWidget(
                        avatarUrl: authUser?.avatarUrl,
                        fullName: isCloser ? (authUser?.fullName ?? 'Amaka Chioma') : state.clientProfile.companyName,
                        radius: 18,
                        showBorder: true,
                        borderColor: const Color(0xFFF37021),
                        borderWidth: 1.5,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCloser ? (authUser?.fullName ?? 'Amaka Chioma') : state.clientProfile.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isCloser ? (authUser?.closerCode ?? 'CLS-NOVA-001') : state.clientProfile.code,
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
                        tooltip: 'Sign Out',
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String key,
    required String title,
    required IconData icon,
    String? badge,
    required bool isSelected,
    required bool isCollapsed,
    required bool isDrawer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? const Color(0xFF1A2B48) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            ref.read(clientActiveTabProvider.notifier).state = key;
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
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF37021) : const Color(0xFF1A2B48),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else if (isSelected)
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

  String _getActiveTabTitle(String activeTab, bool isCloser) {
    switch (activeTab) {
      case 'leads':
        return 'My Leads & Telesales Dialer';
      case 'closers':
        return 'Closers & Telesales Team';
      case 'orders':
        return isCloser ? 'Booked Orders Pipeline' : 'Deliveries & Customer Orders';
      case 'products':
        return 'Product Catalog & Deals';
      case 'dashboard':
      default:
        return isCloser ? 'My Leads & Telesales Dialer' : 'Merchant Dashboard';
    }
  }

  Widget _buildTopAppBar(
    BuildContext context,
    bool isDesktop,
    bool isDark,
    String activeTab,
    ClientPortalState state,
    dynamic authUser,
    bool isCloser,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;
    final activeTitle = _getActiveTabTitle(activeTab, isCloser);

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 20),
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

          // Active Merchant / Closer Station Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isCloser ? const Color(0xFFF37021) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isCloser ? 'Closer Desk' : (isCompact ? state.clientProfile.code : state.clientProfile.companyName),
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Active Screen Title
          Expanded(
            child: Text(
              activeTitle,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 13 : 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),

          if (!isCloser && !isCompact) ...[
            const SizedBox(width: 6),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ClientCreateOrderModal(),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text(
                'Book Order',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF37021),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],

          const SizedBox(width: 8),

          // User Profile Avatar
          UserAvatarWidget(
            avatarUrl: authUser?.avatarUrl,
            fullName: isCloser ? (authUser?.fullName ?? 'Amaka Chioma') : state.clientProfile.companyName,
            radius: 16,
            showBorder: true,
            borderColor: const Color(0xFFF37021),
            borderWidth: 1.5,
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to log out of the Sales & Merchant Portal?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
