import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../dc_console/presentation/widgets/dc_product_detail_modal.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientProductsPage extends ConsumerStatefulWidget {
  const ClientProductsPage({super.key});

  @override
  ConsumerState<ClientProductsPage> createState() => _ClientProductsPageState();
}

class _ClientProductsPageState extends ConsumerState<ClientProductsPage> {
  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Register New Product', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name', hintText: 'e.g. Respira Detox Tea'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: skuCtrl,
                        decoration: const InputDecoration(labelText: 'SKU / Item Code', hintText: 'RSP-DTX-01'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'SKU required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: catCtrl,
                        decoration: const InputDecoration(labelText: 'Category', hintText: 'Health & Wellness'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Default Single Unit Price (₦)', hintText: '25000'),
                  validator: (v) => v == null || double.tryParse(v) == null ? 'Enter valid unit price' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Product Description (Optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final price = double.parse(priceCtrl.text);
                await ref.read(clientPortalProvider.notifier).createProduct(
                  name: nameCtrl.text.trim(),
                  sku: skuCtrl.text.trim().toUpperCase(),
                  category: catCtrl.text.trim(),
                  unitPrice: price,
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('Product created successfully and synced with DC catalog!'),
                    ),
                  );
                }
              }
            },
            child: const Text('Save Product'),
          ),
        ],
      ),
    );
  }

  void _showAddPackageDialog(CatalogProduct product) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '3');
    final paidQtyCtrl = TextEditingController(text: '3');
    final freeQtyCtrl = TextEditingController(text: '0');
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Commercial Package Deal for ${product.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Package / Deal Name', hintText: 'e.g. 3 Packs Family Bundle'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Package name is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Units', hintText: '3'),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: paidQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Paid Units', hintText: '3'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: freeQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bonus Units', hintText: '0'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Package Price (₦)', hintText: '50000'),
                  validator: (v) => v == null || double.tryParse(v) == null ? 'Enter valid price' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deal Description / Marketing Hook (Optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final totalQty = int.parse(qtyCtrl.text);
                final paidQty = int.tryParse(paidQtyCtrl.text) ?? totalQty;
                final freeQty = int.tryParse(freeQtyCtrl.text) ?? 0;
                final price = double.parse(priceCtrl.text);

                await ref.read(clientPortalProvider.notifier).createPackage(
                  productId: product.id,
                  productName: product.name,
                  packageName: nameCtrl.text.trim(),
                  quantity: totalQty,
                  paidQuantity: paidQty,
                  freeQuantity: freeQty,
                  packagePrice: price,
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('Commercial package deal created and available in order creation!'),
                    ),
                  );
                }
              }
            },
            child: const Text('Create Deal Bundle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(productCatalogProvider);
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final products = catalogState.products.isNotEmpty ? catalogState.products : state.products;

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Responsive Header Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Products & Package Bundles',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Configure retail products, promotional pricing, and multi-pack discount deals',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add Product', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (products.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 44, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),
                    Text('No products registered yet', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else
            ...products.map((product) {
              final packages = catalogState.getPackagesForProduct(product.name);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Banner Header (Responsive)
                    InkWell(
                      onTap: () => _openProductDetail(product),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCardWide = constraints.maxWidth >= 550;
                            return isCardWide
                                ? Row(
                                    children: [
                                      _buildProductIcon(product),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildProductDetails(product, isDark)),
                                      const SizedBox(width: 12),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                                              side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onPressed: () => _openProductDetail(product),
                                            icon: const Icon(Icons.warehouse_rounded, size: 14),
                                            label: Text(
                                              'Inspect Stock (${product.totalStockAcrossHubs})',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAddPackageButton(product),
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildProductIcon(product),
                                          const SizedBox(width: 10),
                                          Expanded(child: _buildProductDetails(product, isDark)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                                              side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onPressed: () => _openProductDetail(product),
                                            icon: const Icon(Icons.warehouse_rounded, size: 14),
                                            label: Text(
                                              'Inspect Stock (${product.totalStockAcrossHubs})',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAddPackageButton(product),
                                        ],
                                      ),
                                    ],
                                  );
                          },
                        ),
                      ),
                    ),

                    // Package Deals Sub-List
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_offer_rounded, size: 15, color: Color(0xFFF37021)),
                              const SizedBox(width: 6),
                              Text(
                                'Commercial Deal Packages (${packages.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (packages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No multi-pack bundles created yet. Click "+ Add Package Deal" to create high-converting promotional bundles.',
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isGridWide = constraints.maxWidth >= 600;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isGridWide ? 2 : 1,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: isGridWide ? 2.5 : 2.8,
                                  ),
                                  itemCount: packages.length,
                                  itemBuilder: (context, index) {
                                    final pkg = packages[index];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  pkg.packageName,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${pkg.quantity} Units',
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '₦${pkg.packagePrice.toStringAsFixed(0)} (₦${pkg.unitPrice.toStringAsFixed(0)}/unit)',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: const Color(0xFFF37021),
                                                ),
                                              ),
                                              if (pkg.freeQuantity > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '+${pkg.freeQuantity} FREE',
                                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              pkg.description!,
                                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openProductDetail(CatalogProduct product) {
    final stockState = ref.read(stockProvider);
    final dcState = ref.read(dcConsoleProvider);

    // Find matching stock item entity in central inventory
    StockItemEntity? matchedItem;
    for (final item in stockState.stockItems) {
      if (item.name.toLowerCase() == product.name.toLowerCase() ||
          item.sku.toLowerCase() == product.sku.toLowerCase()) {
        matchedItem = item;
        break;
      }
    }

    final stockItem = matchedItem ??
        StockItemEntity(
          id: product.id,
          name: product.name,
          sku: product.sku,
          category: product.category,
          price: product.defaultUnitPrice,
          assignedCount: product.totalStockAcrossHubs,
          deliveredCount: 0,
          availableCount: product.totalStockAcrossHubs,
          returnedCount: 0,
          imageAsset: product.imageUrl,
          description: product.category,
        );

    DCProductDetailModal.show(
      context,
      item: stockItem,
      drivers: dcState.drivers,
      allocations: stockState.riderAllocations,
    );
  }

  Widget _buildProductIcon(CatalogProduct product) {
    return ProductImageWidget(
      imageUrl: product.imageUrl,
      width: 48,
      height: 48,
      borderRadius: 10,
    );
  }

  Widget _buildProductDetails(CatalogProduct product, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                product.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.sku,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              'Retail: ₦${product.defaultUnitPrice.toStringAsFixed(0)} • ${product.category}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: product.totalStockAcrossHubs > 10
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stock: ${product.totalStockAcrossHubs} units',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: product.totalStockAcrossHubs > 10 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddPackageButton(CatalogProduct product) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF37021),
        side: const BorderSide(color: Color(0xFFF37021)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _showAddPackageDialog(product),
      icon: const Icon(Icons.add_rounded, size: 14),
      label: Text(
        'Add Deal Package',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
