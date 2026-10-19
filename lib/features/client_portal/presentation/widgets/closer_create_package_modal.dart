import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../providers/client_portal_provider.dart';

class CloserCreatePackageModal extends ConsumerStatefulWidget {
  final CatalogProduct? initialProduct;
  final ProductPackage? packageToEdit;

  const CloserCreatePackageModal({
    super.key,
    this.initialProduct,
    this.packageToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    CatalogProduct? product,
    ProductPackage? packageToEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CloserCreatePackageModal(
        initialProduct: product,
        packageToEdit: packageToEdit,
      ),
    );
  }

  @override
  ConsumerState<CloserCreatePackageModal> createState() => _CloserCreatePackageModalState();
}

class _CloserCreatePackageModalState extends ConsumerState<CloserCreatePackageModal> {
  final _formKey = GlobalKey<FormState>();

  CatalogProduct? _selectedProduct;
  late final TextEditingController _packageNameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _paidQuantityController;
  late final TextEditingController _freeQuantityController;
  late final TextEditingController _packagePriceController;
  late final TextEditingController _descriptionController;

  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get isEditing => widget.packageToEdit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.packageToEdit;

    _packageNameController = TextEditingController(text: edit?.packageName ?? '2-Pack Value Bundle');
    _quantityController = TextEditingController(text: edit != null ? edit.quantity.toString() : '2');
    _paidQuantityController = TextEditingController(text: edit != null ? edit.paidQuantity.toString() : '2');
    _freeQuantityController = TextEditingController(text: edit != null ? edit.freeQuantity.toString() : '0');
    _packagePriceController = TextEditingController(text: edit != null ? edit.packagePrice.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');

    _selectedProduct = widget.initialProduct;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedProduct == null && edit != null) {
        final catalog = ref.read(productCatalogProvider);
        final found = catalog.findProductByName(edit.productName) ??
            (edit.productSku != null ? catalog.findProductBySku(edit.productSku!) : null);
        if (found != null && mounted) {
          setState(() => _selectedProduct = found);
        }
      }

