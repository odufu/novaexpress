import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';

class AdminAppSettingsTab extends ConsumerStatefulWidget {
  const AdminAppSettingsTab({super.key});

  @override
  ConsumerState<AdminAppSettingsTab> createState() => _AdminAppSettingsTabState();
}

class _AdminAppSettingsTabState extends ConsumerState<AdminAppSettingsTab> {
  late bool _mandatorySignature;
  late bool _mandatoryPhoto;
  late bool _allowOtpFallback;
  late bool _requireFailureVoiceNote;
  late double _upgAutoApproveLimit;
  late double _maxRiderCashHolding;
  late int _voiceNoteMaxSeconds;
  late bool _enableLiveGps;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(adminConsoleProvider).appSettings;
    _mandatorySignature = settings.mandatorySignature;
    _mandatoryPhoto = settings.mandatoryPhoto;
    _allowOtpFallback = settings.allowOtpFallback;
    _requireFailureVoiceNote = settings.requireFailureVoiceNote;
    _upgAutoApproveLimit = settings.upgAutoApproveLimit;
    _maxRiderCashHolding = settings.maxRiderCashHolding;
    _voiceNoteMaxSeconds = settings.voiceNoteMaxSeconds;
    _enableLiveGps = settings.enableLiveGpsTracking;
  }

  void _save() {
    final newSettings = AdminAppSettings(
      mandatorySignature: _mandatorySignature,
      mandatoryPhoto: _mandatoryPhoto,
      allowOtpFallback: _allowOtpFallback,
      requireFailureVoiceNote: _requireFailureVoiceNote,
      upgAutoApproveLimit: _upgAutoApproveLimit,
      maxRiderCashHolding: _maxRiderCashHolding,
      voiceNoteMaxSeconds: _voiceNoteMaxSeconds,
      enableLiveGpsTracking: _enableLiveGps,
    );

    ref.read(adminConsoleProvider.notifier).updateAppSettings(newSettings);
    setState(() => _hasChanges = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Operational policies successfully updated across all client apps.', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Save Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational & App Policies',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Govern mobile field app behavior, verification constraints, and risk thresholds',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _hasChanges ? _save : null,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text('Save Policies', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 1: Electronic Proof of Delivery (e-POD)
            _buildSectionCard(
              title: 'Electronic Proof of Delivery (e-POD)',
              icon: Icons.draw_rounded,
              isDark: isDark,
              children: [
                _buildToggleRow(
                  title: 'Mandatory Customer Signature',
                  subtitle: 'Rider must capture digital stylus or fingertip signature before marking Delivered',
                  tooltip: 'Strictly locks the "Confirm POD" button until the customer enters signature on modal canvas',
                  value: _mandatorySignature,
                  onChanged: (v) => setState(() {
                    _mandatorySignature = v;
                    _hasChanges = true;
                  }),
                ),
                const Divider(height: 24),
                _buildToggleRow(
                  title: 'Mandatory Doorstep Photo Proof',
                  subtitle: 'Require delivery agent to snap package at doorstep / recipient location',
                  tooltip: 'Uploaded instantly to cloud storage for dispute resolution against false delivery claims',
                  value: _mandatoryPhoto,
                  onChanged: (v) => setState(() {
                    _mandatoryPhoto = v;
                    _hasChanges = true;
                  }),
                ),
                const Divider(height: 24),
                _buildToggleRow(
                  title: 'Allow OTP SMS Fallback',
                  subtitle: 'Enable 4-digit SMS OTP verification when signature screen is physically obstructed',
                  tooltip: 'Sends automatic OTP to recipient phone via Termii SMS gateway as legal POD equivalent',
                  value: _allowOtpFallback,
                  onChanged: (v) => setState(() {
                    _allowOtpFallback = v;
                    _hasChanges = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Delivery Failure & Fraud Prevention
            _buildSectionCard(
              title: 'Exception & Fraud Mitigation Protocols',
              icon: Icons.shield_outlined,
              isDark: isDark,
              children: [
                _buildToggleRow(
                  title: 'Mandatory Audio Note for Delivery Failures',
                  subtitle: 'Rider must record a short explanation before submitting failed delivery',
                  tooltip: 'Prevents riders from falsely logging failures without attempting contact with customer',
                  value: _requireFailureVoiceNote,
                  onChanged: (v) => setState(() {
                    _requireFailureVoiceNote = v;
                    _hasChanges = true;
                  }),
                ),
                const Divider(height: 24),
                _buildSliderRow(
                  title: 'Maximum Rider Cash-in-Transit (COD Ceiling)',
                  subtitle: 'Forces rider to return to DC vault once collected cash hits this threshold',
                  tooltip: 'Prevents robbery or financial leakage by capping cash held on field motorbikes',
                  value: _maxRiderCashHolding,
                  min: 50000,
                  max: 500000,
                  divisions: 9,
                  format: (v) => CurrencyFormatter.formatNaira(v),
                  onChanged: (v) => setState(() {
                    _maxRiderCashHolding = v;
                    _hasChanges = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Package Deals & Telesales UPG Rules
            _buildSectionCard(
              title: 'Package Deals & UPG Auto-Approval Threshold',
              icon: Icons.inventory_outlined,
              isDark: isDark,
              children: [
                _buildSliderRow(
                  title: 'Auto-Approve Closer Package Deals (UPG)',
                  subtitle: 'Upsell deals up to this amount auto-apply without requiring Supervisor signoff',
                  tooltip: 'Allows closers to accelerate order fulfillment; values above this trigger supervisor queue',
                  value: _upgAutoApproveLimit,
                  min: 5000,
                  max: 50000,
                  divisions: 9,
                  format: (v) => CurrencyFormatter.formatNaira(v),
                  onChanged: (v) => setState(() {
                    _upgAutoApproveLimit = v;
                    _hasChanges = true;
                  }),
                ),
                const Divider(height: 24),
                _buildToggleRow(
                  title: 'Continuous High-Precision GPS Telemetry',
                  subtitle: 'Stream real-time rider coordinates to DC dispatcher map every 15 seconds',
                  tooltip: 'Uses low-power background location service on rider mobile units',
                  value: _enableLiveGps,
                  onChanged: (v) => setState(() {
                    _enableLiveGps = v;
                    _hasChanges = true;
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.orange),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required String tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  NovaInfoIcon(message: tooltip),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppColors.orange,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String subtitle,
    required String tooltip,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                NovaInfoIcon(message: tooltip),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                format(value),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.orange,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
