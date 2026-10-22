import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/sales_supervisor_provider.dart';

class RequestUpgModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final String closerId;
  final String closerName;
  final String closerCode;
  final bool isSupervisor;

  const RequestUpgModal({
    super.key,
    required this.order,
    required this.closerId,
    required this.closerName,
    required this.closerCode,
    this.isSupervisor = false,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderEntity order,
    required String closerId,
    required String closerName,
    required String closerCode,
    bool isSupervisor = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => RequestUpgModal(
        order: order,
        closerId: closerId,
        closerName: closerName,
        closerCode: closerCode,
        isSupervisor: isSupervisor,
      ),
    );
  }

  @override
  ConsumerState<RequestUpgModal> createState() => _RequestUpgModalState();
}

class _RequestUpgModalState extends ConsumerState<RequestUpgModal> {
  final _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);
  late TextEditingController _upgradedProductController;
  late TextEditingController _upgradedQuantityController;
  late TextEditingController _upgradedAmountController;
  late TextEditingController _reasonController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final currentProduct = widget.order.productName;
    final currentQty = widget.order.quantity;
    final currentTotal = widget.order.totalAmount;

    // Default suggested upgrade: double the units or upsell package
    _upgradedProductController = TextEditingController(
      text: "$currentProduct (Upgraded Bundle)",
    );
    _upgradedQuantityController = TextEditingController(
      text: "${(currentQty * 2).clamp(2, 20)}",
    );
    _upgradedAmountController = TextEditingController(
      text: "${(currentTotal * 1.8).round()}",
    );
    _reasonController = TextEditingController(
      text: "Customer requested extended course during phone confirmation.",
    );
  }

  @override
  void dispose() {
    _upgradedProductController.dispose();
    _upgradedQuantityController.dispose();
    _upgradedAmountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final currentTotal = widget.order.totalAmount;
    final enteredAmount = double.tryParse(_upgradedAmountController.text.trim()) ?? currentTotal;
    final upsellDelta = enteredAmount - currentTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "UPG REQUEST",
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF37021),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "#${widget.order.orderNumber}",
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Customer: ${widget.order.customerName} (${widget.order.customerPhone})",
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current Order Summary Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Current Package", style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                          Text(
                            "${widget.order.productName} (${widget.order.quantity} units)",
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Current COD Amount", style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                        Text(
                          _currency.format(currentTotal),
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Upgraded Package Name
              Text("Proposed Upgraded Package / Product", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TextField(
                controller: _upgradedProductController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),

              // Upgraded Quantity & Total Amount Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("New Qty", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _upgradedQuantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("New Total COD Amount (₦)", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _upgradedAmountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Incremental Upsell Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (upsellDelta > 0 ? const Color(0xFF10B981) : const Color(0xFFF37021)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (upsellDelta > 0 ? const Color(0xFF10B981) : const Color(0xFFF37021)).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "UPG Upsell Delta:",
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${upsellDelta >= 0 ? '+' : ''}${_currency.format(upsellDelta)}",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: upsellDelta >= 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reason Notes
              Text("Upgrade Justification / Call Notes", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "e.g. Customer upgraded to 3-month package after consultation.",
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 18),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isSupervisor ? const Color(0xFF00522A) : const Color(0xFFF37021),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final upgQty = int.tryParse(_upgradedQuantityController.text.trim()) ?? 1;
                          final upgAmt = double.tryParse(_upgradedAmountController.text.trim()) ?? currentTotal;

                          final res = await ref.read(salesSupervisorProvider.notifier).submitUpgRequest(
                            orderId: widget.order.id,
                            orderNumber: widget.order.orderNumber,
                            customerName: widget.order.customerName,
                            customerPhone: widget.order.customerPhone,
                            deliveryAddress: widget.order.deliveryAddress,
                            closerId: widget.closerId,
                            closerName: widget.closerName,
                            closerCode: widget.closerCode,
                            originalProduct: widget.order.productName,
                            originalQuantity: widget.order.quantity,
                            originalAmount: currentTotal,
                            upgradedProduct: _upgradedProductController.text.trim(),
                            upgradedQuantity: upgQty,
                            upgradedAmount: upgAmt,
                            reason: _reasonController.text.trim(),
                            selfApprove: widget.isSupervisor,
                            supervisorName: widget.closerName,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                content: Text(res['message']?.toString() ?? "UPG Request processed."),
                              ),
                            );
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.isSupervisor
                              ? "Authorize & Apply UPG Instantly"
                              : "Submit UPG for Supervisor Approval",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
