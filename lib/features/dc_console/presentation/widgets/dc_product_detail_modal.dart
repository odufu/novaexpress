import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/product_package.dart';
import '../providers/product_catalog_provider.dart';
import 'dc_create_order_modal.dart';

class DCProductDetailModal extends ConsumerStatefulWidget {
  final StockItemEntity item;
  final List<DCFleetDriver> drivers;
  final List<RiderStockAllocation> allocations;
  final VoidCallback? onReceiveMoreStock;
  final VoidCallback? onAssignToRider;
  final VoidCallback? onReportDamage;

  const DCProductDetailModal({
    super.key,
    required this.item,
    required this.drivers,
    required this.allocations,
    this.onReceiveMoreStock,
    this.onAssignToRider,
    this.onReportDamage,
  });

  static Future<void> show(
    BuildContext context, {
    required StockItemEntity item,
    required List<DCFleetDriver> drivers,
    required List<RiderStockAllocation> allocations,
    VoidCallback? onReceiveMoreStock,
    VoidCallback? onAssignToRider,
    VoidCallback? onReportDamage,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 24,
          vertical: isMobile ? 12 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 780,
            maxHeight: size.height * 0.92,
          ),
          child: DCProductDetailModal(
            item: item,
            drivers: drivers,
            allocations: allocations,
            onReceiveMoreStock: onReceiveMoreStock,
            onAssignToRider: onAssignToRider,
            onReportDamage: onReportDamage,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<DCProductDetailModal> createState() => _DCProductDetailModalState();
}

class _DCProductDetailModalState extends ConsumerState<DCProductDetailModal> {
  /// Strips out internal metadata tags ([IMAGE_URL: ...], [PACKAGES: ...]) from user-facing description.
  String _cleanDisplayDescription(String rawDesc, String productName) {
    if (rawDesc.trim().isEmpty) {
      return '$productName commercial distributed stock item managed across NovaXpress distribution network.';
    }
    var desc = rawDesc;
    if (desc.contains('[IMAGE_URL:')) {
      desc = desc.replaceAll(RegExp(r'\[IMAGE_URL:\s*[^\]]+\]'), '').trim();
    }
    if (desc.contains('[PACKAGES:')) {
      final start = desc.indexOf('[PACKAGES:');
      final end = desc.lastIndexOf(']');
      if (end > start) {
        desc = (desc.substring(0, start) + desc.substring(end + 1)).trim();
      } else {
        desc = desc.substring(0, start).trim();
      }
    }
    desc = desc.replaceAll(RegExp(r'-\s*Distributed Inventory', caseSensitive: false), '').trim();
    desc = desc.replaceAll(RegExp(r'[\s\-_]+$'), '').trim();

    if (desc.isEmpty || desc.trim().toLowerCase() == productName.trim().toLowerCase()) {
      return '$productName commercial distributed stock item managed across NovaXpress distribution network.';
    }
    return desc.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    final catalogState = ref.watch(productCatalogProvider);
    final packages = catalogState.getPackagesForProduct(item.name);

    final productAllocations = widget.allocations.where((a) =>
        (a.productId == item.id ||
            a.sku.toLowerCase() == item.sku.toLowerCase() ||
            a.productName.toLowerCase() == item.name.toLowerCase()) &&
        a.inCustodyUnits > 0).toList();

    final cleanDesc = _cleanDisplayDescription(item.description, item.name);
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Column(
          children: [
            // 1. TOP HERO HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // High-Resolution Product Image with subtle glow
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ProductImageWidget(
                      imageUrl: item.imageAsset,
                      width: 56,
                      height: 56,
                      borderRadius: 14,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, SKU, Category, Merchant Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            _buildStatusBadge(item),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // SKU Pill with Copy Action
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: item.sku));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied SKU: ${item.sku}'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_rounded, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.sku,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Category Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),

                            // Merchant / Brand Owner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.business_rounded, size: 11, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.ownerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Close Dialog Button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.all(6),
                    ),
                    tooltip: 'Close Modal',
                  ),
                ],
              ),
            ),

            // 2. SCROLLABLE BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. INVENTORY & CUSTODY STATS (4-CARD GRID)
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Inventory & Physical Custody Accounting',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final is4Col = constraints.maxWidth > 650;
                        final is2Col = constraints.maxWidth > 360 && !is4Col;
                        final width = is4Col
                            ? (constraints.maxWidth - 24) / 4
                            : is2Col
                                ? (constraints.maxWidth - 8) / 2
                                : constraints.maxWidth;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: width,
                              child: _buildStockStatTile(
                                '🏢 In DC Possession',
                                '${item.availableCount} Units',
                                'Available on shelf',
                                const Color(0xFF10B981),
                                isDark,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildStockStatTile(
                                '🛵 In Rider Custody',
                                '${item.inRiderCustodyCount} Units',
                                'Active with fleet riders',
                                const Color(0xFF8B5CF6),
                                isDark,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildStockStatTile(
                                '✅ Delivered Units',
                                '${item.deliveredCount} Units',
                                'Fulfilled to buyers',
                                const Color(0xFF2563EB),
                                isDark,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildStockStatTile(
                                '⚠️ Reported / Damaged',
                                '${item.complaintCount} Units',
                                item.complaintCount > 0 ? 'Action required' : 'Zero loss recorded',
                                item.complaintCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                isDark,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // B. PRODUCT SPECIFICATIONS & WAREHOUSING SPECS
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'Specifications & Warehouse Parameters',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final is2Col = constraints.maxWidth > 480;
                              final colWidth = is2Col ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                              return Wrap(
                                spacing: 16,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '🏢 Merchant / Company',
                                      item.ownerName,
                                      Icons.storefront_outlined,
                                      isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '💰 Single Unit Retail Price',
                                      CurrencyFormatter.formatNaira(item.price),
                                      Icons.payments_outlined,
                                      isDark,
                                      valueColor: const Color(0xFF10B981),
                                      isBold: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '📍 Storage Bin Location',
                                      item.binLocation ?? 'BIN-A1-01',
                                      Icons.location_on_outlined,
                                      isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '🏷️ Batch / Lot Code',
                                      item.batchNumber ?? 'LOT-2026-08',
                                      Icons.tag_rounded,
                                      isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '📊 Total Tracked Units',
                                      '${item.totalInCustody} Units',
                                      Icons.inventory_2_outlined,
                                      isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidth,
                                    child: _buildSpecItem(
                                      '💎 Stock Asset Value',
                                      CurrencyFormatter.formatNaira(item.totalInCustody * item.price),
                                      Icons.account_balance_wallet_outlined,
                                      isDark,
                                      valueColor: const Color(0xFF2563EB),
                                      isBold: true,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          if (cleanDesc.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Description',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        cleanDesc,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // C. COMMERCIAL PACKAGES SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF37021).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 450;
                              final titleWidget = Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.local_offer_rounded, size: 16, color: Color(0xFFF37021)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Commercial Packages & Bundles (${packages.length})',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          'Multi-pack deals with auto stock deduction',
                                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final btnWidget = ElevatedButton.icon(
                                onPressed: () => _showCreateOrEditPackageDialog(context, isDark, item),
                                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                label: const Text(
                                  '+ Create Package Deal',
                                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF37021),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    titleWidget,
                                    const SizedBox(height: 10),
                                    Align(alignment: Alignment.centerLeft, child: btnWidget),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: titleWidget),
                                  const SizedBox(width: 10),
                                  btnWidget,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          if (packages.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Center(
                                child: Text(
                                  'No custom package deals yet. Click "+ Create Package Deal" to create bulk or promo packages.',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...packages.map((pkg) => _buildPackageCard(pkg, item, isDark)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // D. RIDERS IN CUSTODY SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 8),
                              Text(
                                'Riders Holding Vehicle Stock (${productAllocations.length})',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (productAllocations.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                'No riders currently hold this product in vehicle custody.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            )
                          else
                            ...productAllocations.map((alloc) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow = constraints.maxWidth < 420;
                                    final riderInfo = Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                          child: const Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                alloc.riderName,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                alloc.riderCode,
                                                style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );

                                    final stockBadge = Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                                      ),
                                      child: Text(
                                        '${alloc.inCustodyUnits} Units in Vehicle',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8B5CF6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );

                                    if (isNarrow) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          riderInfo,
                                          const SizedBox(height: 8),
                                          stockBadge,
                                        ],
                                      );
                                    }

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: riderInfo),
                                        const SizedBox(width: 8),
                                        stockBadge,
                                      ],
                                    );
                                  },
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. ACTION FOOTER BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: borderColor),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      if (widget.onReportDamage != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onReportDamage!();
                          },
                          icon: const Icon(Icons.report_problem_outlined, size: 14, color: Color(0xFFEF4444)),
                          label: const Text('Report Damage / Loss', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      if (widget.onReceiveMoreStock != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onReceiveMoreStock!();
                          },
                          icon: const Icon(Icons.arrow_downward_rounded, size: 15, color: Colors.white),
                          label: const Text('Receive Stock', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                        ),
                      if (widget.onAssignToRider != null)
                        ElevatedButton.icon(
                          onPressed: item.availableCount > 0
                              ? () {
                                  Navigator.of(context).pop();
                                  widget.onAssignToRider!();
                                }
                              : null,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
                          label: const Text('Assign to Rider', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, IconData icon, bool isDark, {Color? valueColor, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(ProductPackage pkg, StockItemEntity item, bool isDark) {
    final savings = pkg.savingsAmount(item.price);
    final savingsPct = pkg.savingsPercent(item.price);
    final hasSavings = savings > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              final infoWidget = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: Color(0xFFF37021), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.packageName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📦 ${pkg.quantity} Physical Stock Unit${pkg.quantity > 1 ? 's' : ''} (${pkg.paidQuantity} Paid + ${pkg.freeQuantity} Free)',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final priceWidget = Column(
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(pkg.packagePrice),
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                  ),
                  Text(
                    '${CurrencyFormatter.formatNaira(pkg.unitPrice)} / unit',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoWidget,
                    const SizedBox(height: 8),
                    priceWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: infoWidget),
                  const SizedBox(width: 12),
                  priceWidget,
                ],
              );
            },
          ),

          if (hasSavings || (pkg.description != null && pkg.description!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasSavings)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '🔥 Save ${CurrencyFormatter.formatNaira(savings)} (${savingsPct.toStringAsFixed(0)}% OFF)',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                if (pkg.description != null && pkg.description!.isNotEmpty)
                  Text(
                    pkg.description!,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showCreateOrEditPackageDialog(context, isDark, item, existingPackage: pkg),
                icon: const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF2563EB)),
                label: const Text('Edit Deal', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (pkg.isCustom)
                TextButton.icon(
                  onPressed: () {
                    ref.read(productCatalogProvider.notifier).deletePackage(
                          productName: item.name,
                          packageId: pkg.id,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Package "${pkg.packageName}" removed.')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  final catProd = ref.read(productCatalogProvider).findProductByName(item.name) ??
                      CatalogProduct(
                        id: item.id,
                        name: item.name,
                        sku: item.sku,
                        clientName: item.ownerName,
                        defaultUnitPrice: item.price,
                        category: item.category,
                        packages: [pkg],
                      );
                  ref.read(dcCreateOrderDraftProvider.notifier).selectProduct(catProd);
                  ref.read(dcCreateOrderDraftProvider.notifier).selectPackage(pkg);
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (ctx) => const DCCreateOrderModal(),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                label: const Text('Create Order with this Package', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateOrEditPackageDialog(
    BuildContext context,
    bool isDark,
    StockItemEntity item, {
    ProductPackage? existingPackage,
  }) {
    final isEditing = existingPackage != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? existingPackage.packageName : '${item.name} 5-Pack Special Deal',
    );
    final qtyCtrl = TextEditingController(
      text: isEditing ? '${existingPackage.quantity}' : '5',
    );
    final paidQtyCtrl = TextEditingController(
      text: isEditing ? '${existingPackage.paidQuantity}' : '5',
    );
    final freeQtyCtrl = TextEditingController(
      text: isEditing ? '${existingPackage.freeQuantity}' : '0',
    );
    final priceCtrl = TextEditingController(
      text: isEditing ? existingPackage.packagePrice.toStringAsFixed(0) : (item.price * 5 * 0.85).toStringAsFixed(0),
    );
    final descCtrl = TextEditingController(
      text: isEditing ? (existingPackage.description ?? '') : 'Save with this bulk package deal',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = int.tryParse(qtyCtrl.text) ?? 1;
          final p = double.tryParse(priceCtrl.text.replaceAll(',', '').replaceAll('₦', '')) ?? 0.0;
          final effectiveUnit = q > 0 ? p / q : p;
          final baseTotal = q * item.price;
          final savings = (baseTotal - p) > 0 ? (baseTotal - p) : 0.0;
          final savingsPct = baseTotal > 0 && savings > 0 ? (savings / baseTotal * 100) : 0.0;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.local_offer_rounded,
                  color: const Color(0xFFF37021),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Package: ${existingPackage.packageName}' : 'Create Package for ${item.name}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Package Name *',
                        hintText: 'e.g. 5 Grazer Tea Pack (5 for ₦55,000)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Physical Units *',
                              hintText: '5',
                            ),
                            onChanged: (_) => setDialogState(() {
                              if (!isEditing || paidQtyCtrl.text == qtyCtrl.text) {
                                paidQtyCtrl.text = qtyCtrl.text;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: paidQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Paid Units',
                              hintText: '5',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: freeQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Free Bonus Units',
                              hintText: '0',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Package Selling Price (₦) *',
                        hintText: '55000',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Package Description / Badge (Optional)',
                        hintText: 'e.g. Best Value Mega Deal - Save ₦5,000',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Real-time calculation preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Effective Unit Rate:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                              Flexible(
                                child: Text(
                                  CurrencyFormatter.formatNaira(effectiveUnit),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Standard Single Price Total:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                              Flexible(
                                child: Text(
                                  CurrencyFormatter.formatNaira(baseTotal),
                                  style: GoogleFonts.inter(fontSize: 11.5, decoration: TextDecoration.lineThrough, color: const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Customer Savings:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                              Flexible(
                                child: Text(
                                  '${CurrencyFormatter.formatNaira(savings)} (${savingsPct.toStringAsFixed(0)}% OFF)',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final pkgName = nameCtrl.text.trim();
                  final totalUnits = int.tryParse(qtyCtrl.text) ?? 1;
                  final paidUnits = int.tryParse(paidQtyCtrl.text) ?? totalUnits;
                  final freeUnits = int.tryParse(freeQtyCtrl.text) ?? 0;
                  final pkgPrice = double.tryParse(priceCtrl.text.replaceAll(',', '').replaceAll('₦', '')) ?? 0.0;
                  final desc = descCtrl.text.trim();

                  if (pkgName.isEmpty || pkgPrice <= 0) return;

                  if (isEditing) {
                    ref.read(productCatalogProvider.notifier).updatePackage(
                          productName: item.name,
                          packageId: existingPackage.id,
                          packageName: pkgName,
                          quantity: totalUnits,
                          paidQuantity: paidUnits,
                          freeQuantity: freeUnits,
                          packagePrice: pkgPrice,
                          description: desc.isNotEmpty ? desc : null,
                        );
                  } else {
                    ref.read(productCatalogProvider.notifier).addPackageToProduct(
                          productName: item.name,
                          packageName: pkgName,
                          quantity: totalUnits,
                          paidQuantity: paidUnits,
                          freeQuantity: freeUnits,
                          packagePrice: pkgPrice,
                          clientName: item.ownerName,
                          productSku: item.sku,
                          description: desc.isNotEmpty ? desc : null,
                        );
                  }

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text(isEditing ? 'Package "$pkgName" updated successfully!' : 'Package "$pkgName" created successfully!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021)),
                child: Text(isEditing ? 'Update Package' : 'Save Package', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStockStatTile(String title, String value, String subtitle, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(StockItemEntity item) {
    Color bg;
    Color fg;
    String text;

    switch (item.status) {
      case StockStatus.available:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        text = 'AVAILABLE';
        break;
      case StockStatus.lowStock:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        text = 'LOW STOCK';
        break;
      case StockStatus.outOfStock:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        text = 'OUT OF STOCK';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg)),
    );
  }
}
