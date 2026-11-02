import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 1: Empty State
/// Displays structured, branded guidance before data exists,
/// preventing blank, unfinished-looking logistics interfaces.
class NovaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Color? accentColor;
  final Widget? customIllustration;

  const NovaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.accentColor,
    this.customIllustration,
  });

  /// Factory for empty shipment / orders screen
  factory NovaEmptyState.orders({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.local_shipping_outlined,
      title: title ?? 'No Orders Dispatched Yet',
      message: message ??
          customMessage ??
          'There are no customer delivery orders recorded yet. Book a new shipment or sync orders from connected sales channels.',
      actionLabel: actionLabel ?? 'Book Shipment',
      onAction: onAction,
      accentColor: const Color(0xFFF37021),
    );
  }

  /// Factory for empty delivery routes / pda assignment screen
  factory NovaEmptyState.routes({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.alt_route_rounded,
      title: title ?? 'No Delivery Routes Active',
      message: message ??
          customMessage ??
          'No delivery runs are currently scheduled for this zone. Dispatch inbound packages or wait for automated route clustering.',
      actionLabel: actionLabel ?? 'Assign Route',
      onAction: onAction,
      accentColor: const Color(0xFF3B82F6),
    );
  }

  /// Factory for empty financial remittances / cash collections
  factory NovaEmptyState.remittances({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: title ?? 'Remittances Reconciled',
      message: message ??
          customMessage ??
          'All rider cash-on-delivery collections and client payouts are currently up to date. New transactions will generate settlement sheets automatically.',
      actionLabel: actionLabel ?? 'Refresh Ledger',
      onAction: onAction,
      accentColor: const Color(0xFF0F766E),
    );
  }

  /// Factory for empty inventory / warehouse stock
  factory NovaEmptyState.inventory({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.inventory_2_outlined,
      title: title ?? 'Warehouse Stock Empty',
      message: message ??
          customMessage ??
          'No inventory items have been received or allocated to this distribution center yet. Log incoming consignments to begin tracking stock custody.',
      actionLabel: actionLabel ?? 'Receive Stock',
      onAction: onAction,
      accentColor: const Color(0xFF8B5CF6),
    );
  }

  /// Factory for empty staff / fleet riders / personnel
  factory NovaEmptyState.staff({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.people_outline_rounded,
      title: title ?? 'No Staff Registered',
      message: message ??
          customMessage ??
          'No personnel are currently attached to this distribution facility. Onboard station officers or riders to activate dispatch operations.',
      actionLabel: actionLabel ?? 'Onboard Staff',
      onAction: onAction,
      accentColor: const Color(0xFF10B981),
    );
  }

  /// Factory for empty notifications inbox
  factory NovaEmptyState.notifications({
    VoidCallback? onAction,
    String? customMessage,
    String? message,
    String? title,
    String? actionLabel,
  }) {
    return NovaEmptyState(
      icon: Icons.notifications_none_rounded,
      title: title ?? 'All Caught Up',
      message: message ??
          customMessage ??
          'You have no pending delivery alerts, payment verifications, or operational notifications at this time.',
      actionLabel: actionLabel ?? 'Check Updates',
      onAction: onAction,
      accentColor: const Color(0xFF64748B),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryAccent = accentColor ?? const Color(0xFFF37021);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Visual Graphic Container
              if (customIllustration != null)
                customIllustration!
              else
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: isDark ? 0.18 : 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: isDark ? 0.35 : 0.2),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: primaryAccent,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Description / Logistics Guidance
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action Button
              if (actionLabel != null && onAction != null)
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: Text(
                    actionLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),

              // Secondary Action Button
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(
                    secondaryActionLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

