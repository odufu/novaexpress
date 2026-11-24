import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/admin_models.dart';

/// Modal dialog opened when tapping a stock holder row in the Multi-Hub Stock table.
/// Displays holder details, held product quantities breakdown, stock valuation, and scoped actions.
class AdminStockHolderDetailModal extends StatelessWidget {
  final AdminStockHolderRow holder;
  final List<AdminGlobalStockItem> allProducts;
  final VoidCallback? onInboundQc;
  final VoidCallback? onOnboardProduct;
  final VoidCallback? onEditAgent;
  final VoidCallback? onAssignMerchants;
  final VoidCallback? onManageCustody;

  const AdminStockHolderDetailModal({
    super.key,
    required this.holder,
    required this.allProducts,
    this.onInboundQc,
    this.onOnboardProduct,
    this.onEditAgent,
    this.onAssignMerchants,
    this.onManageCustody,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminStockHolderRow holder,
    required List<AdminGlobalStockItem> allProducts,
    VoidCallback? onInboundQc,
    VoidCallback? onOnboardProduct,
    VoidCallback? onEditAgent,
    VoidCallback? onAssignMerchants,
    VoidCallback? onManageCustody,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AdminStockHolderDetailModal(
        holder: holder,
        allProducts: allProducts,
        onInboundQc: onInboundQc,
        onOnboardProduct: onOnboardProduct,
        onEditAgent: onEditAgent,
        onAssignMerchants: onAssignMerchants,
        onManageCustody: onManageCustody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isShelf = holder.isDcShelf;
    final isInternal = holder.isInternalFleet;
    final brandColor = isShelf
        ? const Color(0xFF10B981)
        : (isInternal ? const Color(0xFF2563EB) : const Color(0xFF0284C7));

    // Calculate itemized products held with their unit prices and values
    // Matches by SKU, product ID, product name, or case-insensitive string
    final List<Map<String, dynamic>> heldProductsList = [];
    final Set<String> matchedKeys = {};

    for (final p in allProducts) {
      int qty = 0;
      if (holder.productQuantities.containsKey(p.sku)) {
        qty = holder.productQuantities[p.sku]!;
        matchedKeys.add(p.sku);
      } else if (holder.productQuantities.containsKey(p.id)) {
        qty = holder.productQuantities[p.id]!;
        matchedKeys.add(p.id);
      } else if (holder.productQuantities.containsKey(p.productName)) {
        qty = holder.productQuantities[p.productName]!;
        matchedKeys.add(p.productName);
      } else {
        for (final entry in holder.productQuantities.entries) {
          final k = entry.key.toLowerCase().trim();
          if (k == p.sku.toLowerCase().trim() ||
              k == p.productName.toLowerCase().trim() ||
              k.contains(p.productName.toLowerCase().trim()) ||
              p.productName.toLowerCase().trim().contains(k)) {
            qty = entry.value;
            matchedKeys.add(entry.key);
            break;
          }
        }
      }

      if (qty > 0) {
        heldProductsList.add({
          'name': p.productName,
          'sku': p.sku,
          'merchantName': p.merchantName,
          'qty': qty,
          'unitPrice': p.unitPrice,
          'value': qty * p.unitPrice,
        });
      }
    }

    // Also include any other items in holder.productQuantities with qty > 0 that weren't matched
    holder.productQuantities.forEach((key, qty) {
      if (qty > 0 && !matchedKeys.contains(key)) {
        heldProductsList.add({
          'name': key,
          'sku': key,
          'merchantName': 'Platform Merchant',
          'qty': qty,
          'unitPrice': 0.0,
          'value': 0.0,
        });
      }
    });

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isShelf
                          ? Icons.warehouse_rounded
                          : (isInternal ? Icons.local_shipping_rounded : Icons.delivery_dining_rounded),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                holder.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: brandColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isShelf ? 'WAREHOUSE SHELF' : (isInternal ? 'INTERNAL FLEET' : '3PL PARTNER'),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: brandColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Code: ${holder.code} • Operating Hub: ${holder.hubName} • Phone: ${holder.phone.isNotEmpty ? holder.phone : "Direct Channel"}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Metric Cards Ribbon
                    Row(
                      children: [
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Total Custody Stock',
                          value: '${holder.totalUnits} units',
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Stock Valuation',
                          value: CurrencyFormatter.formatNaira(holder.totalValueNaira),
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile(
                          isDark: isDark,
                          title: 'Products Stocked',
                          value: '${heldProductsList.length} SKUs',
                          icon: Icons.category_rounded,
                          color: const Color(0xFFF97316),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Merchants Served
                    Text(
                      'Merchants Served',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: holder.assignedMerchantNames.map((merchantName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 6),
                              Text(
                                merchantName,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Itemized Stock Holding Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Held Inventory Breakdown',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${holder.totalUnits} Total Units',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (heldProductsList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'No active stock currently allocated to this custodian.',
                            style: GoogleFonts.inter(fontSize: 12.5, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: heldProductsList.map((item) {
                            final name = item['name'] as String;
                            final sku = item['sku'] as String;
                            final merchantName = item['merchantName'] as String;
                            final qty = item['qty'] as int;
                            final value = item['value'] as double;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'SKU: $sku • Partner: $merchantName',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$qty units',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.formatNaira(value),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isShelf && onInboundQc != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Inbound QC Restock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onInboundQc?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isShelf && onOnboardProduct != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_box_outlined, size: 16),
                      label: const Text('Onboard Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOnboardProduct?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isShelf && onManageCustody != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Adjust Custody Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onManageCustody?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isShelf && onEditAgent != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Agent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEditAgent?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
