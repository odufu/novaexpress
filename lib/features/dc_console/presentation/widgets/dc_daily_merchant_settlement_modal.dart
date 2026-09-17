import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';

class DCDailyMerchantSettlementModal extends ConsumerStatefulWidget {
  final ClientProfile client;
  final List<OrderEntity> eligibleOrders;

  const DCDailyMerchantSettlementModal({
    super.key,
    required this.client,
    required this.eligibleOrders,
  });

  static Future<void> show({
    required BuildContext context,
    required ClientProfile client,
    required List<OrderEntity> eligibleOrders,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DCDailyMerchantSettlementModal(
        client: client,
        eligibleOrders: eligibleOrders,
      ),
    );
  }

  @override
  ConsumerState<DCDailyMerchantSettlementModal> createState() => _DCDailyMerchantSettlementModalState();
}

class _DCDailyMerchantSettlementModalState extends ConsumerState<DCDailyMerchantSettlementModal> {
  late Set<String> _selectedOrderIds;
  final TextEditingController _otherChargesController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default select all eligible orders
    _selectedOrderIds = widget.eligibleOrders.map((o) => o.id).toSet();
  }

  @override
  void dispose() {
    _otherChargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    final dcSettings = ref.watch(dcConsoleProvider.select((s) => s.financeSettings));
    final activeDcId = ref.watch(dcConsoleProvider.select((s) => s.activeDcId));

    // Calculate active metrics based on selected orders
    final activeOrders = widget.eligibleOrders.where((o) => _selectedOrderIds.contains(o.id)).toList();
    final double grossCollections = activeOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    // Delivery fees calculation (merchant override or DC default)
    final double deliveryFeePerOrder = widget.client.customDeliveryFee ?? dcSettings.defaultClientDeliveryFee;
    final double totalDeliveryFees = activeOrders.length * deliveryFeePerOrder;

    // Platform fees calculation
    final platformFeeType = widget.client.customPlatformFeeType ?? dcSettings.platformFeeType;
    final platformFeeValue = widget.client.customPlatformFeeValue ?? dcSettings.platformFeeValue;
    double totalPlatformFees = 0.0;
    if (platformFeeType == 'percent') {
      totalPlatformFees = grossCollections * (platformFeeValue / 100.0);
    } else {
      totalPlatformFees = activeOrders.length * platformFeeValue;
    }

    // Gateway fees calculation
    final paystackFeeAbsorbedBy = widget.client.customPaystackFeeAbsorbedBy ?? dcSettings.paystackFeeAbsorbedBy;
    double totalGatewayFees = 0.0;
    if (paystackFeeAbsorbedBy == 'merchant' || paystackFeeAbsorbedBy == 'shared') {
      final directOrders = activeOrders.where((o) => o.isDirectTransfer);
      for (final d in directOrders) {
        final calculatedFee = d.totalAmount * (dcSettings.paystackDirectFeePercent / 100.0);
        final cappedFee = calculatedFee > dcSettings.paystackFeeCap ? dcSettings.paystackFeeCap : calculatedFee;
        totalGatewayFees += paystackFeeAbsorbedBy == 'shared' ? (cappedFee / 2.0) : cappedFee;
      }
    }

    final double otherCharges = double.tryParse(_otherChargesController.text) ?? 0.0;
    final double totalDeductions = totalDeliveryFees + totalPlatformFees + totalGatewayFees + otherCharges;
    final double netPayout = grossCollections - totalDeductions;

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 850,
          maxHeight: screenHeight * 0.92,
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fact_check_rounded, color: Color(0xFFF37021), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client Settlement',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.client.companyName} | ${widget.client.bankName.isNotEmpty ? widget.client.bankName : "No Bank"} - ${widget.client.accountNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Order Selection & Charges Matrix
                Expanded(
                  child: isMobile
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checklist header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Delivered Orders (${activeOrders.length}/${widget.eligibleOrders.length})',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedOrderIds.length == widget.eligibleOrders.length) {
                                          _selectedOrderIds.clear();
                                        } else {
                                          _selectedOrderIds = widget.eligibleOrders.map((o) => o.id).toSet();
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedOrderIds.length == widget.eligibleOrders.length ? 'Deselect All' : 'Select All',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: widget.eligibleOrders.isEmpty
                                    ? Center(child: Text('No eligible orders found', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)))
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: widget.eligibleOrders.length,
                                        itemBuilder: (context, idx) {
                                          final o = widget.eligibleOrders[idx];
                                          final isSelected = _selectedOrderIds.contains(o.id);
                                          return CheckboxListTile(
                                            dense: true,
                                            value: isSelected,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedOrderIds.add(o.id);
                                                } else {
                                                  _selectedOrderIds.remove(o.id);
                                                }
                                              });
                                            },
                                            title: Text(
                                              '${o.orderNumber} - ${o.customerName}',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              '${o.paymentType.toUpperCase()} | Delivered: ${o.deliveredAt?.toLocal().toString().split('.')[0] ?? "Today"}',
                                              style: GoogleFonts.inter(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            secondary: Text(
                                              currency.format(o.totalAmount),
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0D9488)),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _buildSettlementCard(
                                isDark: isDark,
                                currency: currency,
                                grossCollections: grossCollections,
                                totalDeliveryFees: totalDeliveryFees,
                                totalPlatformFees: totalPlatformFees,
                                totalGatewayFees: totalGatewayFees,
                                otherCharges: otherCharges,
                                netPayout: netPayout,
                                activeOrders: activeOrders,
                                activeDcId: activeDcId,
                                isMobile: true,
                              ),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Order Checklist
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Delivered Orders (${activeOrders.length}/${widget.eligibleOrders.length})',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            if (_selectedOrderIds.length == widget.eligibleOrders.length) {
                                              _selectedOrderIds.clear();
                                            } else {
                                              _selectedOrderIds = widget.eligibleOrders.map((o) => o.id).toSet();
                                            }
                                          });
                                        },
                                        child: Text(_selectedOrderIds.length == widget.eligibleOrders.length ? 'Deselect All' : 'Select All'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: widget.eligibleOrders.length,
                                      itemBuilder: (context, idx) {
                                        final o = widget.eligibleOrders[idx];
                                        final isSelected = _selectedOrderIds.contains(o.id);
                                        return CheckboxListTile(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedOrderIds.add(o.id);
                                              } else {
                                                _selectedOrderIds.remove(o.id);
                                              }
                                            });
                                          },
                                          title: Text('${o.orderNumber} - ${o.customerName}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                          subtitle: Text('${o.paymentType.toUpperCase()} | Delivered: ${o.deliveredAt?.toLocal().toString().split('.')[0] ?? "Today"}', style: GoogleFonts.inter(fontSize: 11)),
                                          secondary: Text(currency.format(o.totalAmount), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0D9488))),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right: Itemized Charges Breakdown Card
                            Expanded(
                              flex: 2,
                              child: _buildSettlementCard(
                                isDark: isDark,
                                currency: currency,
                                grossCollections: grossCollections,
                                totalDeliveryFees: totalDeliveryFees,
                                totalPlatformFees: totalPlatformFees,
                                totalGatewayFees: totalGatewayFees,
                                otherCharges: otherCharges,
                                netPayout: netPayout,
                                activeOrders: activeOrders,
                                activeDcId: activeDcId,
                                isMobile: false,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettlementCard({
    required bool isDark,
    required NumberFormat currency,
    required double grossCollections,
    required double totalDeliveryFees,
    required double totalPlatformFees,
    required double totalGatewayFees,
    required double otherCharges,
    required double netPayout,
    required List<OrderEntity> activeOrders,
    required String activeDcId,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text('Itemized Settlement Calculation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _buildCalculationRow('Gross Delivered Sales', currency.format(grossCollections), isPositive: true),
          const Divider(height: 16),
          _buildCalculationRow('Logistics Delivery Fees', '- ${currency.format(totalDeliveryFees)}', isNegative: true),
          _buildCalculationRow('Platform Commission Fees', '- ${currency.format(totalPlatformFees)}', isNegative: true),
          _buildCalculationRow('Paystack Gateway Fees', '- ${currency.format(totalGatewayFees)}', isNegative: true),
          if (otherCharges > 0)
            _buildCalculationRow('Auxiliary Charges', '- ${currency.format(otherCharges)}', isNegative: true),
          const Divider(height: 20),
          _buildCalculationRow('Net Liquid Payout', currency.format(netPayout > 0 ? netPayout : 0.0), isBold: true, isHighlight: true),
          if (isMobile) const SizedBox(height: 16) else const Spacer(),

          // Execution Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: activeOrders.isEmpty ? null : () async {
                await showAppLoadingDialog(
                  context: context,
                  message: 'Finalizing Client Settlement...',
                  subMessage: 'Locking ${activeOrders.length} orders & generating settlement receipt...',
                  isDark: isDark,
                  task: () async {
                    final now = DateTime.now();
                    final selectedIds = activeOrders.map((o) => o.id).toList();
                    await ref.read(dcConsoleProvider.notifier).executeDailyMerchantSettlement(
                      clientId: widget.client.id,
                      dcId: activeDcId,
                      periodStart: now.subtract(const Duration(days: 60)),
                      periodEnd: now,
                      customDeductions: {
                        'other_charges': otherCharges,
                        'notes': _notesController.text.isNotEmpty
                            ? _notesController.text
                            : 'Client Settlement Batch',
                      },
                      orderIds: selectedIds,
                    );
                    await ref.read(ordersProvider.notifier).fetchOrders();
                  },
                );
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text('Finalize Client Settlement', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? const Color(0xFF0D9488)
                  : isNegative
                      ? const Color(0xFFEF4444)
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
