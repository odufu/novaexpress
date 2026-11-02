import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/ux_states/ux_states.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../orders/domain/entities/order.dart';
import '../../data/repositories/expenditure_repository.dart';
import '../../domain/entities/business_expenditure.dart';
import '../../domain/entities/client_settlement.dart';
import '../providers/client_portal_provider.dart';
import '../providers/merchant_settlements_provider.dart';
import '../widgets/client_add_expenditure_modal.dart';
import '../widgets/merchant_settlement_sheet.dart';
import 'merchant_bi_chat_page.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../users/presentation/widgets/edit_profile_modal.dart';

/// Expanded Mobile Console for Merchant Accountants:
/// 5 Core Tabs:
///  0. Settles: Daily accumulating multi-DC remittances, validation queue & history
///  1. Income: Delivered counts & COD, failed attempt costs, rider comms & ledger
///  2. Expenses: Operating expenditures, category breakdowns & live "+ Log" action
///  3. NovaBI: AI business intelligence copilot with interactive charts & flowcharts
///  4. Profile: Accountant credentials, verified bank payout destination & security (last on right)
class MerchantSettlementsMobilePage extends ConsumerStatefulWidget {
  const MerchantSettlementsMobilePage({super.key});

  @override
  ConsumerState<MerchantSettlementsMobilePage> createState() => _MerchantSettlementsMobilePageState();
}

class _MerchantSettlementsMobilePageState extends ConsumerState<MerchantSettlementsMobilePage> {
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
  final shortDateFormat = DateFormat('MMM dd, yyyy');
  final searchController = TextEditingController();
  final incomeSearchController = TextEditingController();

  int _activeBottomTab = 0;
  String _incomeFilter = 'all'; // 'all', 'delivered', 'failed', 'pending'

  // Expenses Tab State
  final ExpenditureRepository _expenditureRepo = ExpenditureRepository();
  List<BusinessExpenditureEntity> _expenditures = [];
  bool _isLoadingExpenses = false;
  String _selectedExpenseCategory = 'all';

  final List<String> _tabTitles = const [
    'Settlements',
    'Income',
    'Expenses',
    'NovaBI Intel',
    'Accountant Profile',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    incomeSearchController.dispose();
    super.dispose();
  }

  void _onRefresh() {
    ref.read(merchantSettlementsProvider.notifier).loadData();
    if (_activeBottomTab == 2) {
      _loadExpenses();
    }
  }

