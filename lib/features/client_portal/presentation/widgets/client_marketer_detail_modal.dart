import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/payout_receipt_preview_dialog.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import '../../domain/entities/client_marketer.dart';
import '../../domain/entities/lead_form.dart';
import '../providers/client_portal_provider.dart';
import 'client_disburse_marketer_payout_modal.dart';
import 'client_edit_marketer_profile_modal.dart';
import 'client_form_builder_modal.dart';
import 'client_form_embed_modal.dart';
import 'client_order_tracking_modal.dart';

class ClientMarketerDetailModal extends ConsumerStatefulWidget {
  final ClientMarketer marketer;
  final bool isSupervisorView;

  const ClientMarketerDetailModal({
    super.key,
    required this.marketer,
    this.isSupervisorView = false,
  });

  static Future<void> show(
    BuildContext context, {
    required ClientMarketer marketer,
    bool isSupervisorView = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientMarketerDetailModal(
        marketer: marketer,
        isSupervisorView: isSupervisorView,
      ),
    );
  }

  @override
  ConsumerState<ClientMarketerDetailModal> createState() => _ClientMarketerDetailModalState();
}

class _ClientMarketerDetailModalState extends ConsumerState<ClientMarketerDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClientMarketer _currentMarketer;
  String _orderSearchQuery = '';
  String _selectedOrderStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentMarketer = widget.marketer;

    // Proactively load marketer payouts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientPortalProvider.notifier).loadMarketerPayouts(_currentMarketer.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Marketer Password',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      _currentMarketer.fullName,
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
                  'Set a new password for ${_currentMarketer.email}. The marketer will use this password to access their ad campaign portal.',
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
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();

                try {
                  await ref.read(clientPortalProvider.notifier).resetMarketerPassword(
                    marketerId: _currentMarketer.id,
                    newPassword: passwordCtrl.text.trim(),
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text('Password updated successfully for ${_currentMarketer.fullName}!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Password reset failed: $e')),
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

  void _showCredentialsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.share_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Marketer Login Credentials', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_currentMarketer.fullName, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCredentialRow('Marketer Code', _currentMarketer.marketerCode),
            const SizedBox(height: 10),
            _buildCredentialRow('Login Email', _currentMarketer.email),
            const SizedBox(height: 10),
            _buildCredentialRow('Phone', _currentMarketer.phone),
            const SizedBox(height: 10),
            _buildCredentialRow('Role', _currentMarketer.isSupervisor ? 'Marketing Supervisor' : 'Digital Marketer / Media Buyer'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Default Temporary Password: Marketer123! (or updated password)',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final text = 'NoveXPS Marketer Access:\n'
                  'Name: ${_currentMarketer.fullName}\n'
                  'Code: ${_currentMarketer.marketerCode}\n'
                  'Email: ${_currentMarketer.email}\n'
                  'Default Password: Marketer123!\n'
                  'Portal: https://novexps.com/login';
              _copyToClipboard(text, 'Credentials');
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text('Copy All Credentials', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF10B981)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => _copyToClipboard(value, label),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleMarketerStatus() async {
    final nextStatus = !_currentMarketer.isActive;
    final actionName = nextStatus ? 'Activate' : 'Deactivate';
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionName Marketer Access?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          nextStatus
            ? 'Are you sure you want to activate ${_currentMarketer.fullName}? They will regain access to launch ad campaigns and earn commissions.'
            : 'Are you sure you want to deactivate ${_currentMarketer.fullName}? They will temporarily lose access to the Marketer Portal.',
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
      await ref.read(clientPortalProvider.notifier).toggleMarketerStatus(
        marketerId: _currentMarketer.id,
        isActive: nextStatus,
      );
      setState(() {
        _currentMarketer = _currentMarketer.copyWith(isActive: nextStatus);
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: nextStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            content: Text('${_currentMarketer.fullName} is now ${nextStatus ? "Active" : "Deactivated"}.'),
          ),
        );
      }
    }
  }

  void _confirmDeleteMarketer() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text('Delete Marketer?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_currentMarketer.fullName}? All existing lead forms and order conversion histories will be preserved safely.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(clientPortalProvider.notifier).deleteMarketer(_currentMarketer.id);
        if (mounted) {
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('Marketer ${_currentMarketer.fullName} deleted successfully.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Deletion failed: $e')),
          );
        }
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

    // Keep _currentMarketer fresh from state
    final liveMarketer = state.marketers.where((m) => m.id == _currentMarketer.id).firstOrNull;
    if (liveMarketer != null) {
      _currentMarketer = liveMarketer;
    }

    // Forms belonging to this marketer
    final marketerForms = state.leadForms.where((f) => f.marketerId == _currentMarketer.id).toList();
    final formIds = marketerForms.map((f) => f.id).toSet();

    // Orders attributed to this marketer (direct marketer_id or via lead form)
    final baseOrders = state.orders.where((o) =>
        (o.marketerId != null && o.marketerId == _currentMarketer.id) ||
        (o.formId != null && formIds.contains(o.formId))).toList();

    // Filter orders by search & status
    final filteredOrders = baseOrders.where((o) {
      if (_selectedOrderStatusFilter != 'all') {
        if (_selectedOrderStatusFilter == 'delivered' && !o.isDelivered) return false;
        if (_selectedOrderStatusFilter == 'pending_dispatch' && o.status != 'pending_dispatch' && o.status != 'confirmed') return false;
        if (_selectedOrderStatusFilter == 'in_transit' && o.status != 'in_transit' && o.status != 'assigned') return false;
        if (_selectedOrderStatusFilter == 'cancelled' && !o.isCancelled) return false;
      }
      if (_orderSearchQuery.isNotEmpty) {
        final q = _orderSearchQuery.toLowerCase();
        return o.orderNumber.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.productName.toLowerCase().contains(q) ||
            o.deliveryCity.toLowerCase().contains(q) ||
            (o.lga != null && o.lga!.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    // Calculate live dynamic metrics
    int liveSubmissions = 0;
    int liveBooked = 0;
    int liveDelivered = 0;
    for (final f in marketerForms) {
      liveSubmissions += f.totalSubmissions;
      liveBooked += f.totalOrdersBooked;
      liveDelivered += f.totalOrdersDelivered;
    }

    final totalLeads = liveSubmissions > _currentMarketer.totalLeadsGenerated ? liveSubmissions : _currentMarketer.totalLeadsGenerated;
    final totalBooked = liveBooked > _currentMarketer.totalOrdersGenerated ? liveBooked : _currentMarketer.totalOrdersGenerated;
    final totalDelivered = liveDelivered > _currentMarketer.totalOrdersDelivered ? liveDelivered : _currentMarketer.totalOrdersDelivered;

    final deliveredOrders = baseOrders.where((o) => o.isDelivered).toList();
    final double totalRevenue = deliveredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    final double convRate = totalBooked > 0
        ? ((totalDelivered / totalBooked) * 100).clamp(0.0, 100.0)
        : (totalLeads > 0 ? ((totalDelivered / totalLeads) * 100).clamp(0.0, 100.0) : 0.0);

    final mediaQuery = MediaQuery.of(context);
    final isCompactScreen = mediaQuery.size.width < 500;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompactScreen ? 10 : 16,
        vertical: 20,
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.92,
          maxWidth: 1080,
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
            // 1. Header with Avatar & Action Controls
            _buildModalHeader(context, isDark),

            // 2. Performance KPI Ribbon (6 Metrics)
            _buildKpiRibbon(
              isDark: isDark,
              currencyFormatter: currencyFormatter,
              totalRevenue: totalRevenue,
              totalCommission: _currentMarketer.totalCommissionEarned,
              unpaidBalance: _currentMarketer.unpaidCommissionBalance,
              totalLeads: totalLeads,
              totalBooked: totalBooked,
              totalDelivered: totalDelivered,
              convRate: convRate,
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
                indicatorColor: const Color(0xFF10B981),
                indicatorWeight: 3,
                labelColor: const Color(0xFF10B981),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Attributed Orders (${baseOrders.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Lead Forms (${marketerForms.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(_currentMarketer.isSupervisor ? 'Team & Supervisees' : 'Supervisor & Hierarchy'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text('Commissions & Payouts'),
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
                  _buildOrdersTab(filteredOrders, isDark, currencyFormatter),
                  _buildFormsTab(marketerForms, isDark),
                  _buildHierarchyTab(state, isDark, currencyFormatter),
                  _buildCommissionsTab(state, isDark, currencyFormatter),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: Modal Header & Actions
  // ===========================================================================
  Widget _buildModalHeader(BuildContext context, bool isDark) {
    final statusColor = _currentMarketer.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with edit badge
          GestureDetector(
            onTap: () => ClientEditMarketerProfileModal.show(context, marketer: _currentMarketer),
            child: Stack(
              children: [
                UserAvatarWidget(
                  avatarUrl: _currentMarketer.avatarUrl,
                  fullName: _currentMarketer.fullName,
                  radius: 26,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Name, Code, Badges, Contact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      _currentMarketer.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentMarketer.marketerCode,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentMarketer.isActive ? 'ACTIVE MARKETER' : 'DEACTIVATED',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                    if (_currentMarketer.isSupervisor)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, size: 11, color: Color(0xFF6366F1)),
                            const SizedBox(width: 3),
                            Text(
                              'SUPERVISOR',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${_currentMarketer.email} • ${_currentMarketer.phone}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    if (!_currentMarketer.isSupervisor && _currentMarketer.supervisorName != null && _currentMarketer.supervisorName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Supervised by ${_currentMarketer.supervisorName}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Top Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSupervisorView) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        'SUPERVISOR VIEW',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!widget.isSupervisorView) ...[
                IconButton(
                  tooltip: 'Delete Marketer',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: _confirmDeleteMarketer,
                ),
              ],
              IconButton(
                tooltip: 'Edit Profile & Settings',
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: _currentMarketer),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: Text('Share Login', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: _showCredentialsDialog,
              ),
              if (!widget.isSupervisorView) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.lock_reset_rounded, size: 14),
                  label: Text('Reset Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: _showPasswordResetDialog,
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentMarketer.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _toggleMarketerStatus,
                  child: Text(_currentMarketer.isActive ? 'Deactivate' : 'Activate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Close Modal',
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: Performance KPI Ribbon (6 Metrics)
  // ===========================================================================
  Widget _buildKpiRibbon({
    required bool isDark,
    required NumberFormat currencyFormatter,
    required double totalRevenue,
    required double totalCommission,
    required double unpaidBalance,
    required int totalLeads,
    required int totalBooked,
    required int totalDelivered,
    required double convRate,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : const Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isRow = constraints.maxWidth >= 768;
          final kpis = [
            _buildRibbonCard(
              'Daily Ad Spend',
              currencyFormatter.format(_currentMarketer.dailyAdSpendBudget),
              '${currencyFormatter.format(_currentMarketer.dailyAdSpendBudget * 30)}/mo pace',
              Icons.campaign_outlined,
              const Color(0xFF6366F1),
              isDark,
            ),
            _buildRibbonCard(
              'Leads Ingested',
              '$totalLeads',
              'Form checkouts submitted',
              Icons.contact_mail_outlined,
              const Color(0xFF0EA5E9),
              isDark,
            ),
            _buildRibbonCard(
              'Orders Booked',
              '$totalBooked',
              'Confirmed by telesales',
              Icons.phone_in_talk_outlined,
              const Color(0xFFF59E0B),
              isDark,
            ),
            _buildRibbonCard(
              'Delivered (POD)',
              '$totalDelivered',
              '${convRate.toStringAsFixed(1)}% Conversion',
              Icons.verified_outlined,
              const Color(0xFF10B981),
              isDark,
            ),
            _buildRibbonCard(
              'Commission Earned',
              currencyFormatter.format(totalCommission),
              '${currencyFormatter.format(unpaidBalance)} unpaid balance',
              Icons.payments_outlined,
              const Color(0xFF10B981),
              isDark,
            ),
            _buildRibbonCard(
              'Ad Revenue Generated',
              currencyFormatter.format(totalRevenue),
              'Gross delivered GMV',
              Icons.monetization_on_outlined,
              const Color(0xFFF37021),
              isDark,
            ),
          ];

          return isRow
              ? Row(
                  children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: k))).toList(),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 16) / 3, child: k)).toList(),
                );
        },
      ),
    );
  }

  Widget _buildRibbonCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w500, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: Tab 1 - Attributed Orders
  // ===========================================================================
  Widget _buildOrdersTab(List<OrderEntity> orders, bool isDark, NumberFormat currencyFormatter) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _orderSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by Order #, Customer Name, City, Product...',
                    hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${orders.length} Orders Converted',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildFilterChip('All Statuses', 'all'),
              _buildFilterChip('Delivered (POD)', 'delivered'),
              _buildFilterChip('Pending Dispatch', 'pending_dispatch'),
              _buildFilterChip('In Transit / Assigned', 'in_transit'),
              _buildFilterChip('Cancelled', 'cancelled'),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Orders List
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text('No Orders Found', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('No customer orders match the current filter for this marketer.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    return _buildOrderCard(o, isDark, currencyFormatter);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedOrderStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedOrderStatusFilter = value),
        selectedColor: const Color(0xFF10B981).withValues(alpha: 0.18),
        checkmarkColor: const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity o, bool isDark, NumberFormat currencyFormatter) {
    final statusColor = _getStatusColor(o.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_shipping_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 14),

          // Order details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      o.orderNumber,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        o.status.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${o.customerName} (${o.customerPhone}) • ${(o.lga != null && o.lga!.isNotEmpty) ? "${o.lga}, " : ""}${o.deliveryState}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${o.productName} (${o.quantity > 0 ? "${o.quantity} units" : "Single Item"})',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021)),
                    ),
                    if (o.closerName != null && o.closerName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('• Closer: ${o.closerName}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount & Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(o.totalAmount),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF10B981)),
                    tooltip: 'Order Pipeline Chat',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => OrderPipelineChatSheet.showForOrder(context, o),
                  ),
                  InkWell(
                    onTap: () => ClientOrderTrackingModal.show(context, o),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View Order >',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return const Color(0xFF10B981);
      case 'pending_dispatch':
      case 'confirmed':
        return const Color(0xFFF59E0B);
      case 'assigned':
      case 'in_transit':
        return const Color(0xFF0EA5E9);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ===========================================================================
  // SECTION 4: Tab 2 - Campaign Lead Forms
  // ===========================================================================
  Widget _buildFormsTab(List<LeadForm> forms, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Campaign Landing Pages (${forms.length})',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Create Form for Marketer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => ClientFormBuilderModal.show(context),
              ),
            ],
          ),
        ),

        Expanded(
          child: forms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text('No Lead Forms Created', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('Create an ad landing page checkout form assigned to this marketer.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: forms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final f = forms[index];
                    return _buildFormCard(f, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFormCard(LeadForm f, bool isDark) {
    final formUrl = 'https://novexps.com/f/${f.formSlug}';
    final conv = f.conversionRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Product: ${f.productName} • Slug: /f/${f.formSlug}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 12),
                    label: Text('Copy Link', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () => _copyToClipboard(formUrl, 'Form URL'),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.code_rounded, size: 12),
                    label: Text('Embed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () => ClientFormEmbedModal.show(context, form: f),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Metrics Bar
          Row(
            children: [
              _buildFormStat('Views', '${f.totalViews}', const Color(0xFF64748B)),
              _buildFormStat('Submissions', '${f.totalSubmissions}', const Color(0xFF0EA5E9)),
              _buildFormStat('Orders Booked', '${f.totalOrdersBooked}', const Color(0xFFF59E0B)),
              _buildFormStat('Delivered', '${f.totalOrdersDelivered}', const Color(0xFF10B981)),
              _buildFormStat('Conv. Rate', '${conv.toStringAsFixed(1)}%', const Color(0xFF10B981)),
              if (f.pixelId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Meta Pixel: ${f.pixelId}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 5: Tab 3 - Supervision & Team Hierarchy
  // ===========================================================================
  Widget _buildHierarchyTab(ClientPortalState state, bool isDark, NumberFormat currencyFormatter) {
    if (_currentMarketer.isSupervisor) {
      // Find all media buyers supervised by this marketer
      final supervisees = state.marketers.where((m) =>
          m.supervisorId != null && m.supervisorId == _currentMarketer.id && m.id != _currentMarketer.id).toList();

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervised Media Buyers & Marketers (${supervisees.length})',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    Text(
                      'As a supervisor, ${_currentMarketer.fullName} manages campaign budgets and performance for these media buyers.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: supervisees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                          const SizedBox(height: 10),
                          Text('No Subordinate Marketers Assigned', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text('When onboarding junior media buyers, select ${_currentMarketer.fullName} as supervisor.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: supervisees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sub = supervisees[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              UserAvatarWidget(avatarUrl: sub.avatarUrl, fullName: sub.fullName, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub.fullName, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                    Text('${sub.email} • Code: ${sub.marketerCode}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Budget: ${currencyFormatter.format(sub.dailyAdSpendBudget)}/day',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0EA5E9)),
                                  ),
                                  Text(
                                    '${sub.totalLeadsGenerated} leads • ${sub.totalOrdersDelivered} delivered',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  ClientMarketerDetailModal.show(
                                    context,
                                    marketer: sub,
                                    isSupervisorView: widget.isSupervisorView,
                                  );
                                },
                                child: const Text('View Details'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    } else {
      // Junior Media Buyer view
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supervisory Hierarchy', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text('Reporting lines, ad campaign escalation, and budget oversight.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentMarketer.supervisorName != null && _currentMarketer.supervisorName!.isNotEmpty
                              ? _currentMarketer.supervisorName!
                              : 'Brand Admin Direct (No Supervisor Assigned)',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Direct Campaign Supervisor & Ad Budget Approver',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: _currentMarketer),
                    child: const Text('Change Supervisor'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ===========================================================================
  // SECTION 6: Tab 4 - Commissions & Payouts
  // ===========================================================================
  Widget _buildCommissionsTab(ClientPortalState state, bool isDark, NumberFormat currencyFormatter) {
    final payouts = state.marketerPayouts.where((p) => p.marketerId == _currentMarketer.id).toList();
    final modelText = _currentMarketer.commissionModel == 'per_delivered_order'
        ? 'Pay Per Delivered Order (₦${NumberFormat('#,##0').format(_currentMarketer.effectiveCommissionPerDelivery)} / delivery)'
        : 'Pay Per Form Submission (₦${NumberFormat('#,##0').format(_currentMarketer.effectiveCommissionPerSubmission)} / lead)';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Commission Model & Disburse Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Commission Model: ',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          modelText,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Automatic delivery milestone tracking & remittance disbursements.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                ],
              ),
              if (!widget.isSupervisorView)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text('Disburse Commission Payout', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  onPressed: () => ClientDisburseMarketerPayoutModal.show(context, marketer: _currentMarketer),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text('Merchant Settled Disbursements', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Balances Card
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard('Total Accrued Commission', currencyFormatter.format(_currentMarketer.totalCommissionEarned), const Color(0xFF10B981), isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard('Total Disbursed Payouts', currencyFormatter.format(_currentMarketer.totalPaidCommission), const Color(0xFF0EA5E9), isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard('Pending Unpaid Balance', currencyFormatter.format(_currentMarketer.unpaidCommissionBalance), const Color(0xFFF59E0B), isDark),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Settlement Bank Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settlement Bank Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(
                        _currentMarketer.hasBankDetails
                            ? '${_currentMarketer.bankName} • ${_currentMarketer.accountNumber} • ${_currentMarketer.accountName}'
                            : 'No bank details configured. Click edit to set bank details for direct transfer.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (_currentMarketer.hasBankDetails)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF10B981)),
                    tooltip: 'Copy Account Number',
                    onPressed: () => _copyToClipboard(_currentMarketer.accountNumber, 'Account Number'),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                  onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: _currentMarketer),
                  child: const Text('Edit Bank'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Payout History Ledger
          Text(
            'PAYOUT SETTLEMENT HISTORY (${payouts.length})',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          if (payouts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('No payout settlements recorded yet.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = payouts[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.payoutNumber, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                            Text(
                              '${DateFormat('MMM dd, yyyy • hh:mm a').format(p.createdAt)} • ${p.bankName} (${p.accountNumber})',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            if (p.notes != null && p.notes!.isNotEmpty)
                              Text('Note: ${p.notes}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormatter.format(p.amount), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                          Text(p.status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                        ],
                      ),
                      if (p.hasReceipt) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF6366F1)),
                          tooltip: 'View Payment Receipt',
                          onPressed: () {
                            PayoutReceiptPreviewDialog.show(
                              context,
                              title: 'Marketer Commission Receipt',
                              subtitle: 'Payout #${p.payoutNumber} • ${_currentMarketer.fullName} (${p.bankName} - ${p.accountNumber})',
                              amountFormatted: currencyFormatter.format(p.amount),
                              receiptUrl: p.proofOfPaymentUrl!,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
