import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/sales_supervisor_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';

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
  ProductPackage? _selectedPackage;
  late TextEditingController _reasonController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: "Customer confirmed upgrade to higher package during phone consultation.",
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _cleanProductName(String raw) {
    // Strip trailing parenthesized info like "(3 units)" or "(1 Pack)" or "(Upgraded Bundle)"
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
  }

  List<ProductPackage> _resolvePackages(ProductCatalogState catalog) {
    final cleanName = _cleanProductName(widget.order.productName);

    // 1. Try finding by clean name or exact product name
    final matchedProduct = catalog.findProductByName(cleanName) ??
        catalog.findProductByName(widget.order.productName);

    if (matchedProduct != null && matchedProduct.packages.isNotEmpty) {
      return matchedProduct.packages;
    }

    // 2. Try catalog.getPackagesForProduct
    final directPkgs = catalog.getPackagesForProduct(cleanName);
    if (directPkgs.isNotEmpty) return directPkgs;

    // 3. Fallback: generate default synthesized packages based on unit price
    final currentQty = widget.order.quantity > 0 ? widget.order.quantity : 1;
    final unitPrice = widget.order.basePrice > 0
        ? widget.order.basePrice
        : (widget.order.totalAmount / currentQty);

    return ProductCatalogNotifier.buildDefaultPackagesForProduct(
      productId: matchedProduct?.id ?? 'prod-${widget.order.productId ?? widget.order.orderNumber}',
      productName: cleanName.isNotEmpty ? cleanName : widget.order.productName,
      baseUnitPrice: unitPrice > 0 ? unitPrice : 15000.0,
      clientName: widget.order.clientName,
    );
  }

  bool _isCurrentPackage(ProductPackage pkg) {
    final orderPkgName = widget.order.packageDealName?.trim().toLowerCase();
    if (orderPkgName != null && orderPkgName.isNotEmpty) {
      if (pkg.packageName.trim().toLowerCase() == orderPkgName) return true;
    }
    // Check by quantity and price
    if (pkg.totalPhysicalQuantity == widget.order.quantity &&
        (pkg.packagePrice - widget.order.totalAmount).abs() < 1.0) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final catalogState = ref.watch(productCatalogProvider);
    final packages = _resolvePackages(catalogState);
    final currentTotal = widget.order.totalAmount;

    final selectedPkg = _selectedPackage;
    final upsellDelta = selectedPkg != null ? (selectedPkg.packagePrice - currentTotal) : 0.0;
    final isSelectedPackageCurrent = selectedPkg != null && _isCurrentPackage(selectedPkg);

    final cleanName = _cleanProductName(widget.order.productName);
    final currentPackageLabel = (widget.order.packageDealName != null && widget.order.packageDealName!.trim().isNotEmpty)
        ? widget.order.packageDealName!.trim()
        : '${widget.order.quantity} units (Current)';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        padding: const EdgeInsets.all(20),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 13, color: Colors.amberAccent),
                                const SizedBox(width: 3),
                                Text(
                                  "UPG REQUEST",
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
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
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Product & Active Order Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cleanName.isNotEmpty ? cleanName : widget.order.productName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Current Package: $currentPackageLabel",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "CURRENT COD",
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _currency.format(currentTotal),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D9488),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Package Selection Prompt
                    Row(
                      children: [
                        Text(
                          "Select Upgraded Package",
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(Tap to Select)",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Choose one of the official packages attached to this product. Quantities and pricing adjust automatically.",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Interactive Tap-to-Select Package Cards List
                    ...packages.map((pkg) {
                      final isSelected = _selectedPackage?.id == pkg.id ||
                          (_selectedPackage == null && _isCurrentPackage(pkg));
                      final isCurrent = _isCurrentPackage(pkg);

                      return _buildPackageCard(
                        context: context,
                        pkg: pkg,
                        isSelected: isSelected,
                        isCurrent: isCurrent,
                        isDark: isDark,
                        currentTotal: currentTotal,
                        onTap: () {
                          setState(() {
                            _selectedPackage = pkg;
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 14),

                    // Live Upgrade Impact Summary Banner
                    if (selectedPkg != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (upsellDelta > 0 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (upsellDelta > 0 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              upsellDelta > 0 ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                              size: 20,
                              color: upsellDelta > 0 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    upsellDelta > 0
                                        ? "UPG Upsell Delta: +${_currency.format(upsellDelta)}"
                                        : (upsellDelta == 0 ? "Current Order Terms (No Change)" : "Price Adjustment: ${_currency.format(upsellDelta)}"),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: upsellDelta > 0
                                          ? const Color(0xFF10B981)
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "New Total: ${_currency.format(selectedPkg.packagePrice)} (${selectedPkg.totalPhysicalQuantity} physical units)",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Reason / Call Justification Notes
                    Text(
                      "Upgrade Justification / Confirmation Notes",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: "e.g. Customer agreed to 3-month family bundle during confirmation call.",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF8B5CF6),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isSupervisor ? const Color(0xFF00522A) : const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: (_isSubmitting || selectedPkg == null || isSelectedPackageCurrent)
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        final targetPkg = selectedPkg;

                        final res = await ref.read(salesSupervisorProvider.notifier).submitUpgRequest(
                          orderId: widget.order.id,
                          orderNumber: widget.order.orderNumber,
                          customerName: widget.order.customerName,
                          customerPhone: widget.order.customerPhone,
                          deliveryAddress: widget.order.deliveryAddress,
                          closerId: widget.closerId,
                          closerName: widget.closerName,
                          closerCode: widget.closerCode,
                          originalProduct: (widget.order.packageDealName != null && widget.order.packageDealName!.isNotEmpty)
                              ? '${cleanName.isNotEmpty ? cleanName : widget.order.productName} (${widget.order.packageDealName})'
                              : '${cleanName.isNotEmpty ? cleanName : widget.order.productName} (${widget.order.quantity} units)',
                          originalQuantity: widget.order.quantity,
                          originalAmount: currentTotal,
                          upgradedProduct: targetPkg.packageName,
                          upgradedQuantity: targetPkg.totalPhysicalQuantity,
                          upgradedAmount: targetPkg.packagePrice,
                          reason: _reasonController.text.trim().isNotEmpty
                              ? _reasonController.text.trim()
                              : 'Customer upgraded to ${targetPkg.packageName}.',
                          selfApprove: widget.isSupervisor,
                          supervisorName: widget.closerName,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              content: Row(
                                children: [
                                  Icon(
                                    res['success'] == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      res['message']?.toString() ?? "UPG Request processed.",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isSupervisor ? Icons.verified_rounded : Icons.bolt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isSupervisor
                                ? "Authorize & Apply UPG Instantly"
                                : (isSelectedPackageCurrent
                                    ? "Select Different Package to Upgrade"
                                    : "Submit UPG for Supervisor Approval"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard({
    required BuildContext context,
    required ProductPackage pkg,
    required bool isSelected,
    required bool isCurrent,
    required bool isDark,
    required double currentTotal,
    required VoidCallback onTap,
  }) {
    final delta = pkg.packagePrice - currentTotal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.16)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.08))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Custom Radio Indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Package Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pkg.packageName,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CURRENT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pkg.totalPhysicalQuantity} units in package',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        if (pkg.freeQuantity > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${pkg.freeQuantity} Free',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Price & Delta Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currency.format(pkg.packagePrice),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (delta > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${_currency.format(delta)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    )
                  else if (delta < 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currency.format(delta),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    )
                  else
                    Text(
                      'No Change',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
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
