import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/client_logo_widget.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_create_order_modal.dart';
import 'client_closer_workspace_page.dart';
import 'client_closers_page.dart';
import 'client_dashboard_page.dart';
import 'finance/client_expenses_view.dart';
import 'finance/client_payouts_view.dart';
import 'finance/client_profits_view.dart';
import 'finance/client_remittance_view.dart';
import 'client_inventory_page.dart';
import 'client_orders_page.dart';
import 'client_products_page.dart';
import 'client_marketing_suite_page.dart';
import 'closer_mobile_portal_page.dart';
import '../../../pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';
import '../../../pipeline_chat/presentation/providers/pipeline_chat_fab_provider.dart';
import '../../../users/presentation/widgets/edit_profile_modal.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/entities/app_notification.dart';

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
  bool _isFinanceExpanded = true;

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(clientActiveTabProvider);
    final state = ref.watch(clientPortalProvider);
    final authUser = ref.watch(authProvider).user;
    final isCloser = authUser?.isCloser == true;

    // Route sales closer directly to dedicated mobile-first closer portal
    if (isCloser) {
      return const CloserMobilePortalPage();
    }

    final isCollapsed = ref.watch(clientSidebarCollapsedProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      floatingActionButton: const PipelineChatFloatingActionButton(),
      floatingActionButtonLocation: ref.watch(pipelineChatFabLocationProvider),
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
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(context, activeTab, state, isDark),
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
      case 'inventory':
        return const ClientInventoryPage();
      case 'finance':
      case 'finance_remittance':
        return const ClientRemittanceView();
      case 'finance_expenses':
        return const ClientExpensesView();
      case 'finance_profits':
        return const ClientProfitsView();
      case 'finance_payouts':
        return const ClientPayoutsView();
      case 'products':
        return const ClientProductsPage();
      case 'marketing':
        return const ClientMarketingSuitePage();
      case 'dashboard':
      default:
        if (isCloser) {
          return const ClientCloserWorkspacePage();
        }
        return ClientDashboardPage(
          onNavigateToOrders: () => ref.read(clientActiveTabProvider.notifier).state = 'orders',
          onNavigateToProducts: () => ref.read(clientActiveTabProvider.notifier).state = 'products',
          onNavigateToInventory: () => ref.read(clientActiveTabProvider.notifier).state = 'inventory',
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
    final brandPrimary = state.clientProfile.brandPrimaryColor;
    final brandLogo = state.clientProfile.logoUrl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isDrawer ? 280.0 : width,
      decoration: const BoxDecoration(
        color: Color(0xFF031632), // NovaXpress Enterprise Deep Navy matching DC Console
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
                ClientLogoWidget(
                  logoUrl: brandLogo,
                  companyName: state.clientProfile.companyName,
                  size: 36,
                  borderRadius: 10,
                  brandColor: brandPrimary,
                  isCloser: isCloser,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCloser
                              ? '${state.clientProfile.companyName} Sales'
                              : state.clientProfile.companyName,
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
                    title: 'Dashboard',
                    icon: Icons.dashboard_rounded,
                    isSelected: activeTab == 'dashboard',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildNavItem(
                    key: 'orders',
                    title: 'Orders',
                    icon: Icons.local_shipping_rounded,
                    badge: state.totalOrdersCount > 0 ? '${state.totalOrdersCount}' : null,
                    isSelected: activeTab == 'orders',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  _buildExpandableFinanceItem(
                    activeTab: activeTab,
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                    state: state,
                  ),
                  _buildNavItem(
                    key: 'products',
                    title: 'Products',
                    icon: Icons.inventory_2_rounded,
                    isSelected: activeTab == 'products',
                    isCollapsed: isCollapsed,
                    isDrawer: isDrawer,
                  ),
                  if (state.clientProfile.hasInventoryManagement)
                    _buildNavItem(
                      key: 'inventory',
                      title: 'Inventory',
                      icon: Icons.warehouse_rounded,
                      badge: state.stockBalances.isNotEmpty ? '${state.uniqueWarehousesCount} Hubs' : null,
                      isSelected: activeTab == 'inventory',
                      isCollapsed: isCollapsed,
                      isDrawer: isDrawer,
                    ),
                  if (state.clientProfile.isEnterprise)
                    _buildNavItem(
                      key: 'closers',
                      title: 'Closers',
                      icon: Icons.people_alt_rounded,
                      badge: state.closers.isNotEmpty ? '${state.closers.length}' : null,
                      isSelected: activeTab == 'closers',
                      isCollapsed: isCollapsed,
                      isDrawer: isDrawer,
                    ),
                  _buildNavItem(
                    key: 'marketing',
                    title: 'Marketing',
                    icon: Icons.campaign_rounded,
                    badge: state.leadForms.isNotEmpty ? '${state.leadForms.length}' : null,
                    isSelected: activeTab == 'marketing',
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
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (authUser != null) {
                            EditProfileModal.show(context, authUser);
                          }
                        },
                        child: UserAvatarWidget(
                          avatarUrl: (authUser?.avatarUrl != null && authUser!.avatarUrl!.trim().isNotEmpty)
                              ? authUser?.avatarUrl
                              : state.clientProfile.logoUrl,
                          fullName: isCloser ? (authUser?.fullName ?? 'Amaka Chioma') : state.clientProfile.companyName,
                          radius: 18,
                          showBorder: true,
                          borderColor: brandPrimary,
                          borderWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (authUser != null) {
                              EditProfileModal.show(context, authUser);
                            }
                          },
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
    final brandPrimary = ref.watch(clientPortalProvider).clientProfile.brandPrimaryColor;

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
                  color: isSelected ? brandPrimary : const Color(0xFF8293B5),
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
                        color: isSelected ? brandPrimary : const Color(0xFF1A2B48),
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
                      decoration: BoxDecoration(
                        color: brandPrimary,
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

  Widget _buildExpandableFinanceItem({
    required String activeTab,
    required bool isCollapsed,
    required bool isDrawer,
    required ClientPortalState state,
  }) {
    final brandPrimary = state.clientProfile.brandPrimaryColor;
    final isAnyFinanceSelected = activeTab.startsWith('finance');
    final awaitingRemittance = state.activeFinanceSummary.awaitingRemittance;

    if (isCollapsed) {
      return Tooltip(
        message: 'Finance',
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isAnyFinanceSelected ? const Color(0xFF1A2B48) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                ref.read(clientActiveTabProvider.notifier).state = 'finance_remittance';
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Center(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: isAnyFinanceSelected ? brandPrimary : const Color(0xFF8293B5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent Header Tile
          Material(
            color: (isAnyFinanceSelected && !_isFinanceExpanded) ? const Color(0xFF1A2B48) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isFinanceExpanded = !_isFinanceExpanded;
                });
                if (!isAnyFinanceSelected) {
                  ref.read(clientActiveTabProvider.notifier).state = 'finance_remittance';
                }
              },
              borderRadius: BorderRadius.circular(10),
              hoverColor: Colors.white.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20,
                      color: isAnyFinanceSelected ? brandPrimary : const Color(0xFF8293B5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Finance',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isAnyFinanceSelected ? FontWeight.bold : FontWeight.w500,
                          color: isAnyFinanceSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (awaitingRemittance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Ready',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    Icon(
                      _isFinanceExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF8293B5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sub-items list when expanded
          if (_isFinanceExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Column(
                children: [
                  _buildSubNavItem(
                    key: 'finance_remittance',
                    title: 'Remittance',
                    tooltip: 'Daily Collections & Payouts',
                    icon: Icons.payments_outlined,
                    isSelected: activeTab == 'finance_remittance' || activeTab == 'finance',
                    isDrawer: isDrawer,
                  ),
                  _buildSubNavItem(
                    key: 'finance_expenses',
                    title: 'Expenses',
                    tooltip: 'Operating & Product Expenditures',
                    icon: Icons.receipt_long_outlined,
                    isSelected: activeTab == 'finance_expenses',
                    isDrawer: isDrawer,
                  ),
                  _buildSubNavItem(
                    key: 'finance_profits',
                    title: 'Profits',
                    tooltip: 'Commercial Profit & Loss Analysis',
                    icon: Icons.trending_up_rounded,
                    isSelected: activeTab == 'finance_profits',
                    isDrawer: isDrawer,
                  ),
                  _buildSubNavItem(
                    key: 'finance_payouts',
                    title: 'Payouts',
                    tooltip: 'Closer & Marketer Commission Payouts',
                    icon: Icons.account_balance_rounded,
                    isSelected: activeTab == 'finance_payouts',
                    isDrawer: isDrawer,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubNavItem({
    required String key,
    required String title,
    required String tooltip,
    required IconData icon,
    required bool isSelected,
    required bool isDrawer,
  }) {
    final brandPrimary = ref.watch(clientPortalProvider).clientProfile.brandPrimaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isSelected ? const Color(0xFF1A2B48) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () {
              ref.read(clientActiveTabProvider.notifier).state = key;
              if (isDrawer) {
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected ? brandPrimary : const Color(0xFF64748B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? brandPrimary : const Color(0xFF8293B5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
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

  String _getActiveTabTitle(String activeTab, bool isCloser) {
    switch (activeTab) {
      case 'leads':
        return 'Leads';
      case 'closers':
        return 'Closers';
      case 'orders':
        return 'Orders';
      case 'finance':
      case 'finance_remittance':
        return 'Remittance';
      case 'finance_expenses':
        return 'Expenses';
      case 'finance_profits':
        return 'Profits';
      case 'finance_payouts':
        return 'Payouts';
      case 'inventory':
        return 'Inventory';
      case 'products':
        return 'Products';
      case 'marketing':
        return 'Marketing';
      case 'dashboard':
      default:
        return isCloser ? 'Leads' : 'Dashboard';
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
    final isVeryCompact = screenWidth < 500;
    final activeTitle = _getActiveTabTitle(activeTab, isCloser);
    final brandPrimary = state.clientProfile.brandPrimaryColor;

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 20),
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
              tooltip: 'Navigation Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          // Active Merchant / Closer Station Status Pill (hide on very small screens to preserve title space)
          if (!isVeryCompact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              margin: const EdgeInsets.only(right: 10),
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
                      color: isCloser ? brandPrimary : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isCloser ? 'Closer Desk' : (isCompact ? state.clientProfile.code : state.clientProfile.companyName),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Active Screen Title
          Expanded(
            child: Text(
              activeTitle,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 13.5 : 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Notifications Bell with Alert Badge
          Consumer(
            builder: (context, ref, _) {
              final notifState = ref.watch(notificationsProvider);
              final portalState = ref.watch(clientPortalProvider);
              final outOfStockCount = portalState.stockBalances.where((b) => b.balanceQty <= 0).length +
                  portalState.products.where((p) => p.stockQuantity <= 0).length;
              final totalAlerts = notifState.unreadCount + outOfStockCount;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      totalAlerts > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: totalAlerts > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      size: 21,
                    ),
                    tooltip: 'Notifications & Alerts (${totalAlerts > 0 ? "$totalAlerts new" : "No alerts"})',
                    onPressed: () => _showNotificationsDialog(context, isDark),
                  ),
                  if (totalAlerts > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            totalAlerts > 9 ? '9+' : '$totalAlerts',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
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

          if (!isCloser) ...[
            if (isCompact)
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ClientCreateOrderModal(),
                  );
                },
                icon: Icon(Icons.add_circle_rounded, color: brandPrimary, size: 24),
                tooltip: 'Book Order',
              )
            else
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
                  backgroundColor: brandPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
          ],

          const SizedBox(width: 4),

          // User Profile Avatar
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (authUser != null) {
                EditProfileModal.show(context, authUser);
              }
            },
            child: Tooltip(
              message: 'Edit Profile & Settings',
              child: UserAvatarWidget(
                avatarUrl: authUser?.avatarUrl,
                fullName: isCloser ? (authUser?.fullName ?? 'Amaka Chioma') : state.clientProfile.companyName,
                radius: 15,
                showBorder: true,
                borderColor: brandPrimary,
                borderWidth: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(
    BuildContext context,
    String activeTab,
    ClientPortalState state,
    bool isDark,
  ) {
    final brandPrimary = state.clientProfile.brandPrimaryColor;
    final navItems = [
      (key: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      (key: 'orders', label: 'Orders', icon: Icons.local_shipping_rounded),
      if (state.clientProfile.hasInventoryManagement)
        (key: 'inventory', label: 'Inventory', icon: Icons.warehouse_rounded),
      (key: 'products', label: 'Products', icon: Icons.inventory_2_rounded),
      (key: 'finance_remittance', label: 'Finance', icon: Icons.account_balance_wallet_rounded),
      if (state.clientProfile.isEnterprise)
        (key: 'closers', label: 'Closers', icon: Icons.people_alt_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) {
              final isSelected = item.key == 'finance_remittance'
                  ? activeTab.startsWith('finance')
                  : activeTab == item.key;
              return Expanded(
                child: InkWell(
                  onTap: () => ref.read(clientActiveTabProvider.notifier).state = item.key,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? brandPrimary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? brandPrimary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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

  void _showNotificationsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final notifState = ref.watch(notificationsProvider);
          final portalState = ref.watch(clientPortalProvider);
          final outOfStockBalances = portalState.stockBalances.where((b) => b.balanceQty <= 0).toList();
          final outOfStockProducts = portalState.products.where((p) => p.stockQuantity <= 0).toList();
          final notifications = notifState.notifications;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 520,
              constraints: const BoxConstraints(maxHeight: 640),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded, color: Color(0xFF0D9488), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Alerts & Notifications',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (outOfStockBalances.isNotEmpty || outOfStockProducts.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'URGENT: Stock Exhaustion at DC',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFDC2626)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...outOfStockBalances.map((b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• "${b.itemName}" has 0 units at ${b.warehouse.isNotEmpty ? b.warehouse : "Distribution Center"}.',
                                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                                  ),
                                )),
                                if (outOfStockBalances.isEmpty)
                                  ...outOfStockProducts.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• "${p.name}" has 0 units available.',
                                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                                    ),
                                  )),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    ref.read(clientActiveTabProvider.notifier).state = 'inventory';
                                  },
                                  icon: const Icon(Icons.local_shipping_rounded, size: 14),
                                  label: Text('Open Inventory Ledger & Supply', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (notifications.isEmpty && outOfStockBalances.isEmpty && outOfStockProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text('All caught up! No active alerts.', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                                ],
                              ),
                            ),
                          )
                        else
                          ...notifications.map((n) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  n.category == NotificationCategory.stock
                                      ? Icons.inventory_2_outlined
                                      : (n.category == NotificationCategory.delivery ? Icons.two_wheeler_rounded : Icons.info_outline_rounded),
                                  size: 18,
                                  color: const Color(0xFF0D9488),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                      const SizedBox(height: 2),
                                      Text(n.message, style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                      ],
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
}
