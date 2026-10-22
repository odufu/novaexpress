import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/widgets/dc_staff_profile_settings_tab.dart';
import '../../domain/entities/customer_lead.dart';
import '../../domain/entities/upg_request.dart';
import '../providers/client_portal_provider.dart';
import '../providers/sales_supervisor_provider.dart';
import '../widgets/client_convert_lead_modal.dart';
import '../widgets/supervisee_detail_modal.dart';

class MerchantSalesSupervisorPage extends ConsumerStatefulWidget {
  const MerchantSalesSupervisorPage({super.key});

  @override
  ConsumerState<MerchantSalesSupervisorPage> createState() =>
      _MerchantSalesSupervisorPageState();
}

class _MerchantSalesSupervisorPageState
    extends ConsumerState<MerchantSalesSupervisorPage> {
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  int _activeTab = 0; // 0: UPG Queue, 1: Leaderboard, 2: My Sales Desk, 3: Profile
  String _leadStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    final clientId = user?.clientId;
    ref.read(salesSupervisorProvider.notifier).loadSupervisorData(clientId: clientId);
    ref.read(clientPortalProvider.notifier).loadClientData();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final supervisorState = ref.watch(salesSupervisorProvider);
    final user = ref.watch(authProvider).user;
    final pendingUpgCount = supervisorState.pendingUpgRequests.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Rep Supervisor Console',
              style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${user?.clientCompanyName ?? "Merchant Hub"} • Telesales & UPG Operations',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFF37021),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Operations',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: const Color(0xFFF37021),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.5),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingUpgCount > 0,
                  label: Text('$pendingUpgCount'),
                  backgroundColor: const Color(0xFFF37021),
                  child: const Icon(Icons.verified_user_rounded),
                ),
                label: 'UPG Queue',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: supervisorState.closers.isNotEmpty,
                  label: Text('${supervisorState.closers.length}'),
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.leaderboard_rounded),
                ),
                label: 'Leaderboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.headset_mic_rounded),
                label: 'Sales Desk',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (_activeTab != 3)
                _buildKpiGrid(supervisorState, isDark),
              Expanded(
                child: _buildActiveTabBody(supervisorState, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RESPONSIVE 2x2 KPI GRID
  // ==========================================
  Widget _buildKpiGrid(SalesSupervisorState state, bool isDark) {
    final pendingCount = state.pendingUpgRequests.length;
    final approvedToday = state.approvedTodayCount;
    final totalUpsell = state.totalUpsellValueApproved;
    final activeSupervisees = state.closers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'PENDING UPG QUEUE',
                  value: '$pendingCount',
                  unit: 'Requests',
                  subtitle: 'Awaiting authorization',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF37021),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'APPROVED TODAY',
                  value: '$approvedToday',
                  unit: 'Upgrades',
                  subtitle: 'Authorized package UPGs',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'UPSELL VALUE',
                  value: _currency.format(totalUpsell),
                  unit: '',
                  subtitle: 'Incremental sales gain',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'ACTIVE SUPERVISEES',
                  value: '$activeSupervisees',
                  unit: 'Reps',
                  subtitle: 'In telesales team',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB ROUTER
  // ==========================================
  Widget _buildActiveTabBody(SalesSupervisorState state, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildUpgQueueTab(state, isDark);
      case 1:
        return _buildLeaderboardTab(state, isDark);
      case 2:
        return _buildMySalesDeskTab(state, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'Merchant Sales Supervisor',
          departmentLabel: 'TELESALES & UPG GOVERNANCE',
          accentColor: const Color(0xFFF37021),
          roleIcon: Icons.verified_user_rounded,
        );
      default:
        return _buildUpgQueueTab(state, isDark);
    }
  }

  // ==========================================
  // TAB 0: UPG APPROVAL QUEUE (PILLAR 3)
  // ==========================================
  Widget _buildUpgQueueTab(SalesSupervisorState state, bool isDark) {
    final requests = state.filteredUpgRequests;
    final user = ref.read(authProvider).user;
    final supervisorName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Sales Supervisor';

    return Column(
      children: [
        // Action Bar & Filter Pills (Zero Overflow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildUpgFilterPill('Pending (${state.pendingUpgRequests.length})', 'pending', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('Approved (${state.upgRequests.where((r) => r.isApproved).length})', 'approved', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('Rejected (${state.upgRequests.where((r) => r.isRejected).length})', 'rejected', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('All (${state.upgRequests.length})', 'all', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of UPG Requests
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      Text(
                        state.upgFilter == 'pending'
                            ? 'All UPG Requests Cleared! 🎉'
                            : 'No UPG requests matching filter.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.upgFilter == 'pending'
                            ? 'Upgrade requests submitted by sales reps will appear here.'
                            : 'Try switching to another filter tab above.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return _buildUpgRequestCard(req, supervisorName, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpgFilterPill(String title, String value, bool isDark) {
    final state = ref.watch(salesSupervisorProvider);
    final isSelected = state.upgFilter == value;

    return GestureDetector(
      onTap: () => ref.read(salesSupervisorProvider.notifier).setUpgFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildUpgRequestCard(UpgRequest req, String supervisorName, bool isDark) {
    final bool isPending = req.isPending;
    final bool isApproved = req.isApproved;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (isPending
                  ? const Color(0xFFF37021).withValues(alpha: 0.3)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isPending ? 1.2 : 1.0,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${req.orderNumber}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        req.customerName,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isApproved
                          ? const Color(0xFF10B981)
                          : (isPending ? const Color(0xFFF37021) : const Color(0xFFDC2626)))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  req.status.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isApproved
                        ? const Color(0xFF10B981)
                        : (isPending ? const Color(0xFFF37021) : const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.headset_mic_outlined, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Rep: ${req.closerName} (${req.closerCode}) • Phone: ${req.customerPhone}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comparison box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Original Order', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            '${req.originalProduct} (${req.originalQuantity}x)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currency.format(req.originalAmount),
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFF10B981)),
                              const SizedBox(width: 2),
                              Text('Proposed UPG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                            ],
                          ),
                          Text(
                            '${req.upgradedProduct} (${req.upgradedQuantity}x)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currency.format(req.upgradedAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          '+${_currency.format(req.upsellDelta)} (+${req.upsellPercentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (req.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Notes: "${req.reason}"',
                style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (isPending) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00522A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text(
                      'Approve UPG',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () async {
                      final res = await ref.read(salesSupervisorProvider.notifier).approveUpgRequest(
                        upgId: req.id,
                        supervisorName: supervisorName,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                          content: Text(res['message']?.toString() ?? 'UPG processed.'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                    onPressed: () => _showRejectPrompt(req, supervisorName),
                  ),
                ),
              ],
            ),
          ] else if (req.approvedBy != null) ...[
            Text(
              'Authorized by ${req.approvedBy} on ${DateFormat("dd MMM yyyy, hh:mm a").format(req.approvedAt ?? req.createdAt)}',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981)),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectPrompt(UpgRequest req, String supervisorName) {
    final reasonController = TextEditingController(text: 'Customer declined larger package upon review.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline UPG Request', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify reason for declining upgrade on #${req.orderNumber}:', style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(salesSupervisorProvider.notifier).rejectUpgRequest(
                upgId: req.id,
                reason: reasonController.text.trim(),
                supervisorName: supervisorName,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFDC2626),
                  content: Text(res['message']?.toString() ?? 'UPG request declined.'),
                ),
              );
            },
            child: const Text('Confirm Decline'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SUPERVISEES LEADERBOARD (PILLAR 2)
  // ==========================================
  Widget _buildLeaderboardTab(SalesSupervisorState state, bool isDark) {
    final ranked = state.rankedSupervisees;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rank Supervisees by:',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildSortPill('Orders Closed', 'orders', isDark),
                  const SizedBox(width: 6),
                  _buildSortPill('Revenue', 'revenue', isDark),
                  const SizedBox(width: 6),
                  _buildSortPill('Conversion %', 'conversion', isDark),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ranked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Supervisees Registered', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Closers attached to this merchant will appear in the leaderboard.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ranked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = ranked[index];
                    final rank = index + 1;
                    return _buildLeaderboardCard(item, rank, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSortPill(String title, String value, bool isDark) {
    final state = ref.watch(salesSupervisorProvider);
    final isSelected = state.leaderboardSort == value;

    return GestureDetector(
      onTap: () => ref.read(salesSupervisorProvider.notifier).setLeaderboardSort(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(SuperviseePerformance item, int rank, bool isDark) {
    final closer = item.closer;

    Color rankColor;
    String rankEmoji;
    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B);
      rankEmoji = '🥇 #1';
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
      rankEmoji = '🥈 #2';
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
      rankEmoji = '🥉 #3';
    } else {
      rankColor = const Color(0xFF64748B);
      rankEmoji = '#$rank';
    }

    return InkWell(
      onTap: () => SuperviseeDetailModal.show(context, performance: item, isDark: isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rank == 1
                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: rank == 1 ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                rankEmoji,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            UserAvatarWidget(fullName: closer.fullName, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          closer.fullName,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37021).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          closer.closerCode,
                          style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.totalOrders} Orders • ${_currency.format(item.totalRevenue)}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${item.conversionRate.toStringAsFixed(1)}% Conv',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap details →',
                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: MY SALES DESK (PILLAR 1: FULL CLOSER)
  // ==========================================
  Widget _buildMySalesDeskTab(SalesSupervisorState state, bool isDark) {
    final user = ref.read(authProvider).user;
    final leads = state.leads;

    List<CustomerLead> filteredLeads = leads;
    if (_leadStatusFilter != 'all') {
      filteredLeads = leads.where((l) => l.status.toLowerCase().contains(_leadStatusFilter)).toList();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLeadPill('All Leads (${leads.length})', 'all', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('New (${leads.where((l) => l.status.toLowerCase().contains("new")).length})', 'new', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('Confirmed (${leads.where((l) => l.status.toLowerCase().contains("confirmed")).length})', 'confirmed', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('Follow-up (${leads.where((l) => l.status.toLowerCase().contains("back") || l.status.toLowerCase().contains("follow")).length})', 'back', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredLeads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.headset_mic_outlined, size: 44, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('No customer leads matching filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredLeads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    return _buildLeadCard(lead, user?.fullName ?? 'Supervisor', user?.closerCode ?? 'SUP-01', isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeadPill(String title, String value, bool isDark) {
    final isSelected = _leadStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _leadStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCard(CustomerLead lead, String closerName, String closerCode, bool isDark) {
    final phone = lead.customerPhone;
    final bool isConfirmed = lead.status.toLowerCase().contains('confirmed') || lead.status.toLowerCase().contains('order');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lead.customerName,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isConfirmed ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lead.status.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isConfirmed ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${lead.productInterest} • ${lead.deliveryState.isNotEmpty ? lead.deliveryState : "Nigeria"}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 14),
                  label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 14),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/234${phone.replaceAll(RegExp(r"[^0-9]"), "")}')),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 14),
                label: const Text('Convert Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ClientConvertLeadModal(lead: lead),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
