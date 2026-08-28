import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../widgets/change_password_modal.dart';
import '../widgets/edit_profile_modal.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    final user = authState.user;
    final agentName = user != null && user.fullName.isNotEmpty ? user.fullName : 'Field Agent';
    final agentCode = (user?.deliveryAgentCode != null && user!.deliveryAgentCode!.isNotEmpty) ? user.deliveryAgentCode! : 'PDA-7000';
    final dcName = (user?.distributionCenterName != null && user!.distributionCenterName!.isNotEmpty) ? user.distributionCenterName! : 'Wuse Distribution Center';
    final phone = user != null && user.phone.isNotEmpty ? user.phone : 'Not set';
    final email = user?.email ?? '';
    final stateLoc = user != null && user.operatingState.isNotEmpty ? user.operatingState : 'Abuja (FCT)';
    final cityLoc = user != null && user.operatingCity.isNotEmpty ? user.operatingCity : 'Wuse II';
    final vehicle = user != null && user.vehicleType.isNotEmpty ? user.vehicleType : 'Motorcycle (Bajaj Boxer)';
    final plateNo = user != null && user.vehiclePlateNumber.isNotEmpty ? user.vehiclePlateNumber : 'Pending Registration';
    final bankName = user != null && user.bankName.isNotEmpty ? user.bankName : 'Guaranty Trust Bank (GTBank)';
    final bankAccountNo = user != null && user.bankAccountNumber.isNotEmpty ? user.bankAccountNumber : 'Pending Setup';
    final bankAccountName = user != null && user.bankAccountName.isNotEmpty ? user.bankAccountName : agentName;

    final deliveredOrders = ordersState.orders.where((o) => o.status == 'delivered').toList();
    final failedOrders = ordersState.orders.where((o) => o.status == 'failed' || o.status == 'cancelled').toList();
    final totalAttempted = deliveredOrders.length + failedOrders.length;

    // 100% Dynamic lifetime drops: Database base count + live session delivered orders
    final int baseCount = user?.lifetimeDeliveriesCount ?? 0;
    final int totalLifetimeCount = baseCount + deliveredOrders.length;
    final String lifetimeDrops = NumberFormat('#,###').format(totalLifetimeCount);

    // 100% Dynamic success rate % = (delivered / total attempted) * 100
    final double successRateVal = totalAttempted > 0
        ? ((deliveredOrders.length / totalAttempted) * 100.0)
        : 100.0;
    final String successRateStr = totalAttempted > 0 ? '${successRateVal.toStringAsFixed(1)}%' : '100%';

    // 100% Dynamic performance rating
    final double computedRating = totalAttempted > 0
        ? ((deliveredOrders.length / totalAttempted) * 5.0).clamp(1.0, 5.0)
        : (user?.rating ?? 5.0);
    final String performanceRating = computedRating.toStringAsFixed(1);

    final double commissionRate = user?.commissionRate ?? 1000.0;
    final double transportAllowance = user?.isPda == false ? (user?.fuelAllowance ?? 800.0) : (user?.transportAllowance ?? 1500.0);
    final double totalEarningPerOrder = commissionRate + transportAllowance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              ref.read(bottomNavIndexProvider.notifier).state = 0;
            }
          },
        ),
        title: Text(
          'PROFILE & SETTINGS',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.orange, size: 26),
            tooltip: 'Edit Profile & Bank Details',
            onPressed: () {
              if (user != null) EditProfileModal.show(context, user);
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFF8928) : AppColors.primary,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final agentId = user?.deliveryAgentId ?? user?.id ?? '';
          if (agentId.isNotEmpty) {
            await ref.read(ordersProvider.notifier).loadOrders(agentId);
          }
          await ref.read(authProvider.notifier).checkCurrentUser();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO USER PROFILE CARD WITH ONLINE STATUS BADGE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user != null) EditProfileModal.show(context, user);
                      },
                      child: Stack(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: user?.avatarUrl,
                            fullName: agentName,
                            radius: 42,
                            showBorder: true,
                            borderColor: AppColors.orange.withValues(alpha: 0.8),
                            borderWidth: 2.5,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.cardColor, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      agentName,
                      style: GoogleFonts.inter(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        side: BorderSide(color: AppColors.orange.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (user != null) EditProfileModal.show(context, user);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.orange),
                      label: Text(
                        'Edit Profile & DP',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orange),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            agentCode,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            user?.isPda == false ? 'IN-HOUSE RIDER' : 'FREELANCE PDA',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warehouse_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          dcName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. PERFORMANCE & OPERATIONAL KPI CARDS
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: AppColors.orange, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            lifetimeDrops,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'LIFETIME DROPS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(height: 4),
                          Text(
                            successRateStr,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SUCCESS RATE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                          const SizedBox(height: 2),
                          Text(
                            performanceRating,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RATING',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. PERSONAL & CONTACT INFORMATION CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
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
                              const Icon(Icons.person_outline_rounded, color: AppColors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Personal & Contact Details',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange),
                          tooltip: 'Edit Personal Details',
                          onPressed: () {
                            if (user != null) EditProfileModal.show(context, user, initialTabIndex: 0);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProfileDetailRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Phone Number',
                      value: phone,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: email,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.map_outlined,
                      label: 'Operating Region',
                      value: '$cityLoc, $stateLoc',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. FINANCIAL COMPENSATION & BANK SETTLEMENT CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
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
                              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Compensation & Settlement Bank',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF16A34A)),
                          tooltip: 'Edit Settlement Bank Details',
                          onPressed: () {
                            if (user != null) EditProfileModal.show(context, user, initialTabIndex: 1);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProfileDetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Commission / Order',
                      value: CurrencyFormatter.formatNaira(commissionRate),
                      valueColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.local_gas_station_outlined,
                      label: 'Transport Allowance',
                      value: CurrencyFormatter.formatNaira(transportAllowance),
                      valueColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.add_task_rounded,
                      label: 'Total Net / Delivery',
                      value: CurrencyFormatter.formatNaira(totalEarningPerOrder),
                      valueColor: const Color(0xFF00522A),
                    ),
                    const Divider(height: 20),
                    _ProfileDetailRow(
                      icon: Icons.account_balance_rounded,
                      label: 'Settlement Bank',
                      value: bankName,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.credit_card_rounded,
                      label: 'Account Number',
                      value: bankAccountNo,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.person_pin_outlined,
                      label: 'Beneficiary Name',
                      value: bankAccountName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. VEHICLE & FLEET ASSET CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
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
                              const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vehicle & Fleet License',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                          tooltip: 'Edit Vehicle Details',
                          onPressed: () {
                            if (user != null) EditProfileModal.show(context, user, initialTabIndex: 2);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProfileDetailRow(
                      icon: Icons.directions_bike_rounded,
                      label: 'Vehicle Asset',
                      value: vehicle,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.subtitles_outlined,
                      label: 'Plate Number',
                      value: plateNo,
                    ),
                    const SizedBox(height: 10),
                    _ProfileDetailRow(
                      icon: Icons.shield_outlined,
                      label: 'Safety & Helmet Verified',
                      value: 'Compliant ✓',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. SECURITY & PASSWORD MANAGEMENT CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security & Authentication',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.key_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      title: Text(
                        'Change Account Password',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        'Update your login password securely',
                        style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => ChangePasswordModal.show(context),
                        child: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 7. TERMINAL SETTINGS & PREFERENCES
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? const Color(0xFFFF8928) : AppColors.primary,
                      ),
                      title: Text(
                        'Dark Mode Theme',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        isDark ? 'Industrial Dark Active' : 'Light Theme Active',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: isDark,
                      activeThumbColor: AppColors.orange,
                      onChanged: (val) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.onSurface),
                      title: Text('Notification Preferences', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.help_outline_rounded, color: theme.colorScheme.onSurface),
                      title: Text('Help & Field Operations Support', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting to DC Operations Desk...')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 8. LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _showLogoutDialog(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    'LOGOUT OF TERMINAL',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A)),
            const SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of the NovaExpress Rider Terminal?',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
