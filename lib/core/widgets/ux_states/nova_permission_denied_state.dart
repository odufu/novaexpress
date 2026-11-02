import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LogisticsPermissionType {
  location,
  camera,
  storage,
  notifications,
}

/// State 7: Permission Denied State
/// Explains why permissions are essential to logistics execution and
/// provides actionable recovery (Grant, Device Settings).
class NovaPermissionDeniedState extends StatelessWidget {
  final LogisticsPermissionType permissionType;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onGrantPermission;
  final VoidCallback? onOpenSettings;
  final String? customReason;

  const NovaPermissionDeniedState({
    super.key,
    required this.permissionType,
    this.onRequestPermission,
    this.onGrantPermission,
    this.onOpenSettings,
    this.customReason,
  });

  /// Factory for Location permission
  factory NovaPermissionDeniedState.location({
    VoidCallback? onRequestPermission,
    VoidCallback? onGrantPermission,
    VoidCallback? onOpenSettings,
  }) {
    return NovaPermissionDeniedState(
      permissionType: LogisticsPermissionType.location,
      onRequestPermission: onRequestPermission,
      onGrantPermission: onGrantPermission,
      onOpenSettings: onOpenSettings,
    );
  }

  /// Factory for Camera barcode/POD permission
  factory NovaPermissionDeniedState.camera({
    VoidCallback? onRequestPermission,
    VoidCallback? onGrantPermission,
    VoidCallback? onOpenSettings,
  }) {
    return NovaPermissionDeniedState(
      permissionType: LogisticsPermissionType.camera,
      onRequestPermission: onRequestPermission,
      onGrantPermission: onGrantPermission,
      onOpenSettings: onOpenSettings,
    );
  }

  /// Factory for Storage / Waybill export permission
  factory NovaPermissionDeniedState.storage({
    VoidCallback? onRequestPermission,
    VoidCallback? onGrantPermission,
    VoidCallback? onOpenSettings,
  }) {
    return NovaPermissionDeniedState(
      permissionType: LogisticsPermissionType.storage,
      onRequestPermission: onRequestPermission,
      onGrantPermission: onGrantPermission,
      onOpenSettings: onOpenSettings,
    );
  }

  /// Factory for Notification permission
  factory NovaPermissionDeniedState.notifications({
    VoidCallback? onRequestPermission,
    VoidCallback? onGrantPermission,
    VoidCallback? onOpenSettings,
  }) {
    return NovaPermissionDeniedState(
      permissionType: LogisticsPermissionType.notifications,
      onRequestPermission: onRequestPermission,
      onGrantPermission: onGrantPermission,
      onOpenSettings: onOpenSettings,
    );
  }

  _PermissionConfig _getConfig() {
    switch (permissionType) {
      case LogisticsPermissionType.location:
        return _PermissionConfig(
          icon: Icons.location_off_rounded,
          title: 'GPS Location Access Required',
          description: customReason ??
              'Accurate GPS location is required for delivery waypoint tracking, proximity rider dispatch, and calculating live route ETA for customer orders.',
          benefitList: [
            'Rider navigation and route optimization',
            'Proximity dispatch assignment',
            'Live recipient arrival alerts',
          ],
          accentColor: const Color(0xFF3B82F6),
        );
      case LogisticsPermissionType.camera:
        return _PermissionConfig(
          icon: Icons.no_photography_rounded,
          title: 'Camera Permission Required',
          description: customReason ??
              'Scan waybill barcodes and photograph Proof of Delivery customer signatures to document parcel handover.',
          benefitList: [
            'Scan waybill QR & barcodes in real time',
            'Capture recipient photo proof upon delivery',
            'Attach parcel intake condition photos',
          ],
          accentColor: const Color(0xFF10B981),
        );
      case LogisticsPermissionType.storage:
        return _PermissionConfig(
          icon: Icons.folder_off_rounded,
          title: 'Storage Access Required',
          description: customReason ??
              'Storage access is required to download and print PDF waybills, shipping labels, and distribution manifests.',
          benefitList: [
            'Export delivery run sheets and manifests',
            'Save offline order caches',
            'Download merchant payment receipts',
          ],
          accentColor: const Color(0xFF8B5CF6),
        );
      case LogisticsPermissionType.notifications:
        return _PermissionConfig(
          icon: Icons.notifications_off_rounded,
          title: 'Notification Access Recommended',
          description: customReason ??
              'Stay updated on incoming dispatch assignments, delivery status changes, and cash remittance approvals.',
          benefitList: [
            'Instant dispatch alerts for new orders',
            'Customer order cancellation notices',
            'Remittance reconciliation confirmations',
          ],
          accentColor: const Color(0xFFF59E0B),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = _getConfig();
    final effectiveReq = onGrantPermission ?? onRequestPermission;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: config.accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: config.accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    config.icon,
                    size: 34,
                    color: config.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                config.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 18),

              // Why this is needed card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHY THIS MATTERS FOR LOGISTICS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...config.benefitList.map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                                    if (effectiveReq != null)
                    ElevatedButton.icon(
                      onPressed: effectiveReq,
                      icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Grant Permission',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config.accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  if (onOpenSettings != null)
                    OutlinedButton.icon(
                      onPressed: onOpenSettings,
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      label: Text(
                        'Open App Settings',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionConfig {
  final IconData icon;
  final String title;
  final String description;
  final List<String> benefitList;
  final Color accentColor;

  _PermissionConfig({
    required this.icon,
    required this.title,
    required this.description,
    required this.benefitList,
    required this.accentColor,
  });
}