  Future<void> _loadExpenses() async {
    final clientId = ref.read(merchantSettlementsProvider).clientProfile.id;
    if (clientId.isEmpty) return;
    setState(() => _isLoadingExpenses = true);
    try {
      final list = await _expenditureRepo.fetchMerchantExpenditures(clientId: clientId);
      if (mounted) {
        setState(() {
          _expenditures = list;
          _isLoadingExpenses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExpenses = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of the Merchant Console?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _showPasswordResetDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF37021), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Change Password',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                    isDense: true,
                  ),
                  validator: (v) => v != newPassCtrl.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      final result = await ref.read(authProvider.notifier).changePassword(
                            oldPassword: oldPassCtrl.text.trim(),
                            newPassword: newPassCtrl.text.trim(),
                          );
                      setDialogState(() => isSubmitting = false);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: result['success'] == true
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            content: Text(result['message']?.toString() ??
                                result['error']?.toString() ??
                                'Password updated successfully!'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021)),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Update',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantSettlementsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final ongoingList = state.ongoingDcSettlements;
    final awaitingList = state.awaitingValidationSettlements;
    final clearedList = state.clearedSettlementsHistory;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 50,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF37021), Color(0xFFFF944D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _tabTitles[_activeBottomTab],
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Row(
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
                  Flexible(
                    child: Text(
                      state.clientProfile.companyName.isNotEmpty
                          ? state.clientProfile.companyName
                          : 'Novacare Health',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Theme Switcher
            IconButton(
              tooltip: isDark ? 'Light' : 'Dark',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
            // Refresh
            IconButton(
              tooltip: 'Refresh',
              icon: state.isLoading || _isLoadingExpenses
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _onRefresh,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
      body: IndexedStack(
        index: _activeBottomTab,
        children: [
          // 0. Settlements Tab
          _buildSettlementsTab(context, state, isDark, ongoingList, awaitingList, clearedList),
          // 1. Income Tab
          _buildIncomeTab(context, isDark),
          // 2. Expenses Tab
          _buildExpensesTab(context, state, isDark),
          // 3. NovaBI Tab
          const MerchantBiChatPage(),
          // 4. Profile Tab (Last by right)
          _buildProfileTab(context, state, isDark),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeBottomTab,
        onDestinationSelected: (idx) {
          setState(() => _activeBottomTab = idx);
          if (idx == 2 && _expenditures.isEmpty) {
            _loadExpenses();
          }
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        indicatorColor: const Color(0xFFF37021).withValues(alpha: 0.15),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF37021)),
            label: 'Settles',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFFF37021)),
            label: 'Income',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded, color: Color(0xFFF37021)),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: Color(0xFFF37021)),
            label: 'NovaBI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFFF37021)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: SETTLEMENTS VIEW
  // =========================================================================
  Widget _buildSettlementsTab(
    BuildContext context,
    MerchantSettlementsState state,
    bool isDark,
    List<LiveOngoingSettlement> ongoingList,
    List<ClientSettlement> awaitingList,
    List<ClientSettlement> clearedList,
  ) {
    return RefreshIndicator(
      onRefresh: () async => _onRefresh(),
      color: const Color(0xFFF37021),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Top Summary KPIs
          SliverToBoxAdapter(
            child: _buildTopKpiRow(context, state, isDark),
          ),

          // Segmented Navigation Bar
          SliverToBoxAdapter(
            child: _buildSegmentedTabBar(
                context, state, isDark, ongoingList.length, awaitingList.length),
          ),

          // DC Filters & Search Bar
          SliverToBoxAdapter(
            child: _buildFilterBar(context, state, isDark),
          ),

          // Tab Content
          if (state.selectedTab == 'ongoing') ...[
            _buildOngoingSliverList(context, state, ongoingList, isDark),
          ] else if (state.selectedTab == 'awaiting') ...[
            _buildAwaitingSliverList(context, state, awaitingList, isDark),
          ] else ...[
            _buildHistorySliverList(context, state, clearedList, isDark),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildTopKpiRow(BuildContext context, MerchantSettlementsState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Remitted',
                  value: currencyFormat.format(state.totalLiveGrowingToday),
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFF37021),
                  bgColor: const Color(0xFFF37021).withValues(alpha: 0.1),
                  tooltip: 'Rider cash and transfer collections today',
                  isDark: isDark,
                  isLivePulse: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  title: 'Expected',
                  value: currencyFormat.format(state.totalLiveExpectedPayout),
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  tooltip: 'Net payout after delivery tariffs',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Pending',
                  value: currencyFormat.format(state.totalAwaitingValidationAmount),
                  icon: Icons.hourglass_top_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  tooltip: 'Awaiting your sign-off',
                  isDark: isDark,
                  badge: state.awaitingValidationSettlements.isNotEmpty
                      ? '${state.awaitingValidationSettlements.length}'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  title: 'Cleared',
                  value: currencyFormat.format(state.totalClearedThisMonth),
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                  tooltip: 'Disbursed payouts this month',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String tooltip,
    required bool isDark,
    bool isLivePulse = false,
    String? badge,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 14, color: iconColor),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
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
                  ),
                if (isLivePulse && badge == null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF37021),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabBar(BuildContext context, MerchantSettlementsState state, bool isDark,
      int ongoingCount, int awaitingCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: 'Ongoing',
              badgeCount: ongoingCount,
              badgeColor: const Color(0xFFF37021),
              isSelected: state.selectedTab == 'ongoing',
              isDark: isDark,
              onTap: () =>
                  ref.read(merchantSettlementsProvider.notifier).setTab('ongoing'),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              title: 'Validation',
              badgeCount: awaitingCount,
              badgeColor: const Color(0xFFF59E0B),
              isSelected: state.selectedTab == 'awaiting',
              isDark: isDark,
              onTap: () =>
                  ref.read(merchantSettlementsProvider.notifier).setTab('awaiting'),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              title: 'History',
              badgeCount: 0,
              badgeColor: Colors.transparent,
              isSelected: state.selectedTab == 'history',
              isDark: isDark,
              onTap: () =>
                  ref.read(merchantSettlementsProvider.notifier).setTab('history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required int badgeCount,
    required Color badgeColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  Widget _buildFilterBar(BuildContext context, MerchantSettlementsState state, bool isDark) {
    final dcs = state.distributionCenters;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Horizontal DC Selector Chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDcChip(
                  label: 'All DCs',
                  isSelected: state.selectedDcId == 'all',
                  isDark: isDark,
                  onTap: () =>
                      ref.read(merchantSettlementsProvider.notifier).setDcFilter('all'),
                ),
                const SizedBox(width: 6),
                ...dcs.map((dc) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildDcChip(
                        label: dc.name,
                        isSelected: state.selectedDcId == dc.id,
                        isDark: isDark,
                        onTap: () => ref
                            .read(merchantSettlementsProvider.notifier)
                            .setDcFilter(dc.id),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (val) =>
                  ref.read(merchantSettlementsProvider.notifier).setSearchQuery(val),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search settlements, refs...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDcChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF37021)
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingSliverList(
    BuildContext context,
    MerchantSettlementsState state,
    List<LiveOngoingSettlement> list,
    bool isDark,
  ) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: NovaEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Zero Activity',
            message:
                'No pending order remittances building today. Live count increments automatically as couriers complete drops.',
            actionLabel: 'Refresh',
            onAction: _onRefresh,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = list[index];
            return _buildOngoingSettlementCard(context, item, isDark);
          },
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildOngoingSettlementCard(
    BuildContext context,
    LiveOngoingSettlement item,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            MerchantSettlementSheet.show(context: context, ongoingSettlement: item);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: DC Name + Pulse Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.apartment_rounded,
                                size: 16, color: Color(0xFFF37021)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.dcName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.dcState} • ${item.dcCode}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF37021),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Building',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF37021),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Middle: Financial Values
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Expected',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(item.expectedNetPayout),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Gross Remitted',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(item.grossRemitted),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bottom Specs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.deliveredCount} orders • ${item.productsSummary.length} products',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF37021),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 10, color: Color(0xFFF37021)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAwaitingSliverList(
    BuildContext context,
    MerchantSettlementsState state,
    List<ClientSettlement> list,
    bool isDark,
  ) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: NovaEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Queue Clear',
            message: 'No pending DC settlements currently awaiting your sign-off.',
            actionLabel: 'Refresh',
            onAction: _onRefresh,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = list[index];
            final dc = state.distributionCenters.firstWhere(
              (d) => d.id == item.distributionCenterId,
              orElse: () => DistributionCenter(
                id: item.distributionCenterId ?? 'dc-cmd-01',
                name: 'Distribution Center',
                code: 'DC-HUB',
                state: 'Nigeria',
                city: 'Central',
                address: '',
              ),
            );
            return _buildAwaitingSettlementCard(context, item, dc, isDark);
          },
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildAwaitingSettlementCard(
    BuildContext context,
    ClientSettlement item,
    DistributionCenter dc,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            MerchantSettlementSheet.show(
              context: context,
              settlement: item,
              dc: dc,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.settlementNumber,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${dc.name} (${dc.code})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              size: 11, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'Action Required',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Payout',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.netPayoutAmount),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        MerchantSettlementSheet.show(
                          context: context,
                          settlement: item,
                          dc: dc,
                        );
                      },
                      child: Text(
                        'Review & Sign',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySliverList(
    BuildContext context,
    MerchantSettlementsState state,
    List<ClientSettlement> list,
    bool isDark,
  ) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: NovaEmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: 'No History',
            message: 'Cleared historical settlements will be indexed and accessible here.',
            actionLabel: 'Refresh',
            onAction: _onRefresh,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = list[index];
            final dc = state.distributionCenters.firstWhere(
              (d) => d.id == item.distributionCenterId,
              orElse: () => DistributionCenter(
                id: item.distributionCenterId ?? 'dc-cmd-01',
                name: 'Distribution Center',
                code: 'DC-HUB',
                state: 'Nigeria',
                city: 'Central',
                address: '',
              ),
            );
            return _buildClearedSettlementCard(context, item, dc, isDark);
          },
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildClearedSettlementCard(
    BuildContext context,
    ClientSettlement item,
    DistributionCenter dc,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            MerchantSettlementSheet.show(context: context, settlement: item, dc: dc);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded,
                                    size: 11, color: Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  'CLEARED',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.settlementNumber,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dc.name} • ${shortDateFormat.format(item.settledAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(item.netPayoutAmount),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      '${item.totalOrdersCount} drops',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: INCOME & SETTLEMENT BREAKDOWN VIEW
  // =========================================================================
  Widget _buildIncomeTab(BuildContext context, bool isDark) {
    final portalState = ref.watch(clientPortalProvider);
    final allOrders = portalState.orders;

    // Financial Metrics
    final deliveredOrders =
        allOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final failedOrders = allOrders
        .where((o) =>
            o.status.toLowerCase() == 'failed' ||
            (o.failureReason != null && o.failureReason!.isNotEmpty))
        .toList();

    final deliveredCount = deliveredOrders.length;
    final deliveredValue = deliveredOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final failedCount = failedOrders.length;
    final failedValue = failedCount * 1500.0; // standard failed attempt tariff
    final riderCommissions = deliveredOrders.fold(0.0, (acc, o) => acc + o.agentEntitlement);
    final logisticsTariff = deliveredOrders.fold(
        0.0, (acc, o) => acc + (o.clientDeliveryFee > 0 ? o.clientDeliveryFee : 3500.0));
    final netSettlement = deliveredValue - logisticsTariff - riderCommissions;

    // Filtered Orders for the ledger
    final filteredOrders = allOrders.where((o) {
      if (_incomeFilter == 'delivered' && o.status.toLowerCase() != 'delivered') {
        return false;
      }
      if (_incomeFilter == 'failed' &&
          o.status.toLowerCase() != 'failed' &&
          (o.failureReason == null || o.failureReason!.isEmpty)) {
        return false;
      }
      if (_incomeFilter == 'pending' &&
          (o.status.toLowerCase() == 'delivered' || o.status.toLowerCase() == 'failed')) {
        return false;
      }
      final q = incomeSearchController.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        final matchNum = o.orderNumber.toLowerCase().contains(q);
        final matchCust = o.customerName.toLowerCase().contains(q);
        final matchProd = o.productName.toLowerCase().contains(q);
        final matchHub = (o.distributionCenterName ?? '').toLowerCase().contains(q);
        if (!matchNum && !matchCust && !matchProd && !matchHub) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _onRefresh(),
      color: const Color(0xFFF37021),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Income KPI Cards (2x2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Delivered ($deliveredCount)',
                          value: currencyFormat.format(deliveredValue),
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF10B981),
                          bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          tooltip: 'Total successfully delivered COD value',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Failed Drops ($failedCount)',
                          value: currencyFormat.format(failedValue),
                          icon: Icons.cancel_rounded,
                          iconColor: const Color(0xFFEF4444),
                          bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          tooltip: 'Failed delivery attempts & associated tariffs',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Net Settlement',
                          value: currencyFormat.format(netSettlement > 0 ? netSettlement : 0.0),
                          icon: Icons.account_balance_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          bgColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          tooltip: 'Net accrued funds ready for DC disbursement',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Comms & Fees',
                          value: currencyFormat.format(logisticsTariff + riderCommissions),
                          icon: Icons.local_shipping_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          tooltip: 'Logistics flat tariffs and rider commissions deducted',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filter Pills & Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildIncomeFilterChip('All', 'all', isDark),
                      const SizedBox(width: 6),
                      _buildIncomeFilterChip('Delivered', 'delivered', isDark),
                      const SizedBox(width: 6),
                      _buildIncomeFilterChip('Failed', 'failed', isDark),
                      const SizedBox(width: 6),
                      _buildIncomeFilterChip('Pending', 'pending', isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                      ),
                    ),
                    child: TextField(
                      controller: incomeSearchController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search order #, product, or DC...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Orders List
          if (filteredOrders.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: NovaEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Orders Found',
                  message: 'No orders match the selected filters or search query.',
                  actionLabel: 'Reset',
                  onAction: () {
                    setState(() {
                      _incomeFilter = 'all';
                      incomeSearchController.clear();
                    });
                  },
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final o = filteredOrders[index];
                    return _buildIncomeOrderCard(context, o, isDark);
                  },
                  childCount: filteredOrders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomeFilterChip(String label, String value, bool isDark) {
    final isSelected = _incomeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _incomeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF37021)
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeOrderCard(BuildContext context, OrderEntity o, bool isDark) {
    final isDelivered = o.status.toLowerCase() == 'delivered';
    final isFailed = o.status.toLowerCase() == 'failed' || (o.failureReason != null && o.failureReason!.isNotEmpty);

    Color badgeColor;
    String statusLabel;
    if (isDelivered) {
      badgeColor = const Color(0xFF10B981);
      statusLabel = 'Delivered';
    } else if (isFailed) {
      badgeColor = const Color(0xFFEF4444);
      statusLabel = 'Failed';
    } else {
      badgeColor = const Color(0xFF3B82F6);
      statusLabel = 'In Transit';
    }

    final tariff = o.clientDeliveryFee > 0 ? o.clientDeliveryFee : 3500.0;
    final riderComm = o.agentEntitlement;
    final netAmount = isDelivered ? (o.totalAmount - tariff - riderComm) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                o.orderNumber,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${o.productName} • ${o.distributionCenterName ?? "Central DC"}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                currencyFormat.format(o.totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tariff: -₦${tariff.toInt()} • Comm: -₦${riderComm.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                'Net: ${currencyFormat.format(netAmount)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: EXPENSES VIEW
  // =========================================================================
  Widget _buildExpensesTab(
    BuildContext context,
    MerchantSettlementsState state,
    bool isDark,
  ) {
    final totalExpenses = _expenditures.fold(0.0, (acc, e) => acc + e.amount);

    final filteredExpenses = _expenditures.where((e) {
      if (_selectedExpenseCategory == 'all') return true;
      return e.category.name.toLowerCase() == _selectedExpenseCategory.toLowerCase();
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _loadExpenses(),
      color: const Color(0xFFF37021),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Total Logged Expenses & Action
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Operating Costs',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalExpenses),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_expenditures.length} logged entries',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Log',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () async {
                        final created = await ClientAddExpenditureModal.show(
                          context,
                          clientId: state.clientProfile.id,
                        );
                        if (created != null) {
                          _loadExpenses();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Categories Selector
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  _buildExpenseCatChip('All', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildExpenseCatChip('Logistics', 'logistics', isDark),
                  const SizedBox(width: 6),
                  _buildExpenseCatChip('Packaging', 'packaging', isDark),
                  const SizedBox(width: 6),
                  _buildExpenseCatChip('Ads/Media', 'marketing', isDark),
                  const SizedBox(width: 6),
                  _buildExpenseCatChip('Office', 'office', isDark),
                  const SizedBox(width: 6),
                  _buildExpenseCatChip('Other', 'other', isDark),
                ],
              ),
            ),
          ),

          // Expenses List
          if (_isLoadingExpenses)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (filteredExpenses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: NovaEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No Expenses Recorded',
                  message: 'Keep track of operating costs, packaging, and ad spend by tapping "+ Log".',
                  actionLabel: '+ Log Expense',
                  onAction: () async {
                    final created = await ClientAddExpenditureModal.show(
                      context,
                      clientId: state.clientProfile.id,
                    );
                    if (created != null) {
                      _loadExpenses();
                    }
                  },
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final exp = filteredExpenses[index];
                    return _buildExpenseCard(context, exp, isDark);
                  },
                  childCount: filteredExpenses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseCatChip(String label, String value, bool isDark) {
    final isSelected = _selectedExpenseCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedExpenseCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEF4444)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF4444)
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, BusinessExpenditureEntity exp, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exp.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '-${currencyFormat.format(exp.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${exp.category.label} • ${shortDateFormat.format(exp.expenditureDate)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty)
                      const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF10B981)),
                  ],
                ),
                if (exp.description != null && exp.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exp.description!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: PROFILE & SECURITY (LAST ON RIGHT)
  // =========================================================================
  Widget _buildProfileTab(
    BuildContext context,
    MerchantSettlementsState state,
    bool isDark,
  ) {
    final user = ref.watch(authProvider).user;
    final client = state.clientProfile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        children: [
          // Identity Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user != null) {
                          EditProfileModal.show(context, user);
                        }
                      },
                      child: UserAvatarWidget(
                        avatarUrl: user?.avatarUrl,
                        fullName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Accountant',
                        radius: 28,
                        showBorder: true,
                        borderColor: const Color(0xFF0D9488),
                        borderWidth: 2,
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () {
                          if (user != null) {
                            EditProfileModal.show(context, user);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37021),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              user?.fullName.isNotEmpty == true ? user!.fullName : 'Samuel Accountant',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              if (user != null) {
                                EditProfileModal.show(context, user);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF0D9488)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Finance Accountant',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            user?.accountantCode ?? 'ACC-NOVA-001',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: user?.accountantCode ?? 'ACC-NOVA-001'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Staff code copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payout Bank Destination Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_rounded,
                                size: 16, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Payout Destination',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF10B981)),
                          const SizedBox(width: 3),
                          Text(
                            'Active Bank',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                _buildProfileDetailRow(
                    'Bank',
                    client.bankName.isNotEmpty ? client.bankName : 'Access Bank Plc',
                    Icons.account_balance_outlined,
                    isDark),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                    'Account #',
                    client.accountNumber.isNotEmpty ? client.accountNumber : '0123456789',
                    Icons.pin_outlined,
                    isDark),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                    'Account Name',
                    client.accountName.isNotEmpty ? client.accountName : client.companyName,
                    Icons.badge_outlined,
                    isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Merchant Scope Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enterprise Scope',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                _buildProfileDetailRow('Company', client.companyName, Icons.business_rounded, isDark),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                    'Email', user?.email ?? client.email, Icons.email_outlined, isDark),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                    'Phone', user?.phone ?? client.phone, Icons.phone_outlined, isDark),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                    'Coverage',
                    '${state.distributionCenters.length} Distribution Centers',
                    Icons.hub_outlined,
                    isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Settings & Actions
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                // Edit Profile & Photo Tile
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0D9488)),
                  ),
                  title: Text(
                    'Edit Profile & DP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Name, phone, photo & settlement bank',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                  onTap: () {
                    if (user != null) {
                      EditProfileModal.show(context, user);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),

                // Theme Switch Tile
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                  title: Text(
                    isDark ? 'Light Mode' : 'Dark Mode',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    activeColor: const Color(0xFFF37021),
                    onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),

                // Change Password Tile
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFFF37021)),
                  ),
                  title: Text(
                    'Change Password',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                  onTap: () => _showPasswordResetDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFFEF4444),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Sign Out of Console',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
