import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import 'client_order_tracking_modal.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/customer_lead.dart';
import '../providers/client_portal_provider.dart';
import 'client_convert_lead_modal.dart';

class ClientCloserDetailModal extends ConsumerStatefulWidget {
  final ClientCloser closer;

  const ClientCloserDetailModal({
    super.key,
    required this.closer,
  });

  static Future<void> show(BuildContext context, {required ClientCloser closer}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientCloserDetailModal(closer: closer),
    );
  }

  @override
  ConsumerState<ClientCloserDetailModal> createState() => _ClientCloserDetailModalState();
}

class _ClientCloserDetailModalState extends ConsumerState<ClientCloserDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClientCloser _currentCloser;
  String _orderSearchQuery = '';
  String _leadSearchQuery = '';
  String _selectedLeadFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentCloser = widget.closer;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPasswordResetDialog() {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isObscured = true;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Employee Password',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      _currentCloser.fullName,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set a new portal password for ${_currentCloser.email}. The employee will use this password to access the Closer Workspace.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: isObscured,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setDialogState(() => isObscured = !isObscured),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: isObscured,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                  validator: (v) => v != passwordCtrl.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF37021),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newPass = passwordCtrl.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();

                try {
                  await ref.read(clientPortalProvider.notifier).resetCloserPassword(
                    closerId: _currentCloser.id,
                    newPassword: newPass,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Password for ${_currentCloser.fullName} updated successfully!',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Failed to reset password: $e')),
                    );
                  }
                }
              },
              child: Text('Update Password', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentCloser.fullName);
    final phoneCtrl = TextEditingController(text: _currentCloser.phone);
    final emailCtrl = TextEditingController(text: _currentCloser.email);
    final commCtrl = TextEditingController(text: _currentCloser.commissionRate.toStringAsFixed(0));
    final targetCtrl = TextEditingController(text: _currentCloser.dailyCallTarget.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Employee Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded, size: 18)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, size: 18)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: commCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Commission (₦/order)', prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                        validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid amount' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Daily Call Target', prefixIcon: Icon(Icons.phone_callback_rounded, size: 18)),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid target' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF37021),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();

              try {
                final updated = await ref.read(clientPortalProvider.notifier).updateCloserDetails(
                  closerId: _currentCloser.id,
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  commissionRate: double.tryParse(commCtrl.text.trim()) ?? _currentCloser.commissionRate,
                  dailyCallTarget: int.tryParse(targetCtrl.text.trim()) ?? _currentCloser.dailyCallTarget,
                );

                setState(() => _currentCloser = updated);

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Employee profile updated for ${updated.fullName}!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Update failed: $e')),
                  );
                }
              }
            },
            child: Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _toggleEmployeeStatus() async {
    final nextStatus = !_currentCloser.isActive;
    final actionName = nextStatus ? 'Activate' : 'Deactivate';
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionName Employee Access?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          nextStatus
              ? 'Are you sure you want to activate ${_currentCloser.fullName}? They will regain access to call customer leads and book live dispatch orders.'
              : 'Are you sure you want to deactivate ${_currentCloser.fullName}? They will immediately lose access to the Closer Workspace.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionName, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(clientPortalProvider.notifier).toggleCloserStatus(_currentCloser.id, nextStatus);
      setState(() {
        _currentCloser = _currentCloser.copyWith(isActive: nextStatus);
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: nextStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            content: Text('${_currentCloser.fullName} is now ${nextStatus ? "Active" : "Deactivated"}.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // Filter closer's specific orders
    final closerOrders = state.orders.where((o) {
      final code = _currentCloser.closerCode.toLowerCase();
      final id = _currentCloser.id.toLowerCase();
      final name = _currentCloser.fullName.toLowerCase();

      final matchesCloser = (o.closerCode?.toLowerCase() == code) ||
          (o.closerId?.toLowerCase() == id) ||
          (o.closerName?.toLowerCase() == name) ||
          (o.deliveryNotes?.toLowerCase().contains(code) == true);

      if (!matchesCloser) return false;

      if (_orderSearchQuery.isEmpty) return true;
      final query = _orderSearchQuery.toLowerCase();
      return o.orderNumber.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.productName.toLowerCase().contains(query) ||
          o.deliveryCity.toLowerCase().contains(query);
    }).toList();

    // Filter closer's specific leads
    final closerLeads = state.leads.where((l) {
      final id = _currentCloser.id.toLowerCase();
      final name = _currentCloser.fullName.toLowerCase();

      final matchesCloser = (l.assignedCloserId?.toLowerCase() == id) ||
          (l.assignedCloserName?.toLowerCase() == name);

      if (!matchesCloser) return false;

      if (_selectedLeadFilter != 'all' && l.status != _selectedLeadFilter) {
        return false;
      }

      if (_leadSearchQuery.isEmpty) return true;
      final query = _leadSearchQuery.toLowerCase();
      return l.customerName.toLowerCase().contains(query) ||
          l.customerPhone.toLowerCase().contains(query) ||
          l.deliveryLga.toLowerCase().contains(query) ||
          l.productInterest.toLowerCase().contains(query);
    }).toList();

    // Calculate real-time totals
    final totalRevenue = closerOrders.where((o) => o.isDelivered).fold(0.0, (sum, o) => sum + o.totalAmount);
    final totalCommissionEarned = closerOrders.where((o) => o.isDelivered).length * _currentCloser.commissionRate;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1050,
        height: 820,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
          maxWidth: 1050,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151D36) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Profile Header & Management Actions
            _buildModalHeader(context, isDark),

            // 2. Performance KPI Ribbon (6 Metrics)
            _buildKpiRibbon(
              isDark,
              currencyFormatter,
              totalRevenue,
              totalCommissionEarned,
              closerOrders.length,
              closerLeads.length,
            ),

            // 3. Tab Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFF37021),
                indicatorWeight: 3,
                labelColor: const Color(0xFFF37021),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Closed Orders (${closerOrders.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Assigned Leads (${closerLeads.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Profile & Territory'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Commissions & Performance'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Orders List (Tap to open ClientOrderTrackingModal)
                  _buildOrdersTab(closerOrders, isDark, currencyFormatter),

                  // Tab 2: Leads Pipeline
                  _buildLeadsTab(closerLeads, isDark),

                  // Tab 3: Employee Details & Territory
                  _buildProfileDetailsTab(isDark, currencyFormatter),

                  // Tab 4: Performance & Commissions
                  _buildAnalyticsTab(closerOrders, isDark, currencyFormatter, totalCommissionEarned),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          final profileInfo = Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF37021), Color(0xFFFF9554)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF37021).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _currentCloser.fullName.isNotEmpty
                          ? _currentCloser.fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
                          : 'CL',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _currentCloser.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                      children: [
                        Flexible(
                          child: Text(
                            _currentCloser.fullName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37021).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentCloser.closerCode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF37021),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_currentCloser.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentCloser.isActive ? 'ACTIVE EMPLOYEE' : 'SUSPENDED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _currentCloser.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_currentCloser.email} • ${_currentCloser.phone}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Profile
              IconButton(
                tooltip: 'Edit Employee Profile',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: _showEditProfileDialog,
              ),
              const SizedBox(width: 8),

              // Reset Password
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showPasswordResetDialog,
                icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFFF37021)),
                label: Text(
                  'Reset Password',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),

              // Activate / Deactivate
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentCloser.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _toggleEmployeeStatus,
                icon: Icon(
                  _currentCloser.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  _currentCloser.isActive ? 'Deactivate' : 'Activate',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Close Modal
              IconButton(
                tooltip: 'Close Modal',
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );

          return isWide
              ? Row(
                  children: [
                    Expanded(child: profileInfo),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileInfo,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildKpiRibbon(
    bool isDark,
    NumberFormat currencyFormatter,
    double totalRevenue,
    double totalCommission,
    int totalOrders,
    int totalLeads,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 750;
          final crossCount = isWide ? 6 : 3;

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 8,
            childAspectRatio: isWide ? 2.1 : 1.9,
            children: [
              _buildKpiCard(
                title: 'Leads Assigned',
                value: '${_currentCloser.totalLeadsAssigned}',
                icon: Icons.contacts_outlined,
                iconColor: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              _buildKpiCard(
                title: 'Orders Booked',
                value: '${_currentCloser.totalOrdersBooked}',
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFF37021),
                isDark: isDark,
              ),
              _buildKpiCard(
                title: 'Conversion Rate',
                value: '${_currentCloser.conversionRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF10B981),
                isDark: isDark,
              ),
              _buildKpiCard(
                title: 'Delivered (POD)',
                value: '${_currentCloser.totalOrdersDelivered}',
                icon: Icons.verified_outlined,
                iconColor: const Color(0xFF059669),
                isDark: isDark,
              ),
              _buildKpiCard(
                title: 'Commission Earned',
                value: currencyFormatter.format(totalCommission),
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
              _buildKpiCard(
                title: 'Revenue Generated',
                value: currencyFormatter.format(totalRevenue),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFEC4899),
                isDark: isDark,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ORDERS LIST (TAP OPENS ClientOrderTrackingModal)
  // ==========================================
  Widget _buildOrdersTab(List<OrderEntity> orders, bool isDark, NumberFormat currencyFormatter) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter & Search bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _orderSearchQuery = v),
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by Order #, Customer Name, City...',
                      hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${orders.length} Orders Converted',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Orders List
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          'No closed orders matching search.',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(order, isDark, currencyFormatter);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order, bool isDark, NumberFormat currencyFormatter) {
    Color statusColor;
    String statusLabel;
    switch (order.status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'DELIVERED';
        break;
      case 'in_transit':
      case 'out_for_delivery':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'IN TRANSIT';
        break;
      case 'assigned':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'ASSIGNED TO RIDER';
        break;
      case 'failed':
      case 'cancelled':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'CANCELLED';
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusLabel = 'PENDING DISPATCH';
    }

    return InkWell(
      onTap: () => ClientOrderTrackingModal.show(context, order),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_shipping_outlined, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Order Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
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
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.customerName} (${order.customerPhone}) • ${order.deliveryCity}, ${order.deliveryState}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.productName} (${order.packageDealName ?? "${order.quantity} Units"}) • Assigned: ${order.deliveryAgentName ?? "DC Dispatch Hub"}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF37021),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Amount & View CTA
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(order.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Order',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF37021),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFF37021)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: LEADS PIPELINE
  // ==========================================
  Widget _buildLeadsTab(List<CustomerLead> leads, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter Chips & Search Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _leadSearchQuery = v),
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search customer name, phone, product...',
                      hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedLeadFilter,
                dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Leads')),
                  DropdownMenuItem(value: 'new_lead', child: Text('New Leads')),
                  DropdownMenuItem(value: 'calling', child: Text('In Progress')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'order_created', child: Text('Order Created')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedLeadFilter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Leads List
          Expanded(
            child: leads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_missed_rounded, size: 40, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text('No leads found for this employee.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: leads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lead = leads[index];
                      return _buildLeadItemCard(lead, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadItemCard(CustomerLead lead, bool isDark) {
    Color statusColor;
    String statusLabel;
    switch (lead.status) {
      case 'new_lead':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'NEW LEAD';
        break;
      case 'calling':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'IN CALLING';
        break;
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'CONFIRMED';
        break;
      case 'order_created':
        statusColor = const Color(0xFF059669);
        statusLabel = 'ORDER CREATED';
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusLabel = lead.status.toUpperCase();
    }

    final catalog = ref.watch(productCatalogProvider);
    final matchedProduct = catalog.findProductByName(lead.productInterest);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.customerName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${lead.customerPhone} • ${lead.deliveryLga}, ${lead.deliveryState}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Product ribbon & Action buttons
          Row(
            children: [
              ProductImageWidget(imageUrl: matchedProduct?.imageUrl, width: 22, height: 22, borderRadius: 4),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${lead.productInterest} (${lead.packageInterest})',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Call
              IconButton(
                icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF2563EB)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final uri = Uri.parse('tel:${lead.customerPhone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const SizedBox(width: 12),

              // WhatsApp
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF10B981)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final clean = lead.customerPhone.replaceAll(RegExp(r'[^\d]'), '');
                  final phone = clean.startsWith('0') ? '234${clean.substring(1)}' : clean;
                  final uri = Uri.parse('https://wa.me/$phone');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(width: 12),

              // Convert Lead
              if (lead.status != 'order_created')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ClientConvertLeadModal(lead: lead),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 12),
                  label: Text('Convert', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: EMPLOYEE PROFILE & TERRITORY
  // ==========================================
  Widget _buildProfileDetailsTab(bool isDark, NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EMPLOYEE & AUTHENTICATION DETAILS',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Full Legal Name', _currentCloser.fullName, isDark),
                _buildDivider(isDark),
                _buildDetailRow('Closer ID / Unique Code', _currentCloser.closerCode, isDark),
                _buildDivider(isDark),
                _buildDetailRow('Login Email Address', _currentCloser.email, isDark),
                _buildDivider(isDark),
                _buildDetailRow('Direct Phone Number', _currentCloser.phone, isDark),
                _buildDivider(isDark),
                _buildDetailRow('Assigned Company', 'Novacare Limited (Enterprise Client)', isDark),
                _buildDivider(isDark),
                _buildDetailRow('Commission per Converted Order', currencyFormatter.format(_currentCloser.commissionRate), isDark),
                _buildDivider(isDark),
                _buildDetailRow('Daily Outbound Call Target', '${_currentCloser.dailyCallTarget} Calls / Day', isDark),
                _buildDivider(isDark),
                _buildDetailRow('Account Status', _currentCloser.isActive ? 'Active (Full Telesales & Dispatch Access)' : 'Suspended (Access Revoked)', isDark),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'OPERATING TERRITORY & REGIONAL DISPATCH SCOPING',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_outlined, color: Color(0xFFF37021), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Primary Dispatch Hub: Wuse Central Distribution Hub (Abuja)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Orders converted by ${_currentCloser.fullName} are automatically scoped to matching State LGAs and auto-dispatched to the nearest DC & available Rider fleet.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: COMMISSIONS & ANALYTICS
  // ==========================================
  Widget _buildAnalyticsTab(List<OrderEntity> orders, bool isDark, NumberFormat currencyFormatter, double totalCommission) {
    final deliveredOrders = orders.where((o) => o.isDelivered).toList();
    final inTransitOrders = orders.where((o) => o.status.toLowerCase() == 'in_transit').toList();
    final pendingOrders = orders.where((o) => o.status.toLowerCase().contains('pending')).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMISSION EARNINGS & PAYOUT BREAKDOWN',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xFF1E294A), const Color(0xFF0F172A)] : [const Color(0xFFEFF6FF), Colors.white],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.paid_rounded, color: Color(0xFF10B981), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Earned Commission', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormatter.format(totalCommission),
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deliveredOrders.length} Delivered Orders × ${currencyFormatter.format(_currentCloser.commissionRate)} Commission per Delivery',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'ORDER STATUS BREAKDOWN FOR THIS CLOSER',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildStatusMetricCard('Delivered (Paid)', '${deliveredOrders.length}', const Color(0xFF10B981), isDark)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatusMetricCard('In Transit', '${inTransitOrders.length}', const Color(0xFF3B82F6), isDark)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatusMetricCard('Pending Dispatch', '${pendingOrders.length}', const Color(0xFFF59E0B), isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetricCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, color: isDark ? const Color(0xFF1E294A) : const Color(0xFFF1F5F9));
  }
}
