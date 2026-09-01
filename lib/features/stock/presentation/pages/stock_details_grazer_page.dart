import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';
import '../widgets/return_stock_modal.dart';

class StockDetailsGrazerPage extends ConsumerWidget {
  final String productName;

  const StockDetailsGrazerPage({
    super.key,
    this.productName = 'Respira Detox Tea',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final catalogState = ref.watch(productCatalogProvider);
    final ordersState = ref.watch(ordersProvider);

    // 1. Find matched stock item
    StockItemEntity? matchedItem;
    for (final item in stockState.stockItems) {
      if (item.name.toLowerCase() == productName.toLowerCase() ||
          item.sku.toLowerCase() == productName.toLowerCase()) {
        matchedItem = item;
        break;
      }
    }
    final item = matchedItem ?? (stockState.stockItems.isNotEmpty ? stockState.stockItems.first : null);

    final String displayName = item?.name ?? productName;
    final String displaySku = item?.sku ?? 'RDT-001';
    final String displayDesc = (item != null && item.cleanDescription.isNotEmpty)
        ? item.cleanDescription
        : 'Premium organic herbal blend formulated for detox, purification, and daily wellness. Store in cool, dry conditions.';
    final int assigned = item?.assignedCount ?? 0;
    final int delivered = item?.deliveredCount ?? 0;
    final int inVehicle = item?.availableCount ?? 0;
    final int returned = item?.returnedCount ?? 0;
    final double unitPrice = item?.price ?? 22000.0;
    final String ownerName = item?.ownerName ?? 'Novacare Limited';
    final String? imageAsset = item?.imageAsset;

    // 2. Find commercial packages for this product
    List<ProductPackage> packages = [];

    final catalogProduct = catalogState.products.firstWhere(
      (p) => p.name.toLowerCase() == displayName.toLowerCase() || p.sku.toLowerCase() == displaySku.toLowerCase(),
      orElse: () => CatalogProduct(id: '', name: displayName, sku: displaySku, clientName: ownerName, defaultUnitPrice: unitPrice, packages: []),
    );

    if (catalogProduct.packages.isNotEmpty) {
      packages = catalogProduct.packages;
    } else if (item != null && item.description.contains('[PACKAGES:')) {
      try {
        final startIdx = item.description.indexOf('[PACKAGES:') + 10;
        final endIdx = item.description.lastIndexOf(']');
        if (endIdx > startIdx) {
          final jsonStr = item.description.substring(startIdx, endIdx + 1).trim();
          final decodedList = jsonDecode(jsonStr) as List;
          packages = decodedList
              .map((it) => ProductPackage.fromJson(it as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    if (packages.isEmpty) {
      packages = ProductCatalogNotifier.buildDefaultPackagesForProduct(
        productId: item?.id ?? displaySku,
        productName: displayName,
        productSku: displaySku,
        baseUnitPrice: unitPrice,
        clientName: ownerName,
      );
    }

    // 3. Find active orders assigned to rider requiring this product
    final tiedOrders = ordersState.orders.where((o) {
      final matchesProduct = o.productName.toLowerCase() == displayName.toLowerCase() ||
          o.productName.toLowerCase().contains(displayName.toLowerCase()) ||
          displayName.toLowerCase().contains(o.productName.toLowerCase());
      final isActive = o.status != 'delivered' && o.status != 'cancelled';
      return matchesProduct && isActive;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Stock Details',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Reconcile Stock',
            onPressed: () => context.push('/stock/audit'),
          ),
        ],
      ),
      body: stockState.isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  AppSkeletonLoader(width: double.infinity, height: 180, borderRadius: 16),
                  SizedBox(height: 16),
                  AppSkeletonLoader(width: double.infinity, height: 120, borderRadius: 16),
                  SizedBox(height: 16),
                  AppSkeletonLoader(width: double.infinity, height: 140, borderRadius: 16),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image & Hero Card
                  Center(
                    child: ProductImageWidget(
                      imageUrl: imageAsset,
                      width: 140,
                      height: 150,
                      borderRadius: 16,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product Header Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SKU: $displaySku',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${CurrencyFormatter.formatNaira(unitPrice)} / single',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Merchant: $ownerName',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayDesc,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. VEHICLE STOCK CUSTODY CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'IN VEHICLE CUSTODY',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$inVehicle',
                          style: GoogleFonts.inter(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: inVehicle > 0 ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                          ),
                        ),
                        Text(
                          'Physical Units on Motorbike',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 2x2 Grid Summary
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildMatrixRow(
                                '🏢 Assigned by DC',
                                '$assigned Units',
                                '✅ Delivered',
                                '$delivered Units',
                                isDark,
                              ),
                              Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              _buildMatrixRow(
                                '⚠️ Returned / Defect',
                                '$returned Units',
                                '🛵 In Vehicle',
                                '$inVehicle Units',
                                isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. COMMERCIAL PACKAGES & DEALS SECTION
                  Row(
                    children: [
                      const Icon(Icons.local_offer_rounded, size: 16, color: Color(0xFFF37021)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Commercial Packages & Deals (${packages.length})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configured seller bundle deals. When orders include these packages, physical units are automatically tracked and deducted from your vehicle.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),

                  if (packages.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Standard single rate product (1 Unit = ${CurrencyFormatter.formatNaira(unitPrice)}).',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    )
                  else
                    ...packages.map((pkg) => _buildPackageCard(pkg, unitPrice, isDark)),

                  const SizedBox(height: 20),

                  // 3. TIED ACTIVE ORDERS REQUIRING THIS PRODUCT
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Active Orders Requiring this Stock (${tiedOrders.length})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (tiedOrders.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No pending deliveries currently waiting for this product.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...tiedOrders.map((ord) => _buildTiedOrderCard(ord, isDark, context)),

                  const SizedBox(height: 24),

                  // 4. ACTION BUTTONS (Return to DC & Reconcile Stock)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (item != null) {
                              ReturnStockModal.show(context, preselectedItem: item);
                            }
                          },
                          icon: const Icon(Icons.assignment_return_rounded, size: 16, color: Color(0xFFEA580C)),
                          label: Text(
                            'Return to DC',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push('/stock/audit');
                          },
                          icon: const Icon(Icons.fact_check_outlined, size: 16, color: Colors.white),
                          label: Text(
                            'Reconcile Stock',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPackageCard(ProductPackage pkg, double baseUnitPrice, bool isDark) {
    final savings = pkg.savingsAmount(baseUnitPrice);
    final savingsPct = pkg.savingsPercent(baseUnitPrice);
    final hasSavings = savings > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.packageName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📦 ${pkg.quantity} Physical Stock Unit${pkg.quantity > 1 ? 's' : ''} (${pkg.paidQuantity} Paid + ${pkg.freeQuantity} Free)',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(pkg.packagePrice),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                  ),
                  Text(
                    '${CurrencyFormatter.formatNaira(pkg.unitPrice)} / unit',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          if (hasSavings || (pkg.description != null && pkg.description!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (hasSavings)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🔥 Save ${CurrencyFormatter.formatNaira(savings)} (${savingsPct.toStringAsFixed(0)}% OFF)',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pkg.description!,
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTiedOrderCard(OrderEntity ord, bool isDark, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ord.orderNumber,
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${ord.customerName} • ${ord.deliveryCity}',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${ord.quantity} Physical Unit${ord.quantity > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatNaira(ord.totalAmount),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(String label1, String val1, String label2, String val2, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label1,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  val1,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label2,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  val2,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
