import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/nova_tooltip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_console_provider.dart';
import '../widgets/admin_dc_modal.dart';
import '../widgets/admin_merchant_modal.dart';
import '../widgets/admin_user_modal.dart';
import 'tabs/admin_app_settings_tab.dart';
import 'tabs/admin_audit_logs_tab.dart';
import 'tabs/admin_distribution_centers_tab.dart';
import 'tabs/admin_merchants_tab.dart';
import 'tabs/admin_routing_tariffs_tab.dart';
import 'tabs/admin_server_settings_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminConsoleLayout extends ConsumerStatefulWidget {
  const AdminConsoleLayout({super.key});

  @override
  ConsumerState<AdminConsoleLayout> createState() => _AdminConsoleLayoutState();
}

class _AdminConsoleLayoutState extends ConsumerState<AdminConsoleLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _navItems = const [
    {
      'title': 'Users & RBAC',
      'icon': Icons.people_alt_outlined,
      'activeIcon': Icons.people_alt_rounded,
      'tooltip': 'Team members, role privileges, account suspension & onboarding',
    },
    {
      'title': 'DC & Hubs',
      'icon': Icons.hub_outlined,
      'activeIcon': Icons.hub_rounded,
      'tooltip': 'Distribution Centers, regional hubs, warehouse capacity & vaults',
    },
    {
      'title': 'Merchants',
      'icon': Icons.storefront_outlined,
      'activeIcon': Icons.storefront_rounded,
      'tooltip': 'E-commerce partners, closer allocation & COD remittance banks',
    },
    {
      'title': 'App Policies',
      'icon': Icons.tune_outlined,
      'activeIcon': Icons.tune_rounded,
      'tooltip': 'Proof of delivery enforcement, failure locks & rider cash caps',
    },
    {
      'title': 'Server & APIs',
      'icon': Icons.dns_outlined,
      'activeIcon': Icons.dns_rounded,
      'tooltip': 'Database health latency, Paystack, Monnify, Termii & WhatsApp tokens',
    },
    {
      'title': 'Routing & Tariffs',
      'icon': Icons.alt_route_rounded,
      'activeIcon': Icons.alt_route_rounded,
      'tooltip': '36 States hub matrix, shipping tariffs & PDA rider commissions',
    },
    {
      'title': 'Audit Trail',
      'icon': Icons.security_outlined,
      'activeIcon': Icons.security_rounded,
      'tooltip': 'Immutable security event stream of operator and configuration actions',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDark, state, notifier, currentUser)),
      body: Row(
        children: [
          // Desktop Fixed Sidebar
          if (isDesktop)
            SizedBox(
              width: 250,
              child: _buildSidebar(isDark, state, notifier, currentUser),
            ),

          // Main Content View
          Expanded(
            child: Column(
              children: [
                // Top Global Bar
                _buildTopBar(context, isDark, isDesktop, notifier, state),

                // Active Tab Content
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                      : IndexedStack(
                          index: state.activeTab,
                          children: const [
                            AdminUsersTab(),
                            AdminDistributionCentersTab(),
                            AdminMerchantsTab(),
                            AdminAppSettingsTab(),
                            AdminServerSettingsTab(),
                            AdminRoutingTariffsTab(),
                            AdminAuditLogsTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    AdminConsoleNotifier notifier,
    AdminConsoleState state,
  ) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
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

          // Active Tab Title
          Text(
            _navItems[state.activeTab]['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 10),

          // Live Database Environment Pill
          NovaTooltip(
            message: 'Connected to live production Supabase instance (${state.serverSettings.lastPingMs}ms)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
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
                    'LIVE BACKEND',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Quick Create Resource Menu
          _buildQuickAddMenu(context, isDark),
          const SizedBox(width: 8),

          // Refresh Button
          NovaTooltip(
            message: 'Synchronize live data with database',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => notifier.loadAll(),
            ),
          ),

          // Theme Switcher
          NovaTooltip(
            message: isDark ? 'Switch to light interface' : 'Switch to dark interface',
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddMenu(BuildContext context, bool isDark) {
    return PopupMenuButton<String>(
      tooltip: 'Quick create resource',
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (val) {
        final state = ref.read(adminConsoleProvider);
        final notifier = ref.read(adminConsoleProvider.notifier);

        if (val == 'user') {
          showDialog(
            context: context,
            builder: (context) => AdminUserModal(
              distributionCenters: state.distributionCenters,
              merchants: state.merchants,
              onSave: notifier.saveUser,
            ),
          );
        } else if (val == 'hub') {
          showDialog(
            context: context,
            builder: (context) => AdminDCModal(
              onSave: notifier.saveDistributionCenter,
            ),
          );
        } else if (val == 'merchant') {
          showDialog(
            context: context,
            builder: (context) => AdminMerchantModal(
              onSave: notifier.saveMerchant,
            ),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'user',
          child: Row(
            children: [
              const Icon(Icons.person_add_outlined, size: 16, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text('Onboard User', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'hub',
          child: Row(
            children: [
              const Icon(Icons.add_business_outlined, size: 16, color: AppColors.orange),
              const SizedBox(width: 8),
              Text('New DC / Hub', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'merchant',
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('Onboard Merchant', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Add Resource',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(
    bool isDark,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    dynamic currentUser,
  ) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NovaXpress',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Command Console',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Navigation List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = state.activeTab == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: NovaTooltip(
                    message: item['tooltip'] as String,
                    child: InkWell(
                      onTap: () {
                        notifier.setActiveTab(index);
                        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.orange.withValues(alpha: 0.5),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (isSelected ? item['activeIcon'] : item['icon']) as IconData,
                              size: 18,
                              color: isSelected
                                  ? AppColors.orange
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Switch Console Action (Inspect DC Operations)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: InkWell(
              onTap: () => context.go('/dc'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Switch to DC Operations',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // User Profile Card & Sign Out
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.orange,
                  child: Text(
                    currentUser?.firstName.isNotEmpty == true ? currentUser!.firstName[0].toUpperCase() : 'A',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.fullName ?? 'Administrator',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Super Administrator',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFF43F5E)),
                  tooltip: 'Sign Out',
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