      if (!isEditing && _selectedProduct != null && _packagePriceController.text.isEmpty) {
        _packagePriceController.text = (_selectedProduct!.defaultUnitPrice * 2 * 0.9).toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    _quantityController.dispose();
    _paidQuantityController.dispose();
    _freeQuantityController.dispose();
    _packagePriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onProductChanged(CatalogProduct? prod) {
    setState(() {
      _selectedProduct = prod;
      if (prod != null && !isEditing) {
        final qty = int.tryParse(_quantityController.text) ?? 2;
        _packagePriceController.text = (prod.defaultUnitPrice * qty * 0.9).toStringAsFixed(0);
        if (_packageNameController.text.isEmpty) {
          _packageNameController.text = '$qty-Pack Commercial Bundle';
        }
      }
    });
  }

  void _syncQuantitiesFromTotal(String v) {
    final total = int.tryParse(v) ?? 1;
    final free = int.tryParse(_freeQuantityController.text) ?? 0;
    final newPaid = (total - free).clamp(1, 999999);
    _paidQuantityController.text = newPaid.toString();

    if (_selectedProduct != null && !isEditing) {
      _packagePriceController.text = (_selectedProduct!.defaultUnitPrice * newPaid * 0.95).toStringAsFixed(0);
    }
    setState(() {});
  }

  void _syncQuantitiesFromComponents() {
    final paid = int.tryParse(_paidQuantityController.text) ?? 1;
    final free = int.tryParse(_freeQuantityController.text) ?? 0;
    _quantityController.text = (paid + free).toString();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target product for this package deal.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final qty = int.tryParse(_quantityController.text.trim()) ?? 1;
      final paidQty = int.tryParse(_paidQuantityController.text.trim()) ?? qty;
      final freeQty = int.tryParse(_freeQuantityController.text.trim()) ?? 0;
      final price = double.tryParse(_packagePriceController.text.trim().replaceAll(',', '')) ??
          (_selectedProduct!.defaultUnitPrice * qty);

      if (isEditing) {
        // Update existing package
        final updatedPkg = await ref.read(clientPortalProvider.notifier).updatePackage(
              productName: _selectedProduct!.name,
              packageId: widget.packageToEdit!.id,
              packageName: _packageNameController.text.trim(),
              quantity: qty,
              paidQuantity: paidQty,
              freeQuantity: freeQty,
              packagePrice: price,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Package "${updatedPkg?.packageName ?? _packageNameController.text}" updated successfully!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Create new package
        final pkg = await ref.read(clientPortalProvider.notifier).createPackage(
              productId: _selectedProduct!.id,
              productName: _selectedProduct!.name,
              packageName: _packageNameController.text.trim(),
              quantity: qty,
              paidQuantity: paidQty,
              freeQuantity: freeQty,
              packagePrice: price,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Package "${pkg.packageName}" created successfully for ${_selectedProduct!.name}!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to save package: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmDeletePackage() async {
    final pkg = widget.packageToEdit;
    if (pkg == null || _selectedProduct == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Delete Package Deal?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${pkg.packageName}" from ${_selectedProduct!.name}? Existing historical orders will retain their records, but it will no longer be available for new orders.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        final success = await ref.read(clientPortalProvider.notifier).deletePackage(
              productName: _selectedProduct!.name,
              packageId: pkg.id,
            );

        if (mounted && success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Text('Package "${pkg.packageName}" deleted successfully.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('Failed to delete package: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    final availableProducts = clientState.products;

    final currentTotal = int.tryParse(_quantityController.text) ?? 1;
    final currentPaid = int.tryParse(_paidQuantityController.text) ?? currentTotal;
    final currentFree = int.tryParse(_freeQuantityController.text) ?? 0;
    final currentPrice = double.tryParse(_packagePriceController.text.replaceAll(',', '')) ?? 0.0;
    final effectivePerUnit = currentPaid > 0 ? (currentPrice / currentPaid) : 0.0;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37021).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF37021), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Package Deal' : 'Create Package Deal',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                isEditing
                                    ? 'Update bundle units, bonus items & pricing'
                                    : 'Add commercial bundle to client catalog',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Selector
                      Text(
                        'Target Product *',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final seenIds = <String>{};
                          final seenSkus = <String>{};
                          final distinctProducts = <CatalogProduct>[];
                          for (final p in availableProducts) {
                            final idKey = p.id.trim();
                            final skuKey = p.sku.trim().toUpperCase();
                            if (idKey.isNotEmpty && seenIds.contains(idKey)) continue;
                            if (skuKey.isNotEmpty && seenSkus.contains(skuKey)) continue;
                            if (idKey.isNotEmpty) seenIds.add(idKey);
                            if (skuKey.isNotEmpty) seenSkus.add(skuKey);
                            distinctProducts.add(p);
                          }

                          if (_selectedProduct != null) {
                            final hasSelected = distinctProducts.any((p) => p == _selectedProduct);
                            if (!hasSelected) {
                              distinctProducts.insert(0, _selectedProduct!);
                            }
                          }

                          CatalogProduct? effectiveProduct;
                          if (_selectedProduct != null) {
                            effectiveProduct = distinctProducts.cast<CatalogProduct?>().firstWhere(
                              (p) => p != null && (p == _selectedProduct || p.name == _selectedProduct?.name),
                              orElse: () => null,
                            );
                          }
                          if (effectiveProduct == null && distinctProducts.isNotEmpty) {
                            effectiveProduct = distinctProducts.first;
                          }

                          return DropdownButtonFormField<CatalogProduct>(
                            value: effectiveProduct,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFFF37021)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                            ),
                            items: distinctProducts.map((p) {
                              return DropdownMenuItem<CatalogProduct>(
                                value: p,
                                child: Text(
                                  '${p.name} (${currencyFormatter.format(p.defaultUnitPrice)})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: isEditing ? null : _onProductChanged,
                            validator: (v) => v == null ? 'Please choose a product' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Package Deal Name
                      Text(
                        'Package Deal Name *',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _packageNameController,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. 3-Pack Mega Deal (2 + 1 Free)',
                          prefixIcon: const Icon(Icons.loyalty_outlined, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Package name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Quantities Row: Total Units, Paid Units, Free Units
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Units *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: '3',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                  ),
                                  onChanged: _syncQuantitiesFromTotal,
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    if (n == null || n < 1) return 'Min 1';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paid Units *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _paidQuantityController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: '2',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                  ),
                                  onChanged: (_) => _syncQuantitiesFromComponents(),
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    if (n == null || n < 1) return 'Min 1';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Free Units', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _freeQuantityController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: '1',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                                  ),
                                  onChanged: (_) => _syncQuantitiesFromComponents(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Live Unit Count & Calculation Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Physical Count: $currentTotal units ($currentPaid Paid + $currentFree Free)',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                            ),
                            if (effectivePerUnit > 0)
                              Text(
                                '~${currencyFormatter.format(effectivePerUnit)} / unit',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Package Deal Total Price
                      Text(
                        'Total Commercial Package Price (₦) *',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _packagePriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                        decoration: InputDecoration(
                          hintText: '45000',
                          prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFFF37021)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Package price is required';
                          final num = double.tryParse(v.replaceAll(',', ''));
                          if (num == null || num <= 0) return 'Enter a valid price greater than 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description & Pitch
                      Text(
                        'Commercial Pitch / Description Notes',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. Recommended for 60-day recovery. Includes free detox guide.',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _isDeleting) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF37021),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isEditing ? 'Save Package Changes' : 'Create Commercial Package',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: (_isSubmitting || _isDeleting) ? null : _confirmDeletePackage,
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                        label: Text(
                          'Delete Package Deal',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFFEF4444), fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
