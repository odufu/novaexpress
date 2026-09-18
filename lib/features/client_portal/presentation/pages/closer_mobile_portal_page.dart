import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../users/presentation/widgets/edit_profile_modal.dart';
import '../../domain/entities/client_closer.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_convert_lead_modal.dart';
import '../widgets/client_create_order_modal.dart';
import '../widgets/client_order_tracking_modal.dart';
import '../widgets/closer_create_package_modal.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import '../../../pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';

final closerActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0);
final closerOrderStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final closerOrderSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final closerOrderScopeFilterProvider = StateProvider.autoDispose<String>((ref) => 'my_orders');

class CloserMobilePortalPage extends ConsumerStatefulWidget {
  const CloserMobilePortalPage({super.key});

  @override
  ConsumerState<CloserMobilePortalPage> createState() => _CloserMobilePortalPageState();
}

class _CloserMobilePortalPageState extends ConsumerState<CloserMobilePortalPage> {
  Future<void> _makePhoneCall(BuildContext context, String? phone, String recipientType) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text('⚠️ No phone number available for $recipientType'),
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Could not launch dialer for $cleanPhone: $e'),
          ),
        );
      }
    }
  }

  void _showPasswordResetDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
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
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: oldPassCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Enter current password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                ),
                const SizedBox(height: 14),
                Text('New Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Min 6 characters',
                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
                ),
                const SizedBox(height: 14),
                Text('Confirm New Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    prefixIcon: const Icon(Icons.check_circle_outline, size: 18),
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
                            backgroundColor: result['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            content: Text(result['message']?.toString() ?? result['error']?.toString() ?? 'Password updated!'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021)),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Update Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(closerActiveTabProvider);
    final portalState = ref.watch(clientPortalProvider);
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    // Identify current closer entity
    final currentCloser = portalState.closers.firstWhere(
      (c) => c.id == user?.closerId || c.email == user?.email,
      orElse: () => ClientCloser(
        id: user?.closerId ?? 'cls-${user?.id ?? "001"}',
        clientId: user?.clientId ?? portalState.clientProfile.id,
        closerCode: user?.closerCode ?? 'CLS-001',
        fullName: user?.fullName.trim().isNotEmpty == true ? user!.fullName : 'Sales Closer',
        email: user?.email ?? '',
        phone: user?.phone ?? '',
        avatarUrl: user?.avatarUrl,
        dailyCallTarget: 50,
      ),
    );

    return Scaffold(
      floatingActionButton: const PipelineChatFloatingActionButton(),
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      appBar: _buildCloserAppBar(context, currentCloser, user, isDark),
      body: IndexedStack(
        index: activeTab,
        children: [
          _buildDashboardTab(context, currentCloser, portalState, isDark),
          _buildOrdersTab(context, currentCloser, portalState, isDark),
          _buildProductsTab(context, portalState, isDark),
          _buildLeadsTab(context, currentCloser, portalState, isDark),
          _buildProfileTab(context, currentCloser, user, isDark),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeTab,
        onDestinationSelected: (idx) => ref.read(closerActiveTabProvider.notifier).state = idx,
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        indicatorColor: const Color(0xFFF37021).withValues(alpha: 0.15),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFFF37021)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded, color: Color(0xFFF37021)),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFFF37021)),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.headset_mic_outlined),
            selectedIcon: Icon(Icons.headset_mic_rounded, color: Color(0xFFF37021)),
            label: 'Leads',
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

  PreferredSizeWidget _buildCloserAppBar(
    BuildContext context,
    ClientCloser closer,
    dynamic user,
    bool isDark,
  ) {
    final effectiveAvatarUrl = user != null
        ? ((user.avatarUrl != null && user.avatarUrl.toString().trim().isNotEmpty) ? user.avatarUrl.toString().trim() : null)
        : (closer.avatarUrl?.trim().isNotEmpty == true ? closer.avatarUrl : null);
    final effectiveFullName = (user != null && user.fullName.toString().trim().isNotEmpty)
        ? user.fullName.toString().trim()
        : closer.fullName;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      elevation: 0.5,
      titleSpacing: 16,
      title: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (user != null) {
                EditProfileModal.show(context, user);
              }
            },
            child: Stack(
              children: [
                UserAvatarWidget(
                  fullName: effectiveFullName,
                  avatarUrl: effectiveAvatarUrl,
                  radius: 20,
                  backgroundColor: const Color(0xFFF37021),
                  textColor: Colors.white,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effectiveFullName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        closer.closerCode,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                      ),
                    ),
                    if (user?.clientCompanyName != null && user.clientCompanyName.toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          user.clientCompanyName.toString(),
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Toggle Theme',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 20,
            color: const Color(0xFF94A3B8),
          ),
          onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF94A3B8)),
          onPressed: () async {
            await ref.read(authProvider.notifier).checkCurrentUser();
            await ref.read(clientPortalProvider.notifier).loadClientData();
          },
        ),
      ],
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    ClientCloser closer,
    ClientPortalState state,
    bool isDark,
  ) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final metrics = state.getCloserPerformanceMetrics(closer.id, closer.email, closer.fullName);

    final totalBooked = (metrics['totalBooked'] as int?) ?? closer.totalOrdersBooked;
    final deliveredCount = (metrics['deliveredCount'] as int?) ?? closer.totalOrdersDelivered;
    final inTransitCount = (metrics['inTransitCount'] as int?) ?? 0;
    final successRate = (metrics['successRate'] as double?) ?? closer.deliverySuccessRate;
    final grossSales = (metrics['grossSales'] as double?) ?? 0.0;
    final earnedCommission = (metrics['earnedCommission'] as double?) ?? closer.totalEarnedCommission;

    final closerOrders = state.getOrdersForCloser(closer.id, closer.email, closer.fullName);
    final inTransitOrders = closerOrders.where((o) => o.isAssignedInTransit).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => ClientCreateOrderModal.show(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                    label: Text('Book Order', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => CloserCreatePackageModal.show(context),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFFF37021)),
                    label: Text('New Package', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFF37021))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFF37021)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Dial Leads',
                  onPressed: () => ref.read(closerActiveTabProvider.notifier).state = 3,
                  icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Performance KPI Grid
            Text(
              'My Sales & Closing Performance',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _buildKpiCard(
                  title: 'Orders Booked',
                  value: '$totalBooked',
                  subtitle: 'Telesales pipeline',
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  title: 'In Transit',
                  value: '$inTransitCount',
                  subtitle: 'With delivery riders',
                  icon: Icons.two_wheeler_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  title: 'Delivered',
                  value: '$deliveredCount',
                  subtitle: 'Success: ${successRate.toStringAsFixed(1)}%',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  title: 'Gross Closed',
                  value: currencyFormatter.format(grossSales),
                  subtitle: 'Realized revenue',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  title: 'Commissions',
                  value: currencyFormatter.format(earnedCommission),
                  subtitle: '₦${closer.commissionRate.toStringAsFixed(0)}/order',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  title: 'Daily Call Target',
                  value: '${closer.dailyCallTarget}',
                  subtitle: 'Calls per day',
                  icon: Icons.headset_mic_rounded,
                  color: const Color(0xFFF37021),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Live In-Transit Orders Stream
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live In-Transit Delivery Monitor (${inTransitOrders.length})',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                if (inTransitOrders.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(closerActiveTabProvider.notifier).state = 1,
                    child: Text('View All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFF37021))),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (inTransitOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No orders currently in transit.',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Book new orders to route them live to covering DCs.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: inTransitOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = inTransitOrders[index];
                  return _buildOrderCard(context, order, currencyFormatter, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab(
    BuildContext context,
    ClientCloser closer,
    ClientPortalState state,
    bool isDark,
  ) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final statusFilter = ref.watch(closerOrderStatusFilterProvider);
    final scopeFilter = ref.watch(closerOrderScopeFilterProvider);
    final searchQuery = ref.watch(closerOrderSearchProvider).trim().toLowerCase();

    final baseOrders = scopeFilter == 'all_novacare'
        ? state.orders
        : state.getOrdersForCloser(closer.id, closer.email, closer.fullName);

    final filtered = baseOrders.where((o) {
      if (statusFilter != 'all') {
        if (statusFilter == 'in_transit' && !o.isAssignedInTransit) return false;
        if (statusFilter == 'delivered' && !o.isDelivered) return false;
        if (statusFilter == 'pending' && (o.isDelivered || o.isFailed || o.isAssignedInTransit)) return false;
        if (statusFilter == 'failed' && !o.isFailed) return false;
      }
      if (searchQuery.isNotEmpty) {
        final matchesNum = o.orderNumber.toLowerCase().contains(searchQuery);
        final matchesCust = o.customerName.toLowerCase().contains(searchQuery);
        final matchesPhone = o.customerPhone.contains(searchQuery);
        final matchesProd = o.productName.toLowerCase().contains(searchQuery);
        if (!matchesNum && !matchesCust && !matchesPhone && !matchesProd) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Action Bar: Scope Selector + Book Order Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: isDark ? const Color(0xFF151D36) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildScopeButton('my_orders', 'My Orders', scopeFilter, isDark),
                    _buildScopeButton('all_novacare', 'Novacare All', scopeFilter, isDark),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => ClientCreateOrderModal.show(context),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Colors.white),
                label: Text(
                  '+ Book Order',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Filter & Search Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          color: isDark ? const Color(0xFF151D36) : Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (v) => ref.read(closerOrderSearchProvider.notifier).state = v,
                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search customer, phone, order #...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${baseOrders.length})', statusFilter, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('in_transit', 'In Transit (${baseOrders.where((o) => o.isAssignedInTransit).length})', statusFilter, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('delivered', 'Delivered (${baseOrders.where((o) => o.isDelivered).length})', statusFilter, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('pending', 'Pending Dispatch', statusFilter, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('failed', 'Failed/Callback', statusFilter, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Order List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text('No matching orders found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return _buildOrderCard(context, order, currencyFormatter, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderEntity order,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    Color statusColor;
    String statusLabel;

    if (order.isDelivered) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'DELIVERED';
    } else if (order.isAssignedInTransit) {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'IN TRANSIT';
    } else if (order.isFailed) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'FAILED / RETURN';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'PENDING DISPATCH';
    }

    final riderPhone = order.deliveryAgentPhone ?? '';
    final hasRider = order.deliveryAgentName != null && order.deliveryAgentName!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormatter.format(order.totalAmount),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),

          // Order Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Name & Phone
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.customerName} • ${order.customerPhone}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Delivery Address & LGA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.deliveryAddress}, ${order.deliveryCity} (${order.deliveryState})',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Product & Package Deal Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFFF37021)),
                          const SizedBox(width: 5),
                          Text(
                            '${order.productName} (x${order.quantity})',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    if (order.packageDealName != null && order.packageDealName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.packageDealName!,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (order.closerName != null && order.closerName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.closerAvatarUrl != null && order.closerAvatarUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              order.closerAvatarUrl!,
                              width: 16,
                              height: 16,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.headset_mic_rounded, size: 14, color: Color(0xFF7C3AED)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else ...[
                          const Icon(Icons.headset_mic_rounded, size: 14, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          'Created by: ${order.closerName}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hasRider) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 15, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Rider: ${order.deliveryAgentName} (${order.deliveryAgentCode ?? "PDA"})',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Strip with One-Tap Calling & Chat Followup Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // 1. One-Tap Call Customer
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(context, order.customerPhone, 'Customer (${order.customerName})'),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.white),
                    label: Text(
                      'Call Customer',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Order Chat & Live Followup (Strict Closer Scoping)
                Builder(
                  builder: (ctx) {
                    final authUser = ref.read(authProvider).user;
                    final closerId = authUser?.closerId ?? authUser?.id;
                    final closerName = authUser?.fullName.trim().toLowerCase() ?? '';
                    final isMyOrder = (order.closerId != null && (order.closerId == closerId || order.closerId == authUser?.id)) ||
                        (order.closerName != null && order.closerName!.trim().toLowerCase() == closerName);

                    return ElevatedButton.icon(
                      onPressed: isMyOrder
                          ? () {
                              OrderPipelineChatSheet.show(
                                context,
                                orderId: order.id,
                                orderNumber: order.orderNumber,
                                customerName: order.customerName,
                                customerPhone: order.customerPhone,
                              );
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('⛔ Access Restricted: Closers can only access chats for their own assigned orders.'),
                                ),
                              );
                            },
                      icon: Icon(isMyOrder ? Icons.forum_rounded : Icons.lock_outline_rounded, size: 13, color: Colors.white),
                      label: Text(
                        isMyOrder ? 'Chat' : 'Locked',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMyOrder ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // 3. One-Tap Call Rider
                if (hasRider) ...[
                  IconButton(
                    tooltip: 'Call Rider (${order.deliveryAgentName})',
                    onPressed: () => _makePhoneCall(
                      context,
                      riderPhone.isNotEmpty ? riderPhone : order.customerPhone,
                      'Rider (${order.deliveryAgentName})',
                    ),
                    icon: const Icon(Icons.two_wheeler_rounded, size: 18, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 4. Track Stages
                IconButton(
                  tooltip: 'Track Stages',
                  onPressed: () => ClientOrderTrackingModal.show(context, order),
                  icon: const Icon(Icons.route_rounded, size: 18, color: Color(0xFF64748B)),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
  ) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final catalogState = ref.watch(productCatalogProvider);
    final authState = ref.watch(authProvider);

    final effectiveClientId = state.clientProfile.id.isNotEmpty
        ? state.clientProfile.id
        : (authState.user?.clientId ?? '00000000-0000-4000-8000-789382731303');
    final effectiveCompanyName = state.clientProfile.companyName.isNotEmpty
        ? state.clientProfile.companyName
        : (authState.user?.clientCompanyName ?? 'Novacare Health & Wellness Ltd');

    final catalogMerchantProducts = catalogState.products.where((p) {
      return ClientPortalNotifier.isProductForClient(
        product: p,
        clientId: effectiveClientId,
        companyName: effectiveCompanyName,
      );
    }).toList();

    // Deduplicate merged products by SKU & ID
    final Set<String> seenKeys = {};
    final List<CatalogProduct> allProducts = [];
    for (final p in [...state.products, ...catalogMerchantProducts]) {
      final key = p.sku.trim().isNotEmpty ? p.sku.trim().toUpperCase() : p.id.trim();
      if (key.isNotEmpty && seenKeys.add(key)) {
        allProducts.add(p);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CloserCreatePackageModal.show(context),
        backgroundColor: const Color(0xFFF37021),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Package Deal', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(productCatalogProvider.notifier).reloadCatalog(),
            ref.read(clientPortalProvider.notifier).loadClientData(),
          ]);
        },
        child: allProducts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text('No client products available.', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: allProducts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final prod = allProducts[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D36) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProductImageWidget(
                              imageUrl: prod.imageUrl,
                              width: 48,
                              height: 48,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'SKU: ${prod.sku} • Base: ${currencyFormatter.format(prod.defaultUnitPrice)}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => CloserCreatePackageModal.show(context, product: prod),
                              icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFF37021)),
                              label: Text('Add Deal', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                side: const BorderSide(color: Color(0xFFF37021)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stock Counters
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStockPill('Warehouse Stock', '${prod.totalStockAcrossHubs} units', const Color(0xFF10B981)),
                              _buildStockPill('Packages Available', '${prod.packages.length} bundles', const Color(0xFF3B82F6)),
                            ],
                          ),
                        ),

                        // Packages list
                        if (prod.packages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Commercial Bundle Deals:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          ...prod.packages.map((pkg) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.card_giftcard_rounded, size: 14, color: Color(0xFFF37021)),
                                      const SizedBox(width: 6),
                                      Text(
                                        pkg.packageName,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    currencyFormatter.format(pkg.packagePrice),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLeadsTab(
    BuildContext context,
    ClientCloser closer,
    ClientPortalState state,
    bool isDark,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: state.leads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text('No customer leads assigned.', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lead = state.leads[index];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D36) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lead.customerName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(lead.status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${lead.customerPhone} • ${lead.deliveryLga}, ${lead.deliveryState}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      Text('Product: ${lead.productInterest} (${lead.packageInterest})', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(context, lead.customerPhone, lead.customerName),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.white),
                              label: Text('Dial Lead', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => ClientConvertLeadModal(lead: lead),
                                );
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFFF37021)),
                              label: Text('Convert to Order', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFF37021)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildProfileTab(
    BuildContext context,
    ClientCloser closer,
    dynamic user,
    bool isDark,
  ) {
    final effectiveAvatarUrl = user != null
        ? ((user.avatarUrl != null && user.avatarUrl.toString().trim().isNotEmpty) ? user.avatarUrl.toString().trim() : null)
        : (closer.avatarUrl?.trim().isNotEmpty == true ? closer.avatarUrl : null);
    final effectiveFullName = (user != null && user.fullName.toString().trim().isNotEmpty)
        ? user.fullName.toString().trim()
        : closer.fullName;
    final effectiveEmail = (user != null && user.email.toString().trim().isNotEmpty)
        ? user.email.toString().trim()
        : closer.email;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    UserAvatarWidget(
                      fullName: effectiveFullName,
                      avatarUrl: effectiveAvatarUrl,
                      radius: 40,
                      backgroundColor: const Color(0xFFF37021),
                      textColor: Colors.white,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          if (user != null) {
                            EditProfileModal.show(context, user);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF37021),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  effectiveFullName,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  effectiveEmail,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Telesales Closer • ${closer.closerCode}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Menu
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFFF37021)),
                  title: Text('Edit Profile & DP', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('Update name, phone and profile photo', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    if (user != null) {
                      EditProfileModal.show(context, user);
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF3B82F6)),
                  title: Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('Update your login credentials', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPasswordResetDialog(context),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded, color: Color(0xFFF59E0B)),
                  title: Text('Dark / Light Theme', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(isDark ? 'Dark Mode Active' : 'Light Mode Active', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  trailing: Switch(
                    value: isDark,
                    activeColor: const Color(0xFFF37021),
                    onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out of your closer desk?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(authProvider.notifier).logout();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, String currentKey, bool isDark) {
    final isSelected = key == currentKey;
    return GestureDetector(
      onTap: () => ref.read(closerOrderStatusFilterProvider.notifier).state = key,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildStockPill(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildScopeButton(String key, String label, String currentScope, bool isDark) {
    final isSelected = key == currentScope;
    return InkWell(
      onTap: () => ref.read(closerOrderScopeFilterProvider.notifier).state = key,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
