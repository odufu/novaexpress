import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/client_unit_economics.dart';

/// Modal dialog showing the comprehensive granular breakdown of dynamically
/// calculated operational charges for a specific product.
class ClientOperationalCostBreakdownModal extends StatelessWidget {
  final ClientUnitEconomics economics;
  final Color brandPrimary;

  const ClientOperationalCostBreakdownModal({
    super.key,
    required this.economics,
    this.brandPrimary = const Color(0xFF0D9488),
  });

  static Future<void> show(
    BuildContext context, {
    required ClientUnitEconomics economics,
    Color brandPrimary = const Color(0xFF0D9488),
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientOperationalCostBreakdownModal(
        economics: economics,
        brandPrimary: brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat('#,##0.00', 'en_US');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calculate_rounded, color: brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations Cost Breakdown',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${economics.productName} • ${economics.productSku}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Operational Cost Hero Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                              : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL OPERATIONS COST',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₦${currency.format(economics.totalOperationsCost)}',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${economics.totalOrdersCount} Total Orders',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Section: Cost Drivers Breakdown
                    Text(
                      'Granular Cost Drivers & Onboarding Tariffs',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 1. Delivery Fees
                    _buildCostRow(
                      icon: Icons.local_shipping_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Successful Order Delivery Fees',
                      subtext:
                          '${economics.deliveredOrdersCount} orders delivered @ ₦${currency.format(economics.deliveryFeeRate)} per order',
                      amountText: '₦${currency.format(economics.totalDeliveryFees)}',
                      isDark: isDark,
                      badge: 'Negotiated Onboarding Rate',
                    ),

                    const SizedBox(height: 8),

                    // 2. Failed Delivery Attempt Fees
                    _buildCostRow(
                      icon: Icons.cancel_schedule_send_rounded,
                      iconColor: const Color(0xFFEA580C),
                      title: 'Failed Delivery Attempt Charges',
                      subtext:
                          '${economics.failedOrdersCount} failed/cancelled orders @ ₦${currency.format(economics.failedFeeRate)} per attempt',
                      amountText: '₦${currency.format(economics.totalFailedFees)}',
                      isDark: isDark,
                      badge: 'Accumulative per failure',
                      highlightSubtext:
                          'As failed deliveries accumulate across dispatches, operational costs increase.',
                    ),

                    const SizedBox(height: 8),

                    // 3. Platform Transaction Charges
                    _buildCostRow(
                      icon: Icons.hub_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'System Platform & Infrastructure Charges',
                      subtext: economics.platformFeeType == 'percent'
                          ? '${economics.platformChargeRate}% commission on recovered package sales'
                          : '${economics.deliveredOrdersCount} transactions @ ₦${currency.format(economics.platformChargeRate)} per completed sale',
                      amountText: '₦${currency.format(economics.totalPlatformCharges)}',
                      isDark: isDark,
                      badge: 'Transaction Volume Charge',
                      highlightSubtext:
                          'As transaction volume grows, platform charges scale with order activity.',
                    ),

                    const SizedBox(height: 20),

                    // Section: Net Economics Impact
                    Text(
                      'Unit Economics & Net Margin Impact',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryLine(
                            'Gross Value Sold (Recovered Package Cash)',
                            '₦${currency.format(economics.valueSold)}',
                            isDark: isDark,
                            isBold: true,
                            textColor: const Color(0xFF16A34A),
                          ),
                          const Divider(height: 14),
                          _buildSummaryLine(
                            'Dispatched Landed COGS (${economics.quantitySold} units × ₦${currency.format(economics.totalLandedCost)})',
                            '-₦${currency.format(economics.cogsDispatched)}',
                            isDark: isDark,
                            textColor: const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 6),
                          _buildSummaryLine(
                            'Total Operations Cost (Logistics + Failed + Platform)',
                            '-₦${currency.format(economics.totalOperationsCost)}',
                            isDark: isDark,
                            textColor: const Color(0xFFDC2626),
                          ),
                          const Divider(height: 14),
                          _buildSummaryLine(
                            'Realized Net Profit',
                            '₦${currency.format(economics.netRealizedProfit)}',
                            isDark: isDark,
                            isBold: true,
                            textColor: economics.netRealizedProfit >= 0
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(height: 4),
                          _buildSummaryLine(
                            'Realized Net Margin %',
                            '${economics.netMarginPercent.toStringAsFixed(1)}%',
                            isDark: isDark,
                            isBold: true,
                            textColor: economics.netMarginPercent >= 30
                                ? const Color(0xFF16A34A)
                                : (economics.netMarginPercent > 0
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Rates configured in Client Onboarding Profile',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtext,
    required String amountText,
    required bool isDark,
    required String badge,
    String? highlightSubtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtext,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (highlightSubtext != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 12, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      highlightSubtext,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    required bool isDark,
    bool isBold = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isBold ? 12.5 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 13.5 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}

/// Interactive cell that displays the Total Operations Cost with:
/// 1. Instant Hover Popover Breakdown Card when mouse hovers over the cell.
/// 2. Full Granular Breakdown Modal when clicked.
class ClientOperationalCostCell extends StatefulWidget {
  final ClientUnitEconomics economics;
  final Color brandPrimary;
  final bool isDark;

  const ClientOperationalCostCell({
    super.key,
    required this.economics,
    required this.brandPrimary,
    required this.isDark,
  });

  @override
  State<ClientOperationalCostCell> createState() => _ClientOperationalCostCellState();
}

class _ClientOperationalCostCellState extends State<ClientOperationalCostCell> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final eco = widget.economics;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return Positioned(
            width: 340,
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.bottomRight,
              offset: const Offset(0, -6),
              child: MouseRegion(
                onEnter: (_) => _overlayController.show(),
                onExit: (_) => _overlayController.hide(),
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(12),
                  color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.brandPrimary.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: widget.brandPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.analytics_rounded, size: 14, color: widget.brandPrimary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Operations Cost Breakdown',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Total Operations Cost',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₦${currency.format(eco.totalOperationsCost)}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHoverLine('Delivery Fees (${eco.deliveredOrdersCount} orders)', '₦${currency.format(eco.totalDeliveryFees)}', const Color(0xFF10B981)),
                        const SizedBox(height: 4),
                        _buildHoverLine('Failed Attempt Fees (${eco.failedOrdersCount} orders)', '₦${currency.format(eco.totalFailedFees)}', const Color(0xFFF59E0B)),
                        const SizedBox(height: 4),
                        _buildHoverLine('Platform Charges (${eco.deliveredOrdersCount} txns)', '₦${currency.format(eco.totalPlatformCharges)}', const Color(0xFF6366F1)),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Click cell to view full audit modal',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: widget.brandPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.open_in_new_rounded, size: 12, color: widget.brandPrimary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() => _isHovered = true);
            _overlayController.show();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _overlayController.hide();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _overlayController.hide();
              ClientOperationalCostBreakdownModal.show(
                context,
                economics: eco,
                brandPrimary: widget.brandPrimary,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isHovered ? widget.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '₦${currency.format(eco.totalOperationsCost)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: _isHovered ? widget.brandPrimary : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoverLine(String label, String value, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: widget.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
