import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../users/presentation/widgets/edit_profile_modal.dart';
import '../../domain/entities/distribution_center.dart';

class DCStaffProfileSettingsTab extends ConsumerWidget {
  final String roleBadgeTitle;
  final String departmentLabel;
  final Color accentColor;
  final IconData roleIcon;
  final DistributionCenter? station;
  final Widget? extraActionTile;

  const DCStaffProfileSettingsTab({
    super.key,
    required this.roleBadgeTitle,
    required this.departmentLabel,
    required this.accentColor,
    required this.roleIcon,
    this.station,
    this.extraActionTile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final currentStationName = station?.name ?? user?.distributionCenterName ?? 'Central Distribution Hub';
    final currentStationCity = station != null ? '${station!.city}, ${station!.state}' : (user?.operatingCity ?? 'Abuja, FCT');
    final currentStationAddress = station?.address ?? 'Main Terminal Station';
    final currentSupervisor = station?.managerName ?? 'Station Manager';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // 1. User Profile & Avatar Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar with camera badge
              GestureDetector(
                onTap: () {
                  if (user != null) EditProfileModal.show(context, user);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatarWidget(
                      avatarUrl: user?.avatarUrl,
                      fullName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Staff Officer',
                      radius: 42,
                      showBorder: true,
                      borderColor: accentColor.withValues(alpha: 0.8),
                      borderWidth: 2.5,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF151D36) : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.fullName.isNotEmpty == true ? user!.fullName : 'Administrative Officer',
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Department / Role Chips
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, size: 12, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          roleBadgeTitle.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      departmentLabel.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Edit Profile & DP Action Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (user != null) EditProfileModal.show(context, user);
                },
                icon: Icon(Icons.edit_outlined, size: 15, color: accentColor),
                label: Text(
                  'Edit Profile & DP',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              _buildProfileRow(Icons.badge_outlined, 'Staff Code', user?.deliveryAgentCode ?? 'OPS-01'),
              _buildProfileRow(Icons.alternate_email_rounded, 'Email Address', user?.email ?? 'N/A'),
              _buildProfileRow(Icons.phone_outlined, 'Phone', user?.phone ?? 'N/A'),
              _buildProfileRow(Icons.warehouse_rounded, 'Assigned DC', currentStationName),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Station Information Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_city_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Station Information',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProfileRow(Icons.domain_rounded, 'Facility', currentStationName),
              _buildProfileRow(Icons.pin_drop_outlined, 'Region / City', currentStationCity),
              _buildProfileRow(Icons.map_outlined, 'Physical Address', currentStationAddress),
              _buildProfileRow(Icons.person_pin_circle_outlined, 'DC Supervisor', currentSupervisor),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Security, Preferences & Settings Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              if (extraActionTile != null) ...[
                extraActionTile!,
                const Divider(height: 1),
              ],
              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: const Color(0xFFF37021),
                ),
                title: Text(
                  'Dark Mode Theme',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isDark ? 'Dark theme is active' : 'Light theme is active',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: accentColor,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.lock_reset_rounded, color: accentColor),
                title: Text(
                  'Change Password',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Update your secret login credentials',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showPasswordResetDialog(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                title: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                subtitle: Text(
                  'End active administrative session on this device',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static void _showPasswordResetDialog(BuildContext context, WidgetRef ref) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF0D9488)),
              const SizedBox(width: 10),
              Text(
                'Change Password',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newPass = passCtrl.text.trim();
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        return;
                      }
                      if (newPass != confirmCtrl.text.trim()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);
                      final res = await ref.read(authProvider.notifier).changePassword(
                            oldPassword: '',
                            newPassword: newPass,
                          );
                      if (dialogContext.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (context.mounted) {
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Password updated successfully!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚠️ ${res['error'] ?? 'Could not change password'}'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your administrative session?',
          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
