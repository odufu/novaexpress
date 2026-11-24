import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/registration_lookups.dart';

class RegistrationRoleVisuals {
  final IconData icon;
  final Color color;

  const RegistrationRoleVisuals({
    required this.icon,
    required this.color,
  });

  static RegistrationRoleVisuals of(RegistrationAccountType role) {
    switch (role) {
      case RegistrationAccountType.closer:
        return const RegistrationRoleVisuals(
          icon: Icons.headset_mic_rounded,
          color: Color(0xFF4F46E5),
        );
      case RegistrationAccountType.salesSupervisor:
        return const RegistrationRoleVisuals(
          icon: Icons.verified_user_rounded,
          color: Color(0xFFF37021),
        );
      case RegistrationAccountType.marketer:
        return const RegistrationRoleVisuals(
          icon: Icons.campaign_rounded,
          color: Color(0xFFDB2777),
        );
      case RegistrationAccountType.marketingSupervisor:
        return const RegistrationRoleVisuals(
          icon: Icons.trending_up_rounded,
          color: Color(0xFF9D174D),
        );
      case RegistrationAccountType.merchantAccountant:
        return const RegistrationRoleVisuals(
          icon: Icons.receipt_long_rounded,
          color: Color(0xFF0D9488),
        );
      case RegistrationAccountType.client:
        return const RegistrationRoleVisuals(
          icon: Icons.storefront_rounded,
          color: Color(0xFFD97706),
        );
      case RegistrationAccountType.dcOperations:
        return const RegistrationRoleVisuals(
          icon: Icons.hub_rounded,
          color: Color(0xFF059669),
        );
      case RegistrationAccountType.dcStockAdmin:
        return const RegistrationRoleVisuals(
          icon: Icons.inventory_2_rounded,
          color: Color(0xFF0284C7),
        );
      case RegistrationAccountType.dcFinanceAdmin:
        return const RegistrationRoleVisuals(
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFFB45309),
        );
      case RegistrationAccountType.dcManager:
        return const RegistrationRoleVisuals(
          icon: Icons.apartment_rounded,
          color: Color(0xFF1E3A8A),
        );
      case RegistrationAccountType.generalAccountant:
        return const RegistrationRoleVisuals(
          icon: Icons.account_balance_rounded,
          color: Color(0xFF7C3AED),
        );
      case RegistrationAccountType.deliveryAgent:
        return const RegistrationRoleVisuals(
          icon: Icons.two_wheeler_rounded,
          color: Color(0xFF6D28D9),
        );
    }
  }
}

class RegistrationRoleSelectionStep extends StatelessWidget {
  final RegistrationAccountType selectedRole;
  final RegistrationRoleTrack? selectedTrackFilter;
  final ValueChanged<RegistrationRoleTrack?> onTrackFilterChanged;
  final ValueChanged<RegistrationAccountType> onRoleSelected;

  const RegistrationRoleSelectionStep({
    super.key,
    required this.selectedRole,
    required this.selectedTrackFilter,
    required this.onTrackFilterChanged,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredRoles = selectedTrackFilter == null
        ? RegistrationAccountType.values
        : RegistrationAccountType.values
            .where((r) => r.track == selectedTrackFilter)
            .toList();

    final visuals = RegistrationRoleVisuals.of(selectedRole);
    final generatedSteps = selectedRole.steps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Filter Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TrackFilterChip(
              label: 'All Roles (${RegistrationAccountType.values.length})',
              isSelected: selectedTrackFilter == null,
              onTap: () => onTrackFilterChanged(null),
            ),
            ...RegistrationRoleTrack.values.map((track) {
              final count = RegistrationAccountType.values
                  .where((r) => r.track == track)
                  .length;
              return _TrackFilterChip(
                label: '${track.label} ($count)',
                isSelected: selectedTrackFilter == track,
                onTap: () => onTrackFilterChanged(track),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Responsive Role Cards (1 col on mobile, 2 cols on tablet/desktop)
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoCols = constraints.maxWidth >= 600;
            if (!useTwoCols) {
              return Column(
                children: [
                  for (int i = 0; i < filteredRoles.length; i++) ...[
                    _RoleSelectionCard(
                      role: filteredRoles[i],
                      isSelected: filteredRoles[i] == selectedRole,
                      onTap: () => onRoleSelected(filteredRoles[i]),
                    ),
                    if (i != filteredRoles.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              );
            }

            final rows = <Widget>[];
            for (int i = 0; i < filteredRoles.length; i += 2) {
              final first = filteredRoles[i];
              final second =
                  (i + 1 < filteredRoles.length) ? filteredRoles[i + 1] : null;
              rows.add(
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _RoleSelectionCard(
                          role: first,
                          isSelected: first == selectedRole,
                          onTap: () => onRoleSelected(first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: second != null
                            ? _RoleSelectionCard(
                                role: second,
                                isSelected: second == selectedRole,
                                onTap: () => onRoleSelected(second),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
              if (i + 2 < filteredRoles.length) {
                rows.add(const SizedBox(height: 12));
              }
            }
            return Column(children: rows);
          },
        ),

        const SizedBox(height: 18),

        // Dynamic Regenerated Pipeline Preview Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: visuals.color.withValues(alpha: isDark ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: visuals.color.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: visuals.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dynamic Onboarding Steps for ${selectedRole.title}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int idx = 0; idx < generatedSteps.length; idx++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: visuals.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${idx + 1}. ${selectedRole.stepShortTitle(generatedSteps[idx])}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: visuals.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Direct Workspace: ${selectedRole.targetConsoleLabel} • ${selectedRole.requirementSummary}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.orange : AppColors.primary)
              : (isDark ? AppColors.cardDark : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.orange : AppColors.primary)
                : (isDark
                    ? AppColors.borderDark
                    : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final RegistrationAccountType role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visuals = RegistrationRoleVisuals.of(role);
    final stepCount = role.steps.length;

    return InkWell(
      key: Key('reg_role_${role.roleKey}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected
              ? visuals.color.withValues(alpha: isDark ? 0.16 : 0.06)
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? visuals.color
                : (isDark
                    ? AppColors.borderDark
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: visuals.color.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: visuals.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    visuals.icon,
                    color: visuals.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: visuals.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role.badge,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: visuals.color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$stepCount Steps',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: visuals.color,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              role.subtitle,
              style: GoogleFonts.inter(
                fontSize: 11.8,
                height: 1.35,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                role.requirementSummary,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? visuals.color
                      : (isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

