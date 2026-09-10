import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientAddPackageModal extends ConsumerStatefulWidget {
  final CatalogProduct? preselectedProduct;
  final ProductPackage? existingPackageToEdit;

  const ClientAddPackageModal({
    super.key,
    this.preselectedProduct,
    this.existingPackageToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    CatalogProduct? product,
    ProductPackage? packageToEdit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientAddPackageModal(
        preselectedProduct: product,
        existingPackageToEdit: packageToEdit,
      ),
    );
  }

  @override
  ConsumerState<ClientAddPackageModal> createState() => _ClientAddPackageModalState();
}

class _ClientAddPackageModalState extends ConsumerState<ClientAddPackageModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _paidQtyController;
  late TextEditingController _freeQtyController;
  late TextEditingController _priceController;
  late TextEditingController _descController;

  CatalogProduct? _selectedProduct;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final editPkg = widget.existingPackageToEdit;

    _nameController = TextEditingController(text: editPkg?.packageName ?? '');
    _qtyController = TextEditingController(text: (editPkg?.quantity ?? 3).toString());
    _paidQtyController = TextEditingController(text: (editPkg?.paidQuantity ?? 3).toString());
    _freeQtyController = TextEditingController(text: (editPkg?.freeQuantity ?? 0).toString());
    _priceController = TextEditingController(
      text: editPkg != null ? editPkg.packagePrice.toStringAsFixed(0) : '',
    );
    _descController = TextEditingController(text: editPkg?.description ?? '');

    _selectedProduct = widget.preselectedProduct;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _paidQtyController.dispose();
    _freeQtyController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyPreset(String name, int qty, int paid, int free, double? multiplier) {
    setState(() {
      _nameController.text = name;
      _qtyController.text = qty.toString();
      _paidQtyController.text = paid.toString();
      _freeQtyController.text = free.toString();

      if (_selectedProduct != null && multiplier != null) {
        final calculatedPrice = (_selectedProduct!.defaultUnitPrice * multiplier).roundToDouble();
        _priceController.text = calculatedPrice.toStringAsFixed(0);
      }
    });
  }

  double get _currentPrice => double.tryParse(_priceController.text) ?? 0.0;
  int get _currentQty => int.tryParse(_qtyController.text) ?? 1;

  double get _effectiveUnitPrice {
    if (_currentQty <= 0) return _currentPrice;
    return _currentPrice / _currentQty;
  }

  double get _calculatedSavings {
    if (_selectedProduct == null || _currentQty <= 0) return 0.0;
    final regularTotal = _currentQty * _selectedProduct!.defaultUnitPrice;
    final diff = regularTotal - _currentPrice;
    return diff > 0 ? diff : 0.0;
  }

  double get _calculatedSavingsPct {
    if (_selectedProduct == null || _currentQty <= 0) return 0.0;
    final regularTotal = _currentQty * _selectedProduct!.defaultUnitPrice;
    if (regularTotal <= _currentPrice || regularTotal <= 0) return 0.0;
    return ((regularTotal - _currentPrice) / regularTotal) * 100.0;
  }

  List<DistributionCenter> _resolveCoveringDcs(List<DistributionCenter> allDcs) {
    if (_selectedProduct == null || _selectedProduct!.coveringStates.isEmpty) {
      return allDcs;
    }
    final states = _selectedProduct!.coveringStates.map((s) => s.toLowerCase().trim()).toList();
    return allDcs.where((dc) {
      final dcState = dc.state.toLowerCase().trim();
      return states.any((st) => dcState.contains(st) || st.contains(dcState));
    }).toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product for this package')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final isEdit = widget.existingPackageToEdit != null;
      final totalQty = int.parse(_qtyController.text);
      final paidQty = int.tryParse(_paidQtyController.text) ?? totalQty;
      final freeQty = int.tryParse(_freeQtyController.text) ?? 0;
      final price = double.parse(_priceController.text);
      final desc = _descController.text.trim().isNotEmpty ? _descController.text.trim() : null;

      if (isEdit) {
        await ref.read(clientPortalProvider.notifier).updatePackage(
          productName: _selectedProduct!.name,
          packageId: widget.existingPackageToEdit!.id,
          packageName: _nameController.text.trim(),
          quantity: totalQty,
          paidQuantity: paidQty,
          freeQuantity: freeQty,
          packagePrice: price,
          description: desc,
        );
      } else {
        await ref.read(clientPortalProvider.notifier).createPackage(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          packageName: _nameController.text.trim(),
          quantity: totalQty,
          paidQuantity: paidQty,
          freeQuantity: freeQty,
          packagePrice: price,
          description: desc,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit
                        ? 'Package Deal "${_nameController.text.trim()}" updated successfully!'
                        : 'Package Deal "${_nameController.text.trim()}" created and extended to covering DCs!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error saving package: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final catalogState = ref.watch(productCatalogProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final clientState = ref.watch(clientPortalProvider);

    final availableProducts = catalogState.products.isNotEmpty
        ? catalogState.products
        : clientState.products;

    if (_selectedProduct == null && availableProducts.isNotEmpty) {
      _selectedProduct = availableProducts.first;
    }

    final coveringDcs = _resolveCoveringDcs(dcState.distributionCenters);
    final isEdit = widget.existingPackageToEdit != null;

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294A) : const Color(0xFFFFF7ED),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_offer_rounded, color: Color(0xFFF37021), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Commercial Package Deal' : 'Create Commercial Package Deal',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bundle pricing and stock deduction rules extended across covering DCs',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            ),

            // Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Selection
                      Text(
                        'Target Product',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedProduct?.id,
                        decoration: _inputDecoration(isDark, 'Select Product', prefixIcon: Icons.inventory_2_outlined),
                        isExpanded: true,
                        items: availableProducts.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} (SKU: ${p.sku}) • ₦${p.defaultUnitPrice.toStringAsFixed(0)}'),
                          );
                        }).toList(),
                        onChanged: isEdit
                            ? null
                            : (id) {
                                if (id != null) {
                                  setState(() {
                                    _selectedProduct = availableProducts.firstWhere((p) => p.id == id);
                                  });
                                }
                              },
                        validator: (v) => v == null || v.isEmpty ? 'Select product' : null,
                      ),
                      const SizedBox(height: 16),

                      // Presets Quick-Selector
                      if (!isEdit && _selectedProduct != null) ...[
                        Text(
                          'Quick Deal Presets',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildPresetChip('2-Pack Deal', 2, 2, 0, 1.7, isDark),
                            _buildPresetChip('3-Pack Value', 3, 3, 0, 2.3, isDark),
                            _buildPresetChip('4+1 Free Mega Deal', 5, 4, 1, 3.2, isDark),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Package Name
                      Text(
                        'Package / Deal Name',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          isDark,
                          'e.g. 3-Pack Family Value Bundle',
                          prefixIcon: Icons.card_giftcard_rounded,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Package name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Quantities Row: Total, Paid, Bonus
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Units',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(isDark, '3'),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    if (n == null || n <= 0) return 'Required';
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
                                Text(
                                  'Paid Units',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _paidQtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(isDark, '3'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Free / Bonus',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _freeQtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(isDark, '0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selling Price
                      Text(
                        'Total Package Selling Price (₦)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          isDark,
                          'e.g. 50000',
                          prefixIcon: Icons.payments_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final p = double.tryParse(v ?? '');
                          if (p == null || p <= 0) return 'Valid price required';
                          return null;
                        },
                      ),

                      // Live Effective Price & Savings Indicator
                      if (_currentPrice > 0 && _currentQty > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37021).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Effective Price: ${CurrencyFormatter.formatNaira(_effectiveUnitPrice)} / unit',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: const Color(0xFFF37021),
                                    ),
                                  ),
                                  Text(
                                    'Deducts $_currentQty physical units on order placement',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              if (_calculatedSavings > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Saves ${CurrencyFormatter.formatNaira(_calculatedSavings)} (${_calculatedSavingsPct.toStringAsFixed(0)}%)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Deal Description / Marketing Hook
                      Text(
                        'Deal Description / Closer Pitch (Optional)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          isDark,
                          'e.g. Best seller package for 30-day treatment with free detox booster.',
                        ),
                      ),
                      const SizedBox(height: 18),

                      // DC Coverage & Availability Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E294A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.hub_rounded, size: 15, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  'Distribution Centers Coverage (${coveringDcs.length} Hubs)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedProduct != null && _selectedProduct!.coveringStates.isNotEmpty
                                  ? 'This package will be visible and operational in all DCs covering: ${_selectedProduct!.coveringStates.join(", ")}.'
                                  : 'This package is available across all nationwide Distribution Centers in the NovaExpress network.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Create & Extend Package to DCs',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int qty, int paid, int free, double multiplier, bool isDark) {
    return ActionChip(
      backgroundColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFFFF7ED),
      side: const BorderSide(color: Color(0xFFF37021), width: 0.8),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
      ),
      onPressed: () => _applyPreset(
        '${_selectedProduct?.name ?? "Product"} $label',
        qty,
        paid,
        free,
        multiplier,
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E294A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF37021), width: 1.5),
      ),
    );
  }
}
