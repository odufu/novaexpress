import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
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
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      '${item.sku} • ${item.category} • ${item.ownerName}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(item),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Product Specs Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('🏢 Merchant / Company:', item.ownerName, isDark, isBold: true),
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          '💰 Single Unit Retail Price:',
                          CurrencyFormatter.formatNaira(item.price),
                          isDark,
                          valueColor: const Color(0xFF10B981),
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow('📍 Storage Bin Location:', item.binLocation ?? 'BIN-A1-01', isDark),
                        const SizedBox(height: 6),
                        _buildDetailRow('🏷️ Batch / Lot Code:', item.batchNumber ?? 'LOT-2026-08', isDark),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildDetailRow('📝 Description:', item.description, isDark),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Stock Numbers (4 Grid)
                  Text('📊 Inventory & Physical Custody Accounting', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStockStatTile(
                          '🏢 In DC Possession',
                          '${item.availableCount} Units',
                          'Available to assign',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStockStatTile(
                          '🛵 In Rider Custody',
                          '${item.inRiderCustodyCount} Units',
                          'In transit with riders',
                          const Color(0xFF8B5CF6),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStockStatTile(
                          '✅ Delivered Units',
                          '${item.deliveredCount} Units',
                          'Fulfilled to buyers',
                          const Color(0xFF2563EB),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStockStatTile(
                          '⚠️ Reported / Damaged',
                          '${item.complaintCount} Units',
                          'Reported issues',
                          item.complaintCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                          isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. COMMERCIAL PACKAGES SECTION
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer_rounded, size: 16, color: Color(0xFFF37021)),
                          const SizedBox(width: 6),
                          Text(
                            'Commercial Packages & Bundles (${packages.length})',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateOrEditPackageDialog(context, isDark, item),
                        icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        label: const Text('+ Create Package Deal', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF37021),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configured package deals (e.g. 5 Grazer Tea for ₦55,000). Orders attach these packages to deduct the exact physical units from stock.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),

                  if (packages.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No custom packages yet. Click "+ Create Package Deal" to create bulk or promo packages.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    )
                  else
                    ...packages.map((pkg) => _buildPackageCard(pkg, item, isDark)),

                  const SizedBox(height: 20),

                  // 5. Riders in Custody
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🛵 Riders Holding Vehicle Stock (${productAllocations.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (productAllocations.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('No riders currently hold this product in vehicle custody.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    )
                  else
                    ...productAllocations.map((alloc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(alloc.riderName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(alloc.riderCode, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${alloc.inCustodyUnits} Units in Vehicle',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 6. Action Footer
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                if (widget.onReportDamage != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReportDamage!();
                    },
                    icon: const Icon(Icons.report_problem_outlined, size: 14, color: Color(0xFFEF4444)),
                    label: const Text('Report Damage / Loss', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.5)),
                  ),
                const SizedBox(width: 8),
                if (widget.onReceiveMoreStock != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReceiveMoreStock!();
                    },
                    icon: const Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                    label: const Text('Receive Stock', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  ),
                const SizedBox(width: 8),
                if (widget.onAssignToRider != null)
                  ElevatedButton.icon(
                    onPressed: item.availableCount > 0
                        ? () {
                            Navigator.of(context).pop();
                            widget.onAssignToRider!();
                          }
                        : null,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                    label: const Text('Assign to Rider', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_rounded, color: Color(0xFFF37021), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.packageName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '📦 ${pkg.quantity} Physical Stock Unit${pkg.quantity > 1 ? 's' : ''} (${pkg.paidQuantity} Paid + ${pkg.freeQuantity} Free)',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
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
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasSavings)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔥 Save ${CurrencyFormatter.formatNaira(savings)} (${savingsPct.toStringAsFixed(0)}% OFF)',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                if (hasSavings && pkg.description != null && pkg.description!.isNotEmpty)
                  const SizedBox(width: 8),
                if (pkg.description != null && pkg.description!.isNotEmpty)
                  Expanded(
                    child: Text(
                      pkg.description!,
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Edit Package Deal Button
              OutlinedButton.icon(
                onPressed: () => _showCreateOrEditPackageDialog(context, isDark, item, existingPackage: pkg),
                icon: const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF2563EB)),
                label: const Text('Edit Deal', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (ctx) => const DCCreateOrderModal(),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 13, color: Colors.white),
                label: const Text('Create Order with this Package', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockStatTile(String title, String value, String subtitle, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
