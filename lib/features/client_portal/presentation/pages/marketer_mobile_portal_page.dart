import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import '../../../pipeline_chat/presentation/widgets/conversation_list_modal.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import '../../domain/entities/client_marketer.dart';
import '../../domain/entities/lead_form.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_add_package_modal.dart';
import '../widgets/client_edit_marketer_profile_modal.dart';
import '../widgets/client_form_builder_modal.dart';
import '../widgets/client_form_embed_modal.dart';
import '../widgets/client_marketer_detail_modal.dart';

final marketerActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0);
final marketerOrderSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final marketerSuperviseeFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final marketerSuperviseeSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class MarketerMobilePortalPage extends ConsumerStatefulWidget {
  const MarketerMobilePortalPage({super.key});

  @override
  ConsumerState<MarketerMobilePortalPage> createState() => _MarketerMobilePortalPageState();
}

class _MarketerMobilePortalPageState extends ConsumerState<MarketerMobilePortalPage> {
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ $label copied to clipboard!'),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to log out of the Digital Marketer Portal?', style: GoogleFonts.inter(fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final activeTab = ref.watch(marketerActiveTabProvider);
    final selectedSupervisee = ref.watch(marketerSuperviseeFilterProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // Filter marketer's own forms and orders
    final marketerId = authUser?.marketerId ?? authUser?.id ?? '';

    final myMarketer = state.marketers.where((m) =>
        m.id == marketerId ||
        (authUser?.id != null && m.userId == authUser!.id) ||
        (authUser?.email != null && m.email.toLowerCase() == authUser!.email.toLowerCase())).firstOrNull;

    final isSupervisor = myMarketer?.isSupervisor == true || (authUser?.isMarketerSupervisor == true);

    // Supervisees belonging to this marketer
    final supervisees = isSupervisor
        ? state.marketers.where((m) => m.supervisorId != null && myMarketer != null && m.supervisorId == myMarketer.id && m.id != myMarketer.id).toList()
        : <ClientMarketer>[];

    // Allowed marketer IDs according to supervisory hierarchy & filter
    final Set<String> activeMarketerIds;
    if (isSupervisor) {
      if (selectedSupervisee == 'all') {
        activeMarketerIds = {
          if (marketerId.isNotEmpty) marketerId,
          if (myMarketer != null) myMarketer.id,
          ...supervisees.map((s) => s.id),
        };
      } else if (selectedSupervisee == 'self') {
        activeMarketerIds = {
          if (marketerId.isNotEmpty) marketerId,
          if (myMarketer != null) myMarketer.id,
        };
      } else {
        activeMarketerIds = {selectedSupervisee};
      }
    } else {
      activeMarketerIds = {
        if (marketerId.isNotEmpty) marketerId,
        if (myMarketer != null) myMarketer.id,
      };
    }

    final avatarUrl = myMarketer?.avatarUrl ?? authUser?.avatarUrl;

    // Digital Marketer Lead Forms strictly scoped to active marketer IDs
    final myForms = state.leadForms.where((f) =>
        f.marketerId != null && activeMarketerIds.contains(f.marketerId)).toList();

    // Marketer's orders: Strictly those from forms or ad marketing attribution
    final myFormIds = myForms.map((f) => f.id).toSet();
    final myOrders = state.orders.where((o) {
      final isFromForm = o.formId != null && myFormIds.contains(o.formId);
      final isFromMarketer = o.marketerId != null && activeMarketerIds.contains(o.marketerId);
      return isFromForm || isFromMarketer;
    }).toList();

    // Calculate live performance
    int totalLeads = 0;
    int totalBooked = 0;
    int totalDelivered = 0;
    for (final f in myForms) {
      totalLeads += f.totalSubmissions;
      totalBooked += f.totalOrdersBooked;
      totalDelivered += f.totalOrdersDelivered;
    }

    final double convRate = totalLeads > 0 ? ((totalDelivered / totalLeads) * 100) : 0.0;
    final isPayPerSubmission = myMarketer?.commissionModel == 'per_form_submission';
    final double commissionRate = isPayPerSubmission
        ? (myMarketer?.effectiveCommissionPerSubmission ?? 500.0)
        : (myMarketer?.effectiveCommissionPerDelivery ?? 1000.0);
    final double calculatedCommission = isPayPerSubmission
        ? (totalBooked * commissionRate)
        : (totalDelivered * commissionRate);
    final double earnedCommission = (myMarketer != null && myMarketer.totalCommissionEarned > 0)
        ? myMarketer.totalCommissionEarned
        : calculatedCommission;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (myMarketer != null) {
                  ClientMarketerDetailModal.show(context, marketer: myMarketer, isSupervisorView: false);
                } else {
                  ClientEditMarketerProfileModal.show(context, marketer: myMarketer);
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatarWidget(
                    avatarUrl: avatarUrl,
                    fullName: authUser?.fullName ?? myMarketer?.fullName ?? 'Digital Marketer',
                    radius: 20,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF111827) : Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.analytics_rounded, size: 8, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () {
                  if (myMarketer != null) {
                    ClientMarketerDetailModal.show(context, marketer: myMarketer, isSupervisorView: false);
                  } else {
                    ClientEditMarketerProfileModal.show(context, marketer: myMarketer);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authUser?.fullName ?? myMarketer?.fullName ?? 'Digital Marketer',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSupervisor
                                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSupervisor) ...[
                                const Icon(Icons.shield_rounded, size: 10, color: Color(0xFF6366F1)),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                isSupervisor ? 'SUPERVISOR' : (authUser?.marketerCode ?? myMarketer?.marketerCode ?? 'MKT'),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSupervisor ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      state.clientProfile.companyName.isNotEmpty
                          ? state.clientProfile.companyName
                          : 'Tap to edit profile picture & bank details',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Order Pipeline Chat Button with Unread Badge
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(pipelineChatProvider.select((s) => s.totalUnreadCount));
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFF10B981),
                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
                ),
                tooltip: 'Order Pipeline Chats',
                onPressed: () => ConversationListModal.show(context),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => ConversationListModal.show(context),
        icon: const Icon(Icons.forum_rounded, size: 18),
        label: Text('Pipeline Chats', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: activeTab,
          onTap: (index) => ref.read(marketerActiveTabProvider.notifier).state = index,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment_rounded),
              label: isSupervisor ? 'Forms (${myForms.length})' : 'My Forms (${myForms.length})',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.local_shipping_outlined),
              activeIcon: const Icon(Icons.local_shipping_rounded),
              label: isSupervisor ? 'Team Orders (${myOrders.length})' : 'Orders (${myOrders.length})',
            ),
            if (isSupervisor)
              BottomNavigationBarItem(
                icon: const Icon(Icons.groups_outlined),
                activeIcon: const Icon(Icons.groups_rounded),
                label: 'Supervisees (${supervisees.length})',
              ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Earnings & Payouts',
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientPortalProvider.notifier).loadClientData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supervisor Team Filter Bar
              if (isSupervisor && supervisees.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTeamFilterChip('all', 'All Team (${supervisees.length + 1})', selectedSupervisee == 'all', isDark),
                      const SizedBox(width: 8),
                      _buildTeamFilterChip('self', 'My Direct Forms', selectedSupervisee == 'self', isDark),
                      ...supervisees.map((s) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildTeamFilterChip(s.id, s.fullName, selectedSupervisee == s.id, isDark),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Performance KPIs Header
              _buildPerformanceGrid(totalLeads, totalBooked, totalDelivered, convRate, earnedCommission, currencyFormatter, isDark),
              const SizedBox(height: 18),

              if (activeTab == 0) ...[
                // TAB 0: Lead Forms
                _buildFormsTab(myForms, marketerId, state, isSupervisor, isDark),
              ] else if (activeTab == 1) ...[
                // TAB 1: Orders Pipeline
                _buildOrdersTab(myOrders, state, isSupervisor, currencyFormatter, isDark),
              ] else if (isSupervisor && activeTab == 2) ...[
                // TAB 2: Supervised Media Buyers (Supervisor Only)
                _buildSuperviseesTab(supervisees, state, currencyFormatter, isDark),
              ] else ...[
                // TAB 3 (or TAB 2): Earnings & Payouts
                _buildEarningsTab(
                  myMarketer,
                  earnedCommission,
                  isPayPerSubmission ? totalBooked : totalDelivered,
                  isPayPerSubmission,
                  commissionRate,
                  currencyFormatter,
                  isDark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceGrid(
    int totalLeads,
    int totalBooked,
    int totalDelivered,
    double convRate,
    double earnedCommission,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatCard('Leads Ingested', '$totalLeads', Icons.touch_app_rounded, const Color(0xFF6366F1), cardWidth, isDark),
            _buildStatCard('Orders Booked', '$totalBooked', Icons.phone_callback_rounded, const Color(0xFFF59E0B), cardWidth, isDark),
            _buildStatCard('Orders Delivered', '$totalDelivered', Icons.verified_rounded, const Color(0xFF10B981), cardWidth, isDark),
            _buildStatCard('Conversion Rate', '${convRate.toStringAsFixed(1)}%', Icons.insights_rounded, const Color(0xFF0EA5E9), cardWidth, isDark),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildFormsTab(List<LeadForm> myForms, String marketerId, ClientPortalState state, bool isSupervisor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Campaign Lead Forms',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ClientAddPackageModal.show(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 14),
                  label: Text('Deals', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => ClientFormBuilderModal.show(context, initialMarketerId: marketerId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: Text('New Form', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (myForms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text('No forms created yet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Create a lead form for your Facebook / TikTok ad campaigns', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => ClientFormBuilderModal.show(context, initialMarketerId: marketerId),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text('Create Form', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myForms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final form = myForms[index];
              final origin = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'https://portal.novaexpress.ng';
              final directUrl = '$origin/#/f/${form.id}';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            form.title,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${form.totalSubmissions} Leads',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '📦 ${form.productName} • ${form.packages.length} Packages',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    if (isSupervisor && form.marketerId != null) ...[
                      Builder(builder: (context) {
                        final formMarketer = state.marketers.where((m) => m.id == form.marketerId).firstOrNull;
                        if (formMarketer == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: InkWell(
                            onTap: () => ClientMarketerDetailModal.show(context, marketer: formMarketer, isSupervisorView: true),
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_pin_circle_outlined, size: 13, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Text(
                                  'Attributed Media Buyer: ${formMarketer.fullName} >',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 10),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 14),
                            label: Text('Copy Link', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => _copyToClipboard(directUrl, 'Direct Checkout Link'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            icon: const Icon(Icons.code_rounded, size: 14, color: Colors.white),
                            label: Text('Get Embed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                            onPressed: () => ClientFormEmbedModal.show(context, form: form),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                          tooltip: 'Edit Form',
                          onPressed: () => ClientFormBuilderModal.show(context, existingForm: form, initialMarketerId: marketerId),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrdersTab(List<OrderEntity> orders, ClientPortalState state, bool isSupervisor, NumberFormat currencyFormatter, bool isDark) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text('No orders generated yet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('When customers fill your forms, orders appear here in real time', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attributed Orders Pipeline (${orders.length})',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final isDelivered = order.isDelivered;
            final isFailed = order.isFailed;

            Color statusColor = const Color(0xFFF59E0B);
            if (isDelivered) {
              statusColor = const Color(0xFF10B981);
            } else if (isFailed) {
              statusColor = const Color(0xFFEF4444);
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        child: Icon(
                          isDelivered ? Icons.check_circle_rounded : (isFailed ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                          color: statusColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  order.customerName,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 6),
                                Text('• #${order.orderNumber}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                              ],
                            ),
                            Text(
                              '${order.productName} • ${order.deliveryCity}, ${order.deliveryState}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            if (isSupervisor && order.marketerId != null) ...[
                              Builder(builder: (context) {
                                final orderMarketer = state.marketers.where((m) => m.id == order.marketerId).firstOrNull;
                                if (orderMarketer == null) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: InkWell(
                                    onTap: () => ClientMarketerDetailModal.show(context, marketer: orderMarketer, isSupervisorView: true),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin_circle_rounded, size: 11, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Media Buyer: ${orderMarketer.fullName} >',
                                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormatter.format(order.totalAmount), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text(order.status.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (order.packageDealName != null && order.packageDealName!.isNotEmpty)
                        Expanded(
                          child: Text(
                            '📦 ${order.packageDealName}${order.freeQuantity > 0 ? " (+${order.freeQuantity} FREE)" : ""}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            'Qty: ${order.quantity} unit(s)',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ),
                      InkWell(
                        onTap: () => OrderPipelineChatSheet.showForOrder(context, order),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'Order Chat',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeamFilterChip(String filterId, String label, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => ref.read(marketerSuperviseeFilterProvider.notifier).state = filterId,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filterId == 'all')
              Icon(Icons.groups_rounded, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B))
            else if (filterId == 'self')
              Icon(Icons.person_rounded, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B))
            else
              Icon(Icons.shield_outlined, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsTab(
    dynamic myMarketer,
    double earnedCommission,
    int qualifyingCount,
    bool isPayPerSubmission,
    double commissionRate,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    final bankName = myMarketer?.bankName?.toString() ?? '';
    final bankAccountNumber = myMarketer?.bankAccountNumber?.toString() ?? '';
    final bankAccountName = myMarketer?.bankAccountName?.toString() ?? '';
    final hasBankDetails = bankAccountNumber.isNotEmpty;

    return Column(
      children: [
        // Commission Balance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMMISSION & DISBURSEMENT LEDGER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Earned Commission Balance', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  Text(
                    currencyFormatter.format(earnedCommission),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Commission Model', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  Text(
                    isPayPerSubmission ? 'Pay-per-Form (Ads)' : 'Pay-per-Delivered-Order',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Unit Commission Rate', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  Text(
                    currencyFormatter.format(commissionRate),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isPayPerSubmission ? 'Booked Ad Leads Qualifying' : 'Delivered Orders Qualifying', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  Text(
                    '$qualifyingCount ${isPayPerSubmission ? "Leads" : "Orders"}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Commissions are disbursed automatically by the merchant to your designated bank account upon verification.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Marketer Profile & Payout Settlement Account Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PAYOUT SETTLEMENT ACCOUNT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 0.5)),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF10B981)),
                    tooltip: 'Edit Profile & Bank Details',
                    onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: myMarketer),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bank Name', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          hasBankDetails ? bankName : 'Not Set',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Account Number', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          hasBankDetails ? bankAccountNumber : 'Not Set',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Account Name', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          hasBankDetails ? bankAccountName : 'Not Set',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: myMarketer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.account_circle_outlined, size: 16),
                  label: Text('Edit Profile Picture & Bank Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION: Supervised Team & Media Buyers Tab
  // ===========================================================================
  Widget _buildSuperviseesTab(
    List<ClientMarketer> supervisees,
    ClientPortalState state,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    final searchQuery = ref.watch(marketerSuperviseeSearchProvider);
    final filteredSupervisees = supervisees.where((s) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.marketerCode.toLowerCase().contains(q);
    }).toList();

    // Aggregates
    double totalBudget = 0.0;
    int totalLeads = 0;
    int totalDelivered = 0;
    for (final s in supervisees) {
      totalBudget += s.dailyAdSpendBudget;
      totalLeads += s.totalLeadsGenerated;
      totalDelivered += s.totalOrdersDelivered;
    }
    final double teamConv = totalLeads > 0 ? ((totalDelivered / totalLeads) * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Description
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supervised Media Buyers (${supervisees.length})',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Audit subordinate media buyers, live campaign pacing, and delivery milestones.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Team Aggregate KPI Ribbon
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF1E293B)]
                  : [const Color(0xFFEEF2FF), Colors.white],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMicroStatItem('Team Budget', currencyFormatter.format(totalBudget), const Color(0xFF6366F1)),
              _buildMicroStatItem('Team Leads', '$totalLeads', const Color(0xFF0EA5E9)),
              _buildMicroStatItem('Delivered POD', '$totalDelivered', const Color(0xFF10B981)),
              _buildMicroStatItem('Team Conv %', '${teamConv.toStringAsFixed(1)}%', const Color(0xFFF59E0B)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar
        TextField(
          onChanged: (val) => ref.read(marketerSuperviseeSearchProvider.notifier).state = val,
          decoration: InputDecoration(
            hintText: 'Search supervisee by name, code or email...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF111827) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Supervisee List
        if (filteredSupervisees.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('No supervisees matching query', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSupervisees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sub = filteredSupervisees[index];
              final subConv = sub.totalLeadsGenerated > 0
                  ? ((sub.totalOrdersDelivered / sub.totalLeadsGenerated) * 100).toStringAsFixed(1)
                  : '0.0';

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ClientMarketerDetailModal.show(context, marketer: sub, isSupervisorView: true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Avatar, Name, Code, Budget
                        Row(
                          children: [
                            UserAvatarWidget(avatarUrl: sub.avatarUrl, fullName: sub.fullName, radius: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sub.fullName,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          sub.marketerCode,
                                          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${sub.email} • ${sub.phone}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${currencyFormatter.format(sub.dailyAdSpendBudget)}/day',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0EA5E9)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Row 2: 4 Micro KPI Badges
                        Row(
                          children: [
                            Expanded(child: _buildSubMicroChip('Leads', '${sub.totalLeadsGenerated}', isDark)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSubMicroChip('Booked', '${sub.totalOrdersGenerated}', isDark)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSubMicroChip('Delivered', '${sub.totalOrdersDelivered}', isDark, valueColor: const Color(0xFF10B981))),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSubMicroChip('Conv %', '$subConv%', isDark, valueColor: const Color(0xFFF59E0B))),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 3: Commissions & Action Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Commission Balance', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                Text(
                                  currencyFormatter.format(sub.totalCommissionEarned),
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.analytics_outlined, size: 14),
                              label: Text('Inspect Details >', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onPressed: () => ClientMarketerDetailModal.show(context, marketer: sub, isSupervisorView: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMicroStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildSubMicroChip(String label, String value, bool isDark, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
