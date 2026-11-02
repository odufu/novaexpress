content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaSuccessSummaryItem {
  final String label;
  final String value;

  const NovaSuccessSummaryItem({
    required this.label,
    required this.value,
  });
}

/// State 10: Success State
/// Confirms completed operations, celebrates achievements, and provides clear
/// next-step guidance with actionable buttons (Print, Share, Track).
class NovaSuccessState extends StatelessWidget {
  final String title;
  final String message;
  final String? referenceCode;
  final String referenceLabel;
  final Map<String, String> summaryDetails;
  final List<NovaSuccessSummaryItem>? summaryItems;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData icon;

  const NovaSuccessState({
    super.key,
    required this.title,
    required this.message,
    this.referenceCode,
    this.referenceLabel = 'WAYBILL NUMBER',
    this.summaryDetails = const {},
    this.summaryItems,
    this.primaryActionLabel = 'Done',
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.icon = Icons.check_circle_rounded,
  });

  /// Factory for shipment creation success
  factory NovaSuccessState.shipmentBooked({
    required String waybillNumber,
    String? recipientName,
    String? destinationCity,
    String? destination,
    double? totalAmount,
    VoidCallback? onViewTracking,
    VoidCallback? onPrintWaybill,
  }) {
    return NovaSuccessState(
      title: 'Shipment Successfully Booked!',
      message: 'The package has been registered and routed to the fulfillment queue. Dispatch labels are ready for processing.',
      referenceCode: waybillNumber,
      referenceLabel: 'WAYBILL NUMBER',
      summaryItems: [
        if (recipientName != null)
          NovaSuccessSummaryItem(label: 'Recipient', value: recipientName),
        if (destination != null || destinationCity != null)
          NovaSuccessSummaryItem(label: 'Destination', value: destination ?? destinationCity ?? ''),
        if (totalAmount != null)
          NovaSuccessSummaryItem(label: 'Total Amount', value: '₦${totalAmount.toStringAsFixed(0)}'),
      ],
      primaryActionLabel: 'Track Shipment',
      onPrimaryAction: onViewTracking ?? () {},
      secondaryActionLabel: 'Print Waybill',
      onSecondaryAction: onPrintWaybill,
    );
  }

  /// Factory for successful delivery confirmation / POD completion
  factory NovaSuccessState.deliveryConfirmed({
    String? orderId,
    String? orderNumber,
    required String recipientName,
    double? collectionAmount,
    double? remittanceAmount,
    VoidCallback? onNextDelivery,
    VoidCallback? onViewReceipt,
  }) {
    final finalOrder = orderNumber ?? orderId ?? 'ORD-001';
    final finalAmount = remittanceAmount ?? collectionAmount ?? 0.0;
    return NovaSuccessState(
      title: 'Delivery Proof Confirmed!',
      message: 'Proof of Delivery (POD) has been timestamped and customer signature synchronized with central dispatch.',
      referenceCode: finalOrder,
      referenceLabel: 'ORDER ID',
      summaryItems: [
        NovaSuccessSummaryItem(label: 'Recipient', value: recipientName),
        NovaSuccessSummaryItem(label: 'Collection', value: '₦${finalAmount.toStringAsFixed(0)} (Verified)'),
        const NovaSuccessSummaryItem(label: 'POD Status', value: 'Archived to Cloud'),
      ],
      primaryActionLabel: 'Next Delivery',
      onPrimaryAction: onNextDelivery ?? () {},
      secondaryActionLabel: onViewReceipt != null ? 'View Receipt' : null,
      onSecondaryAction: onViewReceipt,
    );
  }

  /// Factory for remittance reconciliation / payout disbursement success
  factory NovaSuccessState.settlementApproved({
    String? settlementRef,
    String? settlementNumber,
    double? totalAmount,
    double? clearedAmount,
    String? dcName,
    String? distributionCenter,
    VoidCallback? onDone,
  }) {
    final finalRef = settlementNumber ?? settlementRef ?? 'STL-001';
    final finalAmount = clearedAmount ?? totalAmount ?? 0.0;
    final finalDc = distributionCenter ?? dcName ?? 'Distribution Center';
    return NovaSuccessState(
      title: 'Settlement Cleared!',
      message: 'Rider cash remittances and DC fulfillment fees have been cleared and credited to the merchant ledger.',
      referenceCode: finalRef,
      referenceLabel: 'SETTLEMENT REFERENCE',
      summaryItems: [
        NovaSuccessSummaryItem(label: 'Distribution Center', value: finalDc),
        NovaSuccessSummaryItem(label: 'Cleared Amount', value: '₦${finalAmount.toStringAsFixed(0)}'),
        const NovaSuccessSummaryItem(label: 'Audit Tag', value: 'Reconciled'),
      ],
      primaryActionLabel: 'Done',
      onPrimaryAction: onDone ?? () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const successColor = Color(0xFF10B981);

    final List<NovaSuccessSummaryItem> effectiveItems = summaryItems ??
        summaryDetails.entries
            .map((e) => NovaSuccessSummaryItem(label: e.key, value: e.value))
            .toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated Success Checkmark Badge
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: successColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: successColor,
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
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),

              // Reference Code Card
              if (referenceCode != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              referenceLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              referenceCode!,
                              style: GoogleFonts.firaCode(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF37021),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: referenceCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$referenceLabel copied to clipboard!'),
                              backgroundColor: successColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Summary Details Card
              if (effectiveItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: effectiveItems.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              entry.value,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onPrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryActionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (secondaryActionLabel != null && onSecondaryAction != null)
                    OutlinedButton(
                      onPressed: onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        secondaryActionLabel!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
"""

with open('lib/core/widgets/ux_states/nova_success_state.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated nova_success_state.dart!')

