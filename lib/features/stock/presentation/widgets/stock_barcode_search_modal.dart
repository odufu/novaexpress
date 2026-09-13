import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';

class StockBarcodeSearchModal extends ConsumerStatefulWidget {
  const StockBarcodeSearchModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StockBarcodeSearchModal(),
    );
  }

  @override
  ConsumerState<StockBarcodeSearchModal> createState() => _StockBarcodeSearchModalState();
}

class _StockBarcodeSearchModalState extends ConsumerState<StockBarcodeSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  StockItemEntity? _matchedVehicleItem;
  CatalogProduct? _matchedCatalogProduct;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _performLookup(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _matchedVehicleItem = null;
        _matchedCatalogProduct = null;
        _hasSearched = false;
      });
      return;
    }

    final stockItems = ref.read(stockProvider).stockItems;
    final catalogProducts = ref.read(productCatalogProvider).products;

    StockItemEntity? foundVehicleItem;
    for (final item in stockItems) {
      final b = item.barcode?.toLowerCase() ?? '';
      final s = item.sku.toLowerCase();
      if (b == query || s == query || (b.isNotEmpty && b.contains(query)) || s.contains(query)) {
        foundVehicleItem = item;
        break;
      }
    }

    CatalogProduct? foundCatalogProduct;
    if (foundVehicleItem == null) {
      for (final prod in catalogProducts) {
        final b = prod.barcode?.toLowerCase() ?? '';
        final s = prod.sku.toLowerCase();
        if (b == query || s == query || (b.isNotEmpty && b.contains(query)) || s.contains(query)) {
          foundCatalogProduct = prod;
          break;
        }
      }
    }

    setState(() {
      _matchedVehicleItem = foundVehicleItem;
      _matchedCatalogProduct = foundCatalogProduct;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockItems = ref.watch(stockProvider).stockItems;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Barcode Lookup',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Scan or type product Barcode / SKU',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter barcode digits (e.g. 0123456789) or SKU',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _performLookup('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onChanged: _performLookup,
              onSubmitted: _performLookup,
            ),
          ),
          const SizedBox(height: 12),

          // Quick-pick Chips (from active items in custody)
          if (stockItems.isNotEmpty && !_hasSearched) ...[
            Text(
              'Quick Lookup (In Custody):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stockItems.take(4).map((it) {
                  final code = it.barcode?.isNotEmpty == true ? it.barcode! : it.sku;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        '${it.name.split(" ").first}: $code',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11),
                      ),
                      onPressed: () {
                        _searchCtrl.text = code;
                        _performLookup(code);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Search Results
          if (_hasSearched) ...[
            const SizedBox(height: 8),
            if (_matchedVehicleItem != null) ...[
              // Case 1: In Vehicle Custody
              _buildVehicleItemFoundCard(_matchedVehicleItem!, isDark, context),
            ] else if (_matchedCatalogProduct != null) ...[
              // Case 2: In DC Catalog but not in vehicle
              _buildCatalogProductOnlyCard(_matchedCatalogProduct!, isDark, context),
            ] else ...[
              // Case 3: Not found
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Not Found',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No product matched "${_searchCtrl.text}". Check the code or contact your DC supervisor.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleItemFoundCard(StockItemEntity item, bool isDark, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'IN VEHICLE CUSTODY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${item.availableCount} Units on Bike',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'SKU: ${item.sku}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('•', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                Text(
                  'BAR: ${item.barcode}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF8B5CF6)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Unit Price: ${CurrencyFormatter.formatNaira(item.price)}',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(stockProvider.notifier).setSearchQuery(item.name);
                  },
                  icon: const Icon(Icons.filter_list_rounded, size: 15),
                  label: Text('Filter List', style: GoogleFonts.inter(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/stock/details/${item.name}', extra: item);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                  label: Text('View Details', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogProductOnlyCard(CatalogProduct product, bool isDark, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'NOT IN VEHICLE CUSTODY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '0 Units on Bike',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'SKU: ${product.sku}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('•', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                Text(
                  'BAR: ${product.barcode}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: const Color(0xFF8B5CF6)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SKU not in current vehicle custody. Check DC warehouse stock.',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFEA580C), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/stock/request');
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: Color(0xFF2563EB)),
              label: Text('Request Stock from DC', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
