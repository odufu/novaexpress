import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/location_lookup_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientEditOrderModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const ClientEditOrderModal({
    super.key,
    required this.order,
  });

  static Future<bool?> show(BuildContext context, OrderEntity order) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientEditOrderModal(order: order),
    );
  }

  @override
  ConsumerState<ClientEditOrderModal> createState() => _ClientEditOrderModalState();
}

class _ClientEditOrderModalState extends ConsumerState<ClientEditOrderModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _customerAltPhoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late final TextEditingController _paidQuantityController;
  late final TextEditingController _freeQuantityController;
  late final TextEditingController _totalQuantityController;
  late final TextEditingController _priceController;

  late String _selectedState;
  String? _selectedLga;
  List<String> _availableLgas = [];

  CatalogProduct? _selectedProduct;
  ProductPackage? _selectedPackage;
  bool _isCustomPackage = false;
  late String _paymentType;
  bool _isSubmitting = false;

  final _currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final o = widget.order;

    _customerNameController = TextEditingController(text: o.customerName);
    _customerPhoneController = TextEditingController(text: o.customerPhone);
    _customerAltPhoneController = TextEditingController(text: o.customerAltPhone ?? '');
    _addressController = TextEditingController(text: o.deliveryAddress);
    _notesController = TextEditingController(text: o.deliveryNotes ?? o.landmark ?? '');

    final totalQty = o.totalPhysicalQuantity > 0 ? o.totalPhysicalQuantity : o.quantity;
    final paidQty = o.paidQuantity > 0 ? o.paidQuantity : (totalQty - (o.freeQuantity > 0 ? o.freeQuantity : 0));
    final freeQty = o.freeQuantity >= 0 ? o.freeQuantity : 0;

    _paidQuantityController = TextEditingController(text: paidQty.toString());
    _freeQuantityController = TextEditingController(text: freeQty.toString());
    _totalQuantityController = TextEditingController(text: totalQty.toString());
    _priceController = TextEditingController(text: o.totalAmount.toStringAsFixed(0));

    _paymentType = o.paymentType.trim().isNotEmpty ? o.paymentType : 'Pay on Delivery (Cash/POS)';

    // Initialize State & LGA
    _selectedState = LocationLookupService.normalizeStateName(o.deliveryState);
    _loadLgas(preselectedLga: o.lga ?? o.deliveryCity);

    // Initialize Product & Package selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProductAndPackage();
    });
  }

  void _loadLgas({String? preselectedLga}) {
    final lgas = LocationLookupService.getLgasForState(_selectedState);
    setState(() {
      _availableLgas = lgas;
      if (preselectedLga != null && lgas.any((l) => l.toLowerCase() == preselectedLga.toLowerCase())) {
        _selectedLga = lgas.firstWhere((l) => l.toLowerCase() == preselectedLga.toLowerCase());
      } else if (lgas.isNotEmpty) {
        _selectedLga = lgas.first;
      } else {
        _selectedLga = null;
      }
    });
  }

  void _initProductAndPackage() {
    final catalog = ref.read(productCatalogProvider);
    final o = widget.order;

    CatalogProduct? foundProd;
    if (o.productId != null && o.productId!.isNotEmpty) {
      foundProd = catalog.products.where((p) => p.id == o.productId).firstOrNull;
    }
    if (foundProd == null && o.productSku != null && o.productSku!.isNotEmpty) {
      foundProd = catalog.findProductBySku(o.productSku!);
    }
    if (foundProd == null && o.productName.isNotEmpty) {
      foundProd = catalog.findProductByName(o.productName);
    }
    if (foundProd == null && catalog.products.isNotEmpty) {
      foundProd = catalog.products.first;
    }

    ProductPackage? foundPkg;
    if (foundProd != null) {
      final pkgs = catalog.getPackagesForProduct(foundProd.name);
      if (o.packageDealId != null && o.packageDealId!.isNotEmpty) {
        foundPkg = pkgs.where((p) => p.id == o.packageDealId).firstOrNull;
      }
      if (foundPkg == null && o.packageDealName != null && o.packageDealName!.isNotEmpty) {
        foundPkg = pkgs.where((p) => p.packageName.toLowerCase() == o.packageDealName!.toLowerCase()).firstOrNull;
      }
    }

    if (mounted) {
      setState(() {
        _selectedProduct = foundProd;
        _selectedPackage = foundPkg;
        _isCustomPackage = (foundPkg == null && (o.packageDealName == null || o.packageDealName!.isEmpty));
      });
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAltPhoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _paidQuantityController.dispose();
    _freeQuantityController.dispose();
    _totalQuantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onPackageSelected(ProductPackage? pkg) {
    setState(() {
      _selectedPackage = pkg;
      _isCustomPackage = (pkg == null);
      if (pkg != null) {
        _paidQuantityController.text = pkg.paidQuantity.toString();
        _freeQuantityController.text = pkg.freeQuantity.toString();
        _totalQuantityController.text = pkg.quantity.toString();
        _priceController.text = pkg.packagePrice.toStringAsFixed(0);
      }
    });
  }

  void _syncQuantitiesFromComponents() {
    final paid = int.tryParse(_paidQuantityController.text) ?? 1;
    final free = int.tryParse(_freeQuantityController.text) ?? 0;
    final total = paid + free;
    _totalQuantityController.text = total.toString();
    setState(() {});
  }

  void _syncQuantitiesFromTotal(String v) {
    final total = int.tryParse(v) ?? 1;
    final free = int.tryParse(_freeQuantityController.text) ?? 0;
    final paid = (total - free).clamp(1, 999999);
    _paidQuantityController.text = paid.toString();
    if (_selectedProduct != null && _isCustomPackage) {
      _priceController.text = (_selectedProduct!.defaultUnitPrice * paid).toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLga == null || _selectedLga!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please select a valid Delivery LGA.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final totalQty = int.tryParse(_totalQuantityController.text.trim()) ?? 1;
      final paidQty = int.tryParse(_paidQuantityController.text.trim()) ?? totalQty;
      final freeQty = int.tryParse(_freeQuantityController.text.trim()) ?? 0;
      final price = double.tryParse(_priceController.text.trim().replaceAll(',', '')) ?? widget.order.totalAmount;

      final pkgName = _selectedPackage?.packageName ??
          (_isCustomPackage
              ? (freeQty > 0 ? '$paidQty-Pack + $freeQty Free Deal' : '$totalQty-Unit Package')
              : widget.order.packageDealName);

      final updates = <String, dynamic>{
        'customer_name': _customerNameController.text.trim(),
        'customer_phone': _customerPhoneController.text.trim(),
        'customer_alt_phone': _customerAltPhoneController.text.trim().isNotEmpty
            ? _customerAltPhoneController.text.trim()
            : null,
        'delivery_state': _selectedState,
        'delivery_city': _selectedLga,
        'delivery_lga': _selectedLga,
        'lga': _selectedLga,
        'delivery_address': _addressController.text.trim(),
        'delivery_notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        'payment_type': _paymentType,
        'product_name': _selectedProduct?.name ?? widget.order.productName,
        'product_id': _selectedProduct?.id ?? widget.order.productId,
        'product_sku': _selectedProduct?.sku ?? widget.order.productSku,
        'package_deal_id': _selectedPackage?.id,
        'package_deal_name': pkgName,
        'quantity': totalQty,
        'paid_quantity': paidQty,
        'free_quantity': freeQty,
        'base_price': price,
        'total_amount': price,
      };

      // 1. Update in ClientPortalProvider (updates Supabase orders table)
      final success1 = await ref.read(clientPortalProvider.notifier).updateOrderDetails(
            orderId: widget.order.id,
            updates: updates,
          );

      // 2. Also update in OrdersProvider state
      try {
        await ref.read(ordersProvider.notifier).updateOrderDetails(
              orderId: widget.order.id,
              updates: updates,
            );
      } catch (_) {}

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success1) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order ${widget.order.orderNumber} updated! Deal: $pkgName (${_currencyFormatter.format(price)})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFEF4444),
              content: Text('Failed to update order. Please check network connection.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error updating order: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    final catalog = ref.watch(productCatalogProvider);
    final clientProducts = ref.watch(clientPortalProvider).products;
    final availableProducts = clientProducts.isNotEmpty ? clientProducts : catalog.products;

    final availablePackages = _selectedProduct != null
        ? catalog.getPackagesForProduct(_selectedProduct!.name)
        : <ProductPackage>[];

    final currentTotal = double.tryParse(_priceController.text.replaceAll(',', '')) ?? widget.order.totalAmount;
    final priceDiff = currentTotal - widget.order.totalAmount;

    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 500;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: mediaQuery.size.height * 0.92,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: EdgeInsets.fromLTRB(isCompact ? 14 : 20, isCompact ? 14 : 16, isCompact ? 12 : 16, isCompact ? 14 : 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFFF37021), size: 22),
                  ),
                  const SizedBox(width: 10),
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
                              'Edit Order & Packages',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 15 : 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.order.orderNumber,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update customer destination, package deals & units live',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 14 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: CUSTOMER RECIPIENT
                      _buildSectionHeader('1. Customer Information', Icons.person_outline_rounded, isDark),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customerNameController,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Customer Full Name', Icons.badge_outlined, isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      if (isCompact) ...[
                        TextFormField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: _inputDecoration('Primary Phone', Icons.phone_rounded, isDark),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Phone is required';
                            if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Valid phone required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerAltPhoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: _inputDecoration('Alt / WhatsApp (Optional)', Icons.chat_bubble_outline_rounded, isDark),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _customerPhoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                decoration: _inputDecoration('Primary Phone', Icons.phone_rounded, isDark),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                                  if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Valid phone required';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _customerAltPhoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                decoration: _inputDecoration('Alt / WhatsApp (Opt)', Icons.chat_bubble_outline_rounded, isDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // SECTION 2: DESTINATION LOCATION
                      _buildSectionHeader('2. Delivery Destination', Icons.location_on_outlined, isDark),
                      const SizedBox(height: 12),
                      if (isCompact) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedState,
                          dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: _inputDecoration('State', Icons.map_outlined, isDark),
                          items: LocationLookupService.getAllStates().map((s) {
                            return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedState = val;
                                _loadLgas();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedLga,
                          dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: _inputDecoration('LGA (Local Govt)', Icons.holiday_village_outlined, isDark),
                          items: _availableLgas.map((l) {
                            return DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedLga = val),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedState,
                                dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                decoration: _inputDecoration('State', Icons.map_outlined, isDark),
                                items: LocationLookupService.getAllStates().map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedState = val;
                                      _loadLgas();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedLga,
                                dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                decoration: _inputDecoration('LGA (Local Govt)', Icons.holiday_village_outlined, isDark),
                                items: _availableLgas.map((l) {
                                  return DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis));
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedLga = val),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Street Address / House No.', Icons.home_work_outlined, isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Delivery address is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Landmark / Dispatch Notes (e.g. Near Total Filling Station)', Icons.notes_rounded, isDark),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3: PRODUCT & COMMERCIAL PACKAGES
                      _buildSectionHeader('3. Product & Package Deals', Icons.card_giftcard_rounded, isDark),
                      const SizedBox(height: 12),

                      // Product Selector
                      if (availableProducts.isNotEmpty) ...[
                        DropdownButtonFormField<CatalogProduct>(
                          isExpanded: true,
                          initialValue: _selectedProduct,
                          dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: _inputDecoration('Target Product', Icons.inventory_2_outlined, isDark),
                          items: availableProducts.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.name} (Base: ${_currencyFormatter.format(p.defaultUnitPrice)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (p) {
                            if (p != null) {
                              setState(() {
                                _selectedProduct = p;
                                final pkgs = catalog.getPackagesForProduct(p.name);
                                if (pkgs.isNotEmpty) {
                                  _onPackageSelected(pkgs.first);
                                } else {
                                  _onPackageSelected(null);
                                  _priceController.text = p.defaultUnitPrice.toStringAsFixed(0);
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Package Deals Selection Chips / Cards
                      Text(
                        'Select Commercial Bundle Deal:',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Standard Single / Custom Option
                          ChoiceChip(
                            selected: _isCustomPackage,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Custom / Single Unit',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            selectedColor: const Color(0xFFF37021).withValues(alpha: 0.18),
                            side: BorderSide(color: _isCustomPackage ? const Color(0xFFF37021) : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                            onSelected: (_) => _onPackageSelected(null),
                          ),
                          ...availablePackages.map((pkg) {
                            final isSel = _selectedPackage?.id == pkg.id;
                            return ChoiceChip(
                              selected: isSel,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${pkg.packageName} • ${_currencyFormatter.format(pkg.packagePrice)}',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  if (pkg.freeQuantity > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                                      child: Text('+${pkg.freeQuantity} FREE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                              selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                              side: BorderSide(color: isSel ? const Color(0xFF10B981) : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                              onSelected: (_) => _onPackageSelected(pkg),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quantity and Breakdown Config
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFFF37021)),
                                const SizedBox(width: 6),
                                Text(
                                  'Quantity & Units Accounting',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Total Units
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalQuantityController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                                    decoration: _compactNumberDecoration('Total Qty', Icons.all_inbox_rounded, const Color(0xFFF37021), isDark),
                                    onChanged: _syncQuantitiesFromTotal,
                                    validator: (v) {
                                      final num = int.tryParse(v ?? '');
                                      if (num == null || num <= 0) return 'Min 1';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Paid Units
                                Expanded(
                                  child: TextFormField(
                                    controller: _paidQuantityController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    decoration: _compactNumberDecoration('Paid Qty', Icons.payments_outlined, const Color(0xFFF37021), isDark),
                                    onChanged: (_) => _syncQuantitiesFromComponents(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Free Units
                                Expanded(
                                  child: TextFormField(
                                    controller: _freeQuantityController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                    decoration: _compactNumberDecoration('Free Bonus', Icons.card_giftcard_rounded, const Color(0xFF10B981), isDark),
                                    onChanged: (_) => _syncQuantitiesFromComponents(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Total Price field
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                              decoration: _inputDecoration('Final Order Package Price (₦)', Icons.monetization_on_outlined, isDark),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final num = double.tryParse(v?.replaceAll(',', '') ?? '');
                                if (num == null || num <= 0) return 'Enter a valid amount';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Live Price Upgrade/Downgrade Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: priceDiff > 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : (priceDiff < 0
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                  : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9))),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: priceDiff > 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : (priceDiff < 0
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                    : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    priceDiff > 0
                                        ? Icons.trending_up_rounded
                                        : (priceDiff < 0 ? Icons.trending_down_rounded : Icons.check_circle_outline_rounded),
                                    size: 18,
                                    color: priceDiff > 0
                                        ? const Color(0xFF10B981)
                                        : (priceDiff < 0 ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      priceDiff > 0
                                          ? 'Package Upgrade: +${_currencyFormatter.format(priceDiff)}'
                                          : (priceDiff < 0
                                              ? 'Package Adjustment: ${_currencyFormatter.format(priceDiff)}'
                                              : 'No Price Change (Identical Total)'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: priceDiff > 0
                                            ? const Color(0xFF10B981)
                                            : (priceDiff < 0 ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currencyFormatter.format(currentTotal),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 4: PAYMENT METHOD
                      _buildSectionHeader('4. Payment Terms', Icons.payment_rounded, isDark),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: ['Pay on Delivery (Cash/POS)', 'Prepaid (Bank Transfer)', 'Partial Deposit + Balance on Delivery'].contains(_paymentType)
                            ? _paymentType
                            : 'Pay on Delivery (Cash/POS)',
                        dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: _inputDecoration('Payment Method', Icons.account_balance_wallet_outlined, isDark),
                        items: const [
                          DropdownMenuItem(
                            value: 'Pay on Delivery (Cash/POS)',
                            child: Text('Pay on Delivery (Cash/POS)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'Prepaid (Bank Transfer)',
                            child: Text('Prepaid (Bank Transfer)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'Partial Deposit + Balance on Delivery',
                            child: Text('Partial Deposit + Balance on Delivery', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (v) => setState(() => _paymentType = v ?? 'Pay on Delivery (Cash/POS)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions Strip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _saveOrder,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: Text(
                        _isSubmitting
                            ? 'Updating Order...'
                            : (isCompact ? 'Save Changes' : 'Save Changes & Deal'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF37021),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
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

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFF37021)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFF37021)),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      filled: true,
      fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  InputDecoration _compactNumberDecoration(String label, IconData icon, Color iconColor, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Icon(icon, size: 15, color: iconColor),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      filled: true,
      fillColor: isDark ? const Color(0xFF151D36) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF37021), width: 1.5),
      ),
    );
  }
}
