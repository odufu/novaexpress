import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../domain/entities/registration_lookups.dart';
import 'registration_role_catalog.dart';

class RegistrationStepHeader extends StatelessWidget {
  final RegistrationAccountType role;
  final int currentStepIndex;
  final ValueChanged<int> onStepTapped;

  const RegistrationStepHeader({
    super.key,
    required this.role,
    required this.currentStepIndex,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = role.steps;
    final visuals = RegistrationRoleVisuals.of(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: visuals.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Step ${currentStepIndex + 1} of ${steps.length} • ${role.badge}',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: visuals.color,
                ),
              ),
            ),
            Text(
              role.targetConsoleLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          role.stepHeadline(steps[currentStepIndex]),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _StepPill(
                  index: i,
                  title: role.stepShortTitle(steps[i]),
                  isActive: i == currentStepIndex,
                  isCompleted: i < currentStepIndex,
                  accentColor: visuals.color,
                  onTap: i < currentStepIndex ? () => onStepTapped(i) : null,
                ),
                if (i != steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  final int index;
  final String title;
  final bool isActive;
  final bool isCompleted;
  final Color accentColor;
  final VoidCallback? onTap;

  const _StepPill({
    required this.index,
    required this.title,
    required this.isActive,
    required this.isCompleted,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isActive
        ? accentColor
        : (isCompleted
            ? accentColor.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.cardDark : const Color(0xFFF1F5F9)));
    final textColor = isActive
        ? Colors.white
        : (isCompleted
            ? accentColor
            : (isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B)));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive || isCompleted
                ? accentColor.withValues(alpha: 0.45)
                : (isDark
                    ? AppColors.borderDark
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.circle,
              size: isCompleted ? 13 : 7,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              '${index + 1}. $title',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantAssignmentStep extends StatelessWidget {
  final RegistrationAccountType role;
  final List<RegistrationMerchantOption> merchants;
  final bool loadingMerchants;
  final String? merchantsError;
  final VoidCallback onRetryMerchants;
  final String? selectedClientId;
  final ValueChanged<RegistrationMerchantOption?> onMerchantChanged;
  final List<RegistrationSupervisorOption> supervisors;
  final bool loadingSupervisors;
  final String? selectedSupervisorId;
  final ValueChanged<String?> onSupervisorChanged;
  final TextEditingController callTargetController;
  final TextEditingController adBudgetController;
  final String commissionModel;
  final ValueChanged<String> onCommissionModelChanged;
  final TextEditingController staffCodeController;

  const MerchantAssignmentStep({
    super.key,
    required this.role,
    required this.merchants,
    required this.loadingMerchants,
    this.merchantsError,
    required this.onRetryMerchants,
    required this.selectedClientId,
    required this.onMerchantChanged,
    required this.supervisors,
    required this.loadingSupervisors,
    required this.selectedSupervisorId,
    required this.onSupervisorChanged,
    required this.callTargetController,
    required this.adBudgetController,
    required this.commissionModel,
    required this.onCommissionModelChanged,
    required this.staffCodeController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMarketerRole = role == RegistrationAccountType.marketer ||
        role == RegistrationAccountType.marketingSupervisor;
    final needsSupervisorChoice = role == RegistrationAccountType.closer ||
        role == RegistrationAccountType.marketer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBanner(
          icon: Icons.storefront_rounded,
          color: const Color(0xFF4F46E5),
          text: isMarketerRole
              ? 'Marketers & Marketing Supervisors must belong to an active Partner Merchant to sync lead forms, Meta pixels, and commission ledgers.'
              : 'Telesales Closers & Sales Supervisors must link to a Partner Merchant so assigned leads, orders, and payouts route accurately.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Partner Merchant *'),
        const SizedBox(height: 6),
        _MerchantSelectorField(
          role: role,
          merchants: merchants,
          isLoading: loadingMerchants,
          errorMessage: merchantsError,
          selectedClientId: selectedClientId,
          onRetry: onRetryMerchants,
          onChanged: onMerchantChanged,
        ),
        const SizedBox(height: 16),

        if (needsSupervisorChoice && selectedClientId != null) ...[
          const _FieldLabel(text: 'Reporting Supervisor (Optional)'),
          const SizedBox(height: 6),
          if (loadingSupervisors)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (supervisors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDark
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                'No ${isMarketerRole ? 'Marketing' : 'Sales'} Supervisor registered for this merchant yet. Your account will report directly to the Merchant Admin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              key: Key(
                'reg_supervisor_dropdown_${selectedClientId}_${selectedSupervisorId ?? "direct"}_${supervisors.length}',
              ),
              initialValue: supervisors.any((s) => s.id == selectedSupervisorId)
                  ? selectedSupervisorId
                  : null,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: 'Select reporting supervisor or Direct to Admin',
                icon: Icons.supervisor_account_rounded,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Direct to Merchant Admin (No Supervisor)'),
                ),
                ...supervisors.map(
                  (sup) => DropdownMenuItem<String?>(
                    value: sup.id,
                    child: Text(
                      '${sup.fullName} (${sup.code})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onSupervisorChanged,
            ),
          const SizedBox(height: 16),
        ],

        if (!isMarketerRole) ...[
          const _FieldLabel(text: 'Daily Confirmed Orders / Call Target *'),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('reg_daily_call_target'),
            controller: callTargetController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration(
              context,
              hint: 'e.g. 50',
              icon: Icons.call_rounded,
            ),
            validator: (v) {
              final parsed = int.tryParse(v?.trim() ?? '');
              if (parsed == null || parsed < 1) {
                return 'Enter a daily target of at least 1 call';
              }
              return null;
            },
          ),
        ] else ...[
          const _FieldLabel(text: 'Daily Ad Spend Budget (₦) *'),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('reg_ad_budget'),
            controller: adBudgetController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration(
              context,
              hint: 'e.g. 25000',
              icon: Icons.payments_outlined,
            ),
            validator: (v) {
              final clean = (v ?? '').replaceAll(',', '').trim();
              final parsed = double.tryParse(clean);
              if (parsed == null || parsed < 1000) {
                return 'Enter a valid budget (minimum ₦1,000)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const _FieldLabel(text: 'Lead Attribution & Commission Model'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _SelectableOptionChip(
                label: 'Per Form Submission (₦500)',
                isSelected: commissionModel == 'per_form_submission',
                onTap: () => onCommissionModelChanged('per_form_submission'),
              ),
              _SelectableOptionChip(
                label: 'Per Delivered Order (₦1,000)',
                isSelected: commissionModel == 'per_delivered_order',
                onTap: () => onCommissionModelChanged('per_delivered_order'),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        const _FieldLabel(text: 'Preferred Staff / Agent Code (Optional)'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_staff_code'),
          controller: staffCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(
            context,
            hint: 'Auto-generated if left blank (e.g. ${role.badge}-101)',
            icon: Icons.qr_code_rounded,
          ),
        ),
      ],
    );
  }
}

class MerchantAccountantSetupStep extends StatelessWidget {
  final RegistrationAccountType role;
  final List<RegistrationMerchantOption> merchants;
  final bool loadingMerchants;
  final String? merchantsError;
  final VoidCallback onRetryMerchants;
  final String? selectedClientId;
  final ValueChanged<RegistrationMerchantOption?> onMerchantChanged;
  final TextEditingController staffCodeController;
  final bool canApproveSettlements;
  final bool canManageExpenses;
  final bool canDisbursePayouts;
  final ValueChanged<bool> onCanApproveChanged;
  final ValueChanged<bool> onCanExpensesChanged;
  final ValueChanged<bool> onCanDisburseChanged;

  const MerchantAccountantSetupStep({
    super.key,
    required this.role,
    required this.merchants,
    required this.loadingMerchants,
    this.merchantsError,
    required this.onRetryMerchants,
    required this.selectedClientId,
    required this.onMerchantChanged,
    required this.staffCodeController,
    required this.canApproveSettlements,
    required this.canManageExpenses,
    required this.canDisbursePayouts,
    required this.onCanApproveChanged,
    required this.onCanExpensesChanged,
    required this.onCanDisburseChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAnyPermission =
        canApproveSettlements || canManageExpenses || canDisbursePayouts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoBanner(
          icon: Icons.receipt_long_rounded,
          color: Color(0xFF0D9488),
          text:
              'Merchant Accountants reconcile DC settlements, marketing expenses, and closer payouts strictly scoped to their linked Merchant.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Partner Merchant *'),
        const SizedBox(height: 6),
        _MerchantSelectorField(
          role: role,
          merchants: merchants,
          isLoading: loadingMerchants,
          errorMessage: merchantsError,
          selectedClientId: selectedClientId,
          onRetry: onRetryMerchants,
          onChanged: onMerchantChanged,
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Preferred Accountant Code (Optional)'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_staff_code'),
          controller: staffCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(
            context,
            hint: 'Auto-generated if left blank (e.g. ACC-NOVA-101)',
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(height: 18),

        const _FieldLabel(text: 'Requested Financial Portal Scopes *'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !hasAnyPermission
                  ? AppColors.danger
                  : (isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: canApproveSettlements,
                onChanged: onCanApproveChanged,
                title: Text(
                  'Verify & Approve DC COD Settlements',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Reconcile net merchant remittance inflows across DCs.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: canManageExpenses,
                onChanged: onCanExpensesChanged,
                title: Text(
                  'Audit & Record Operating Expenses',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Track ad spend, fulfillment charges, and office expenses.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: canDisbursePayouts,
                onChanged: onCanDisburseChanged,
                title: Text(
                  'Process Staff & Commission Disbursements',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Manage closer and marketer salary & bonus payouts.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        if (!hasAnyPermission)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Select at least one finance permission scope.',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class MerchantBusinessProfileStep extends StatelessWidget {
  final TextEditingController companyNameController;
  final TextEditingController clientCodeController;
  final TextEditingController addressController;
  final String merchantTier;
  final ValueChanged<String> onTierChanged;
  final String selectedState;
  final ValueChanged<String> onStateChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const MerchantBusinessProfileStep({
    super.key,
    required this.companyNameController,
    required this.clientCodeController,
    required this.addressController,
    required this.merchantTier,
    required this.onTierChanged,
    required this.selectedState,
    required this.onStateChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statesList = {...NigeriaLocations.states}.toList();
    final effectiveState =
        statesList.contains(selectedState) ? selectedState : 'FCT - Abuja';
    final citiesList = {
      ...NigeriaLocations.getCitiesForState(effectiveState),
    }.toList();
    final effectiveCity = citiesList.contains(selectedCity)
        ? selectedCity
        : (citiesList.isNotEmpty ? citiesList.first : 'Wuse 2');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoBanner(
          icon: Icons.storefront_rounded,
          color: Color(0xFFD97706),
          text:
              'Provision a dedicated Merchant Portal with SKU catalog management, order tracking, closers desk, and automated COD remittances.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Company / Store Brand Name *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_company_name'),
          controller: companyNameController,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. Emerald Herbals Limited',
            icon: Icons.business_rounded,
          ),
          validator: (v) {
            if (v == null || v.trim().length < 2) {
              return 'Enter your registered company or brand name';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Merchant Tier'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _SelectableOptionChip(
              label: 'Standard Logistics Merchant',
              isSelected: merchantTier == 'standard_merchant',
              onTap: () => onTierChanged('standard_merchant'),
            ),
            _SelectableOptionChip(
              label: 'Enterprise (Closers & Multi-Hub)',
              isSelected: merchantTier == 'enterprise',
              onTap: () => onTierChanged('enterprise'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Preferred Merchant Code (Optional)'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_client_code'),
          controller: clientCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(
            context,
            hint: 'Auto-generated if left blank (e.g. CLI-EMR-01)',
            icon: Icons.tag_rounded,
          ),
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Business State *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: Key('reg_merchant_state_$effectiveState'),
          initialValue: effectiveState,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select State',
            icon: Icons.map_outlined,
          ),
          items: statesList
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onStateChanged(val);
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'City / LGA *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: Key('reg_merchant_city_${effectiveState}_$effectiveCity'),
          initialValue: effectiveCity,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select City / LGA',
            icon: Icons.location_city_rounded,
          ),
          items: citiesList
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onCityChanged(val);
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Warehouse / Office Street Address *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_merchant_address'),
          controller: addressController,
          maxLines: 2,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. Suite 12 Plot 405 Aminu Kano Crescent, Wuse 2',
            icon: Icons.place_outlined,
          ),
          validator: (v) {
            if (v == null || v.trim().length < 5) {
              return 'Enter your business street address (at least 5 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class DcHubAssignmentStep extends StatelessWidget {
  final RegistrationAccountType role;
  final List<DistributionCenter> dcs;
  final bool loadingDcs;
  final String? dcsError;
  final VoidCallback onRetryDcs;
  final String? selectedDcId;
  final ValueChanged<DistributionCenter?> onDcChanged;
  final TextEditingController assignedZoneController;
  final TextEditingController staffCodeController;

  const DcHubAssignmentStep({
    super.key,
    required this.role,
    required this.dcs,
    required this.loadingDcs,
    this.dcsError,
    required this.onRetryDcs,
    required this.selectedDcId,
    required this.onDcChanged,
    required this.assignedZoneController,
    required this.staffCodeController,
  });

  List<String> _suggestedDesks(DistributionCenter? dc) {
    final defaults = switch (role) {
      RegistrationAccountType.dcOperations => const [
          'Inbound Dispatch Desk',
          'Route Assignment Bay',
          'Express Rider Control',
        ],
      RegistrationAccountType.dcStockAdmin => const [
          'Main Shelf Custody',
          'Inbound & Returns Bay',
          'Courier Allocation Vault',
        ],
      RegistrationAccountType.dcFinanceAdmin => const [
          'Daily Remittance Desk',
          'Cash Vault & POS Clearing',
          'Merchant Settlement Review',
        ],
      RegistrationAccountType.dcManager => const [
          'Hub Operations Command',
          'Regional Hub Oversight',
        ],
      RegistrationAccountType.generalAccountant => const [
          'National Treasury Desk',
          'Inter-DC Reconciliation',
          'Corporate Audit & Tax',
        ],
      _ => const ['Operations Desk'],
    };

    final dcZones = (dc?.operatingZones ?? const <String>[])
        .where((z) => !z.startsWith('STATE:') && z.trim().isNotEmpty)
        .take(3);

    return {...defaults, ...dcZones}.toList();
  }

  String _sectorFieldLabel() {
    switch (role) {
      case RegistrationAccountType.dcOperations:
        return 'Primary Dispatch Sector / Desk *';
      case RegistrationAccountType.dcStockAdmin:
        return 'Warehouse Custody Bay / Sector *';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'Finance & Cash Vault Desk *';
      case RegistrationAccountType.dcManager:
        return 'Command Jurisdiction / Hub Scope *';
      case RegistrationAccountType.generalAccountant:
        return 'National Treasury & Audit Division *';
      default:
        return 'Assigned Desk / Sector *';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDc = dcs.where((d) => d.id == selectedDcId).firstOrNull;
    final suggestions = _suggestedDesks(selectedDc);
    final visuals = RegistrationRoleVisuals.of(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBanner(
          icon: visuals.icon,
          color: visuals.color,
          text:
              'Every ${role.title} is scoped to an active Distribution Center so orders, stock ledgers, and cash vaults sync to the right hub.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Assigned Distribution Center *'),
        const SizedBox(height: 6),
        _DcSelectorField(
          role: role,
          dcs: dcs,
          isLoading: loadingDcs,
          errorMessage: dcsError,
          selectedDcId: selectedDcId,
          onRetry: onRetryDcs,
          onChanged: onDcChanged,
        ),

        if (selectedDc != null) ...[
          const SizedBox(height: 12),
          _SelectedDcBanner(dc: selectedDc),
        ],

        const SizedBox(height: 16),
        _FieldLabel(text: _sectorFieldLabel()),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_assigned_zone'),
          controller: assignedZoneController,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. ${suggestions.first}',
            icon: Icons.workspaces_outline,
          ),
          validator: (v) {
            if (v == null || v.trim().length < 2) {
              return 'Specify or tap a desk / sector for this role';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: suggestions.map((item) {
            return InkWell(
              onTap: () => assignedZoneController.text = item,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: visuals.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: visuals.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: visuals.color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        const _FieldLabel(text: 'Preferred Staff / Officer Code (Optional)'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_staff_code'),
          controller: staffCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(
            context,
            hint: 'Auto-generated if left blank (e.g. ${role.badge}-101)',
            icon: Icons.badge_outlined,
          ),
        ),
      ],
    );
  }
}

class FleetAndVehicleStep extends StatelessWidget {
  final RegistrationAccountType role;
  final List<DistributionCenter> dcs;
  final bool loadingDcs;
  final String? dcsError;
  final VoidCallback onRetryDcs;
  final String? selectedDcId;
  final ValueChanged<DistributionCenter?> onDcChanged;
  final String personnelType;
  final ValueChanged<String> onPersonnelTypeChanged;
  final String? selectedZone;
  final ValueChanged<String?> onZoneChanged;
  final String vehicleType;
  final ValueChanged<String> onVehicleTypeChanged;
  final TextEditingController vehiclePlateController;

  const FleetAndVehicleStep({
    super.key,
    required this.role,
    required this.dcs,
    required this.loadingDcs,
    this.dcsError,
    required this.onRetryDcs,
    required this.selectedDcId,
    required this.onDcChanged,
    required this.personnelType,
    required this.onPersonnelTypeChanged,
    required this.selectedZone,
    required this.onZoneChanged,
    required this.vehicleType,
    required this.onVehicleTypeChanged,
    required this.vehiclePlateController,
  });

  List<String> _buildZoneOptions(DistributionCenter? dc) {
    final dcZones = (dc?.operatingZones ?? const <String>[])
        .where((z) => !z.startsWith('STATE:') && z.trim().isNotEmpty)
        .map((z) => z.trim())
        .toList();
    final stateCities = NigeriaLocations.getCitiesForState(
      dc?.state ?? 'FCT - Abuja',
    );
    final combined = {
      ...dcZones,
      ...stateCities,
      if (dc != null && dc.city.trim().isNotEmpty) dc.city.trim(),
    }.toList();
    if (combined.isEmpty) {
      return const ['Central Hub Zone'];
    }
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDc = dcs.where((d) => d.id == selectedDcId).firstOrNull;
    final zoneOptions = _buildZoneOptions(selectedDc);
    final validZone =
        zoneOptions.contains(selectedZone) ? selectedZone : zoneOptions.first;
    final vehicleOptions = {...registrationVehicleTypes}.toList();
    final validVehicle = vehicleOptions.contains(vehicleType)
        ? vehicleType
        : vehicleOptions.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoBanner(
          icon: Icons.two_wheeler_rounded,
          color: Color(0xFF6D28D9),
          text:
              'Field Delivery Agents & PDAs must select a home Distribution Center, coverage zone, fleet tier, and vehicle plate number for dispatch assignment.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Home Distribution Center *'),
        const SizedBox(height: 6),
        _DcSelectorField(
          role: role,
          dcs: dcs,
          isLoading: loadingDcs,
          errorMessage: dcsError,
          selectedDcId: selectedDcId,
          onRetry: onRetryDcs,
          onChanged: onDcChanged,
        ),

        if (selectedDc != null) ...[
          const SizedBox(height: 10),
          _SelectedDcBanner(dc: selectedDc),
        ],

        const SizedBox(height: 16),
        const _FieldLabel(text: 'Fleet Classification *'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _SelectableOptionChip(
              label: 'PDA (Own Vehicle • ₦1,000 Comm)',
              isSelected: personnelType == 'pda',
              onTap: () => onPersonnelTypeChanged('pda'),
            ),
            _SelectableOptionChip(
              label: 'In-House Rider (Company Fleet)',
              isSelected: personnelType == 'in_house_rider',
              onTap: () => onPersonnelTypeChanged('in_house_rider'),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const _FieldLabel(text: 'Primary Coverage Zone / LGA *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: Key('reg_zone_dd_${selectedDc?.id ?? "none"}_$validZone'),
          initialValue: validZone,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select Coverage Zone',
            icon: Icons.my_location_rounded,
          ),
          items: zoneOptions
              .map(
                (z) => DropdownMenuItem<String>(
                  value: z,
                  child: Text(z, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onZoneChanged,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Select a coverage zone' : null,
        ),

        const SizedBox(height: 16),
        const _FieldLabel(text: 'Vehicle Category *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: Key('reg_vehicle_type_$validVehicle'),
          initialValue: validVehicle,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select Vehicle Type',
            icon: Icons.directions_bike_rounded,
          ),
          items: vehicleOptions
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onVehicleTypeChanged(val);
          },
        ),

        const SizedBox(height: 14),
        const _FieldLabel(text: 'Vehicle Registration / Plate Number *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_vehicle_plate'),
          controller: vehiclePlateController,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. ABJ-492-XB',
            icon: Icons.subtitles_outlined,
          ),
          validator: (v) {
            if (v == null || v.trim().length < 4) {
              return 'Enter your vehicle plate / registration number';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class IdentityCredentialsStep extends StatelessWidget {
  final RegistrationAccountType role;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final bool? emailAvailable;
  final bool checkingEmail;
  final ValueChanged<String> onEmailChanged;
  final bool? phoneAvailable;
  final bool checkingPhone;
  final ValueChanged<String> onPhoneChanged;
  final Widget? finalSummaryWidget;

  const IdentityCredentialsStep({
    super.key,
    required this.role,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleObscurePassword,
    required this.emailAvailable,
    required this.checkingEmail,
    required this.onEmailChanged,
    required this.phoneAvailable,
    required this.checkingPhone,
    required this.onPhoneChanged,
    this.finalSummaryWidget,
  });

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCol = constraints.maxWidth >= 520;
            final firstField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(text: 'First Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('reg_first_name'),
                  controller: firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    context,
                    hint: 'e.g. Amaka',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Enter first name';
                    }
                    return null;
                  },
                ),
              ],
            );
            final lastField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(text: 'Last Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('reg_last_name'),
                  controller: lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    context,
                    hint: 'e.g. Okafor',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Enter last name';
                    }
                    return null;
                  },
                ),
              ],
            );

            if (!twoCol) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  firstField,
                  const SizedBox(height: 14),
                  lastField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firstField),
                const SizedBox(width: 12),
                Expanded(child: lastField),
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Official Email Address *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_email'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: onEmailChanged,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. name@novaxpress.ng',
            icon: Icons.email_outlined,
            suffix: checkingEmail
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (emailAvailable == true
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      )
                    : (emailAvailable == false
                        ? const Icon(
                            Icons.error_rounded,
                            color: AppColors.danger,
                            size: 20,
                          )
                        : null)),
          ),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (clean.isEmpty || !_emailRegex.hasMatch(clean)) {
              return 'Enter a valid email address';
            }
            if (emailAvailable == false) {
              return 'This email is already registered';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'WhatsApp / Mobile Phone *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_phone'),
          controller: phoneController,
          keyboardType: TextInputType.phone,
          onChanged: onPhoneChanged,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. 08031234567 or +2348031234567',
            icon: Icons.phone_outlined,
            suffix: checkingPhone
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (phoneAvailable == true
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      )
                    : (phoneAvailable == false
                        ? const Icon(
                            Icons.error_rounded,
                            color: AppColors.danger,
                            size: 20,
                          )
                        : null)),
          ),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length < 10 || digits.length > 14) {
              return 'Enter a valid phone number (10-14 digits)';
            }
            if (phoneAvailable == false) {
              return 'Phone number is already registered';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Account Password *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_password'),
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: _fieldDecoration(
            context,
            hint: 'Minimum 6 characters',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: onToggleObscurePassword,
            ),
          ),
          validator: (v) {
            if (v == null || v.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Confirm Password *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_confirm_password'),
          controller: confirmPasswordController,
          obscureText: obscurePassword,
          decoration: _fieldDecoration(
            context,
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return 'Please confirm your password';
            }
            if (v != passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),

        if (finalSummaryWidget != null) ...[
          const SizedBox(height: 18),
          finalSummaryWidget!,
        ],
      ],
    );
  }
}

class PayoutBankAndReviewStep extends StatelessWidget {
  final RegistrationAccountType role;
  final String? selectedBankName;
  final ValueChanged<String?> onBankChanged;
  final TextEditingController bankAccountNoController;
  final TextEditingController bankAccountNameController;
  final Widget finalSummaryWidget;

  const PayoutBankAndReviewStep({
    super.key,
    required this.role,
    required this.selectedBankName,
    required this.onBankChanged,
    required this.bankAccountNoController,
    required this.bankAccountNameController,
    required this.finalSummaryWidget,
  });

  bool get _anyBankStarted =>
      (selectedBankName != null && selectedBankName!.trim().isNotEmpty) ||
      bankAccountNoController.text.trim().isNotEmpty ||
      bankAccountNameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final banks = {...registrationNigerianBanks}.toList();
    final validBank =
        (selectedBankName != null && banks.contains(selectedBankName))
            ? selectedBankName
            : null;
    final isMerchant = role == RegistrationAccountType.client;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBanner(
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF16A34A),
          text: isMerchant
              ? 'Optional during signup — add your Nigerian bank account now to receive automated COD settlements, or configure later inside Merchant Profile.'
              : 'Optional during signup — link your Nigerian settlement bank for monthly salary & commission payouts, or update later in Profile.',
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Settlement Bank Name (Optional)'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          key: Key('reg_bank_name_${validBank ?? "none"}'),
          initialValue: validBank,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select Receiving Bank (Optional)',
            icon: Icons.account_balance_outlined,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Skip for now / Configure later'),
            ),
            ...banks.map(
              (b) => DropdownMenuItem<String?>(
                value: b,
                child: Text(b, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onBankChanged,
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: '10-Digit NUBAN Account Number'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_bank_number'),
          controller: bankAccountNoController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. 0123456789',
            icon: Icons.credit_card_rounded,
          ).copyWith(counterText: ''),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (!_anyBankStarted && clean.isEmpty) return null;
            if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
              return 'Enter a valid 10-digit NUBAN account number';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Account Beneficiary Name'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_bank_account_name'),
          controller: bankAccountNameController,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            context,
            hint: isMerchant
                ? 'Registered company / account name'
                : 'Your bank account holder name',
            icon: Icons.person_pin_outlined,
          ),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (!_anyBankStarted && clean.isEmpty) return null;
            if (clean.length < 2) {
              return 'Enter the bank account holder name';
            }
            return null;
          },
        ),

        const SizedBox(height: 18),
        finalSummaryWidget,
      ],
    );
  }
}

class RiderCompensationBankAndReviewStep extends StatelessWidget {
  final String personnelType;
  final String compensationType;
  final ValueChanged<String> onCompensationTypeChanged;
  final String? selectedBankName;
  final ValueChanged<String?> onBankChanged;
  final TextEditingController bankAccountNoController;
  final TextEditingController bankAccountNameController;
  final Widget finalSummaryWidget;

  const RiderCompensationBankAndReviewStep({
    super.key,
    required this.personnelType,
    required this.compensationType,
    required this.onCompensationTypeChanged,
    required this.selectedBankName,
    required this.onBankChanged,
    required this.bankAccountNoController,
    required this.bankAccountNameController,
    required this.finalSummaryWidget,
  });

  String _ratePreview() {
    final isPda = personnelType == 'pda';
    if (isPda) {
      return 'PDA Standard: ₦1,000/delivery • ₦1,500 transport allowance • ₦500 failed attempt';
    }
    switch (compensationType) {
      case 'salary':
        return 'In-House Salary: ₦120,000/month base • ₦800/day fuel allowance';
      case 'hybrid':
        return 'In-House Hybrid: ₦85,000 base + ₦500/delivery + ₦800/day fuel';
      default:
        return 'In-House Commission: ₦500/delivery • ₦800 fuel • ₦300 failed attempt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banks = {...registrationNigerianBanks}.toList();
    final validBank =
        (selectedBankName != null && banks.contains(selectedBankName))
            ? selectedBankName
            : banks.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Compensation Plan *'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SelectableOptionChip(
              label: 'Commission Per Delivery',
              isSelected: compensationType == 'commission',
              onTap: () => onCompensationTypeChanged('commission'),
            ),
            if (personnelType == 'in_house_rider') ...[
              _SelectableOptionChip(
                label: 'Fixed Monthly Salary',
                isSelected: compensationType == 'salary',
                onTap: () => onCompensationTypeChanged('salary'),
              ),
              _SelectableOptionChip(
                label: 'Hybrid (Salary + Bonus)',
                isSelected: compensationType == 'hybrid',
                onTap: () => onCompensationTypeChanged('hybrid'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _ratePreview(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFF166534),
            ),
          ),
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Payout Bank Name *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: Key('reg_rider_bank_name_$validBank'),
          initialValue: validBank,
          isExpanded: true,
          decoration: _fieldDecoration(
            context,
            hint: 'Select Payout Bank',
            icon: Icons.account_balance_rounded,
          ),
          items: banks
              .map(
                (b) => DropdownMenuItem<String>(
                  value: b,
                  child: Text(b, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onBankChanged,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Select your payout bank' : null,
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: '10-Digit NUBAN Account Number *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_bank_number'),
          controller: bankAccountNoController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: _fieldDecoration(
            context,
            hint: 'e.g. 0123456789',
            icon: Icons.credit_card_rounded,
          ).copyWith(counterText: ''),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
              return 'Enter a valid 10-digit NUBAN account number';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        const _FieldLabel(text: 'Account Holder Name *'),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('reg_bank_account_name'),
          controller: bankAccountNameController,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            context,
            hint: 'Beneficiary full name',
            icon: Icons.person_pin_outlined,
          ),
          validator: (v) {
            if (v == null || v.trim().length < 2) {
              return 'Account holder name is required for rider payouts';
            }
            return null;
          },
        ),

        const SizedBox(height: 18),
        finalSummaryWidget,
      ],
    );
  }
}

class RegistrationFinalSummaryCard extends StatelessWidget {
  final RegistrationAccountType role;
  final String fullName;
  final String email;
  final String phone;
  final String? partnerMerchantLabel;
  final String? merchantBrandLabel;
  final String? dcLabel;
  final String? zoneOrDeskLabel;
  final String? vehicleLabel;
  final String? bankSummaryLabel;

  const RegistrationFinalSummaryCard({
    super.key,
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    this.partnerMerchantLabel,
    this.merchantBrandLabel,
    this.dcLabel,
    this.zoneOrDeskLabel,
    this.vehicleLabel,
    this.bankSummaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visuals = RegistrationRoleVisuals.of(role);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visuals.color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 18,
                color: visuals.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Account Provisioning Summary',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Account Type', value: role.title),
          _SummaryRow(
            label: 'Workspace Console',
            value: role.targetConsoleLabel,
          ),
          if (fullName.trim().isNotEmpty)
            _SummaryRow(label: 'Full Name', value: fullName.trim()),
          if (email.trim().isNotEmpty)
            _SummaryRow(label: 'Email Login', value: email.trim()),
          if (phone.trim().isNotEmpty)
            _SummaryRow(label: 'Phone', value: phone.trim()),
          if (partnerMerchantLabel != null &&
              partnerMerchantLabel!.isNotEmpty)
            _SummaryRow(
              label: 'Partner Merchant',
              value: partnerMerchantLabel!,
            ),
          if (merchantBrandLabel != null && merchantBrandLabel!.isNotEmpty)
            _SummaryRow(label: 'Brand Profile', value: merchantBrandLabel!),
          if (dcLabel != null && dcLabel!.isNotEmpty)
            _SummaryRow(label: 'Distribution Center', value: dcLabel!),
          if (zoneOrDeskLabel != null && zoneOrDeskLabel!.isNotEmpty)
            _SummaryRow(label: 'Sector / Zone', value: zoneOrDeskLabel!),
          if (vehicleLabel != null && vehicleLabel!.isNotEmpty)
            _SummaryRow(label: 'Fleet & Vehicle', value: vehicleLabel!),
          if (bankSummaryLabel != null && bankSummaryLabel!.isNotEmpty)
            _SummaryRow(label: 'Settlement Bank', value: bankSummaryLabel!),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantSelectorField extends StatelessWidget {
  final RegistrationAccountType role;
  final List<RegistrationMerchantOption> merchants;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedClientId;
  final VoidCallback onRetry;
  final ValueChanged<RegistrationMerchantOption?> onChanged;

  const _MerchantSelectorField({
    required this.role,
    required this.merchants,
    required this.isLoading,
    required this.errorMessage,
    required this.selectedClientId,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && merchants.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Loading active Partner Merchants...')),
          ],
        ),
      );
    }

    if (merchants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage ?? 'Unable to load Partner Merchants.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
            TextButton(
              key: const Key('reg_retry_merchants'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final validId = merchants.any((m) => m.id == selectedClientId)
        ? selectedClientId
        : null;

    return DropdownButtonFormField<String>(
      key: Key(
        'reg_merchant_dropdown_${role.roleKey}_${validId ?? "none"}_${merchants.length}',
      ),
      initialValue: validId,
      isExpanded: true,
      decoration: _fieldDecoration(
        context,
        hint: 'Choose Partner Merchant...',
        icon: Icons.store_mall_directory_outlined,
      ),
      items: merchants
          .map(
            (m) => DropdownMenuItem<String>(
              value: m.id,
              child: Text(
                '${m.name} (${m.code})${m.city.isNotEmpty ? ' • ${m.city}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        final matched = merchants.where((m) => m.id == id).firstOrNull;
        onChanged(matched);
      },
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Please select your Partner Merchant' : null,
    );
  }
}

class _DcSelectorField extends StatelessWidget {
  final RegistrationAccountType role;
  final List<DistributionCenter> dcs;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedDcId;
  final VoidCallback onRetry;
  final ValueChanged<DistributionCenter?> onChanged;

  const _DcSelectorField({
    required this.role,
    required this.dcs,
    required this.isLoading,
    required this.errorMessage,
    required this.selectedDcId,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && dcs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Loading active Distribution Centers...')),
          ],
        ),
      );
    }

    if (dcs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage ?? 'Unable to load Distribution Centers.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
            TextButton(
              key: const Key('reg_retry_dcs'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final validId = dcs.any((d) => d.id == selectedDcId) ? selectedDcId : null;

    return DropdownButtonFormField<String>(
      key: Key(
        'reg_dc_dropdown_${role.roleKey}_${validId ?? "none"}_${dcs.length}',
      ),
      initialValue: validId,
      isExpanded: true,
      decoration: _fieldDecoration(
        context,
        hint: 'Choose Distribution Center...',
        icon: Icons.apartment_rounded,
      ),
      items: dcs
          .map(
            (dc) => DropdownMenuItem<String>(
              value: dc.id,
              child: Text(
                '${dc.name} (${dc.code}) • ${dc.state}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        final matched = dcs.where((d) => d.id == id).firstOrNull;
        onChanged(matched);
      },
      validator: (v) => (v == null || v.isEmpty)
          ? 'Please select an assigned Distribution Center'
          : null,
    );
  }
}

class _SelectedDcBanner extends StatelessWidget {
  final DistributionCenter dc;

  const _SelectedDcBanner({required this.dc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                dc.name,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dc.dcTierLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dc.address} • Covers: ${dc.effectiveCoveredStates.join(', ')}',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.38,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF181C1E),
      ),
    );
  }
}

class _SelectableOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orange.withValues(alpha: isDark ? 0.22 : 0.11)
              : (isDark ? AppColors.cardDark : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.orange
                : (isDark
                    ? AppColors.borderDark
                    : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: isSelected
                  ? AppColors.orange
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.2,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
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

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13,
      color: isDark ? AppColors.textMuted : const Color(0xFF75777E),
    ),
    filled: true,
    fillColor: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    prefixIcon: Icon(
      icon,
      size: 19,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    ),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isDark ? AppColors.orange : AppColors.navy,
        width: 1.8,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

