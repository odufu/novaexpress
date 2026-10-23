import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/widgets/dc_staff_profile_settings_tab.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/smart_order_paste_modal.dart';
import '../../domain/entities/upg_request.dart';
import '../providers/client_portal_provider.dart';
import '../providers/sales_supervisor_provider.dart';
import '../widgets/client_create_order_modal.dart';
import '../widgets/client_order_tracking_modal.dart';
import '../widgets/request_upg_modal.dart';
import '../widgets/supervisee_detail_modal.dart';
import '../widgets/upg_detail_modal.dart';

class MerchantSalesSupervisorPage extends ConsumerStatefulWidget {
  const MerchantSalesSupervisorPage({super.key});

  @override
  ConsumerState<MerchantSalesSupervisorPage> createState() =>
      _MerchantSalesSupervisorPageState();
}

class _MerchantSalesSupervisorPageState
    extends ConsumerState<MerchantSalesSupervisorPage> {
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  int _activeTab = 0; // 0: UPG Queue, 1: Closers Leaderboard, 2: Orders Desk, 3: Profile
  String _orderStatusFilter = 'all';
  final TextEditingController _orderSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _orderSearchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    final clientId = user?.clientId;
    ref.read(salesSupervisorProvider.notifier).loadSupervisorData(clientId: clientId);
    ref.read(clientPortalProvider.notifier).loadClientData();
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
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
    final closersCount = supervisorState.closers.length;

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
              '${user?.clientCompanyName ?? "Novacare"} • Closers Team & UPG Approval',
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
                  isLabelVisible: closersCount > 0,
                  label: Text('$closersCount'),
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.leaderboard_rounded),
                ),
                label: 'Leaderboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.headset_mic_rounded),
                label: 'Orders Desk',
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
                  title: 'TOTAL UPSELL VALUE',
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
                  title: 'ACTIVE CLOSERS',
                  value: '$activeSupervisees',
                  unit: 'Reps',
                  subtitle: 'Telesales supervisees',
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
        return _buildOrdersDeskTab(state, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'Novacare Closers Supervisor',
          departmentLabel: 'TELESALES CLOSERS & UPG GOVERNANCE',
          accentColor: const Color(0xFFF37021),
          roleIcon: Icons.verified_user_rounded,
        );
      default:
        return _buildUpgQueueTab(state, isDark);
    }
  }

  // ==========================================
  // TAB 0: UPG APPROVAL QUEUE (NEWEST FIRST)
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
                      _buildUpgFilterPill('Declined (${state.upgRequests.where((r) => r.isRejected).length})', 'rejected', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('All Requests (${state.upgRequests.length})', 'all', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of UPG Requests (Newest at Top)
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
                            ? 'Package upgrade requests submitted by sales reps will appear here instantly.'
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
    final timeAgo = _formatTimeAgo(req.createdAt);

    return InkWell(
      onTap: () => UpgDetailModal.show(context, request: req, supervisorName: supervisorName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isApproved
                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                : (isPending
                    ? const Color(0xFFF37021).withValues(alpha: 0.35)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            width: isPending ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Requester (Closer) + Status Badge + Time Ago
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        child: const Icon(Icons.headset_mic_rounded, size: 13, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '${req.closerName} (${req.closerCode})',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeAgo,
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
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
              ],
            ),

            const SizedBox(height: 6),

            // Row 2: Order # + Customer Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${req.customerName} • ${req.customerPhone}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 3: Previous Package vs New Upgraded Package
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Previous
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PREVIOUS PACKAGE', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${req.originalProduct} (${req.originalQuantity}x)',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currency.format(req.originalAmount),
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFF37021)),
                  ),

                  // Upgraded
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEW UPGRADE', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${req.upgradedProduct} (${req.upgradedQuantity}x)',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currency.format(req.upgradedAmount),
                          style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Upsell Delta Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upsell Revenue Gain:',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                  ),
                  Text(
                    '+${_currency.format(req.upsellDelta)} (${req.upsellPercentage.toStringAsFixed(0)}%)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ),

            if (req.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${req.reason}"',
                style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            // Actions & Tap hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tap card for full audit & call details →',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
                if (isPending)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showRejectPrompt(req, supervisorName),
                        child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                              content: Text(res['message']?.toString() ?? 'UPG approved!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectPrompt(UpgRequest req, String supervisorName) {
    final reasonController = TextEditingController(text: 'Customer opted to maintain standard package.');
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
  // TAB 1: SUPERVISEES LEADERBOARD (CLOSERS)
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
                'Rank Closers by:',
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
                      Text('No Closers Registered', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Telesales closers attached to this merchant will appear in the leaderboard.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            // Rank badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rankEmoji,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Avatar
            UserAvatarWidget(
              avatarUrl: closer.avatarUrl,
              fullName: closer.fullName,
              radius: 18,
            ),
            const SizedBox(width: 10),

            // Info
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          closer.closerCode,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
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
  // TAB 2: ORDERS & TELESALES DESK (PILLAR 1: FULL CLOSER)
  // ==========================================
  Widget _buildOrdersDeskTab(SalesSupervisorState state, bool isDark) {
    final user = ref.read(authProvider).user;
    final allOrders = state.orders;

    List<OrderEntity> filteredOrders = allOrders;
    if (_orderStatusFilter != 'all') {
      filteredOrders = allOrders.where((o) => o.status.toLowerCase() == _orderStatusFilter.toLowerCase()).toList();
    }
    if (_orderSearchCtrl.text.trim().isNotEmpty) {
      final q = _orderSearchCtrl.text.trim().toLowerCase();
      filteredOrders = filteredOrders.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q) ||
          o.productName.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Action Bar: Create Order + Smart Paste
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _orderSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search orders, customer, phone...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => ClientCreateOrderModal.show(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => SmartOrderPasteModal.show(context),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Smart Paste', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),

        // Filter Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOrderFilterPill('All (${allOrders.length})', 'all', isDark),
                const SizedBox(width: 6),
                _buildOrderFilterPill('Booked (${allOrders.where((o) => o.status.toLowerCase() == "booked").length})', 'booked', isDark),
                const SizedBox(width: 6),
                _buildOrderFilterPill('In Transit (${allOrders.where((o) => o.status.toLowerCase() == "in_transit").length})', 'in_transit', isDark),
                const SizedBox(width: 6),
                _buildOrderFilterPill('Delivered (${allOrders.where((o) => o.status.toLowerCase() == "delivered").length})', 'delivered', isDark),
                const SizedBox(width: 6),
                _buildOrderFilterPill('Rescheduled (${allOrders.where((o) => o.status.toLowerCase() == "rescheduled").length})', 'rescheduled', isDark),
                const SizedBox(width: 6),
                _buildOrderFilterPill('Cancelled (${allOrders.where((o) => o.status.toLowerCase() == "cancelled").length})', 'cancelled', isDark),
              ],
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 44, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('No orders matching filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Tap "+ New" to book a new telesales order.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderDeskCard(order, user?.fullName ?? 'Supervisor', isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderFilterPill(String title, String value, bool isDark) {
    final isSelected = _orderStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _orderStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildOrderDeskCard(OrderEntity order, String supervisorName, bool isDark) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final hasUpg = order.upsellAmount > 0;

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${order.orderNumber}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ),
                  if (hasUpg) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'UPG (+${_currency.format(order.upsellAmount)})',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFFF37021)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDelivered ? const Color(0xFF10B981) : const Color(0xFFF37021),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.productName} • ${order.quantity} units',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                _currency.format(order.totalAmount),
                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (order.customerPhone.isNotEmpty)
                InkWell(
                  onTap: () => _makePhoneCall(order.customerPhone),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(order.customerPhone, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // UPG Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      RequestUpgModal.show(
                        context,
                        order: order,
                        closerId: 'sup-01',
                        closerName: supervisorName,
                        closerCode: 'SUP-01',
                        isSupervisor: true,
                      );
                    },
                    icon: const Icon(Icons.upgrade_rounded, size: 14),
                    label: const Text('UPG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  // Track Details Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => ClientOrderTrackingModal.show(context, order),
                    icon: const Icon(Icons.route_rounded, size: 14),
                    label: const Text('Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
