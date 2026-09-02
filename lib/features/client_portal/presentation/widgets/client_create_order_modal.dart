import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/location_lookup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../providers/client_portal_provider.dart';

class ClientCreateOrderModal extends ConsumerStatefulWidget {
  const ClientCreateOrderModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClientCreateOrderModal(),
    );
  }

  @override
  ConsumerState<ClientCreateOrderModal> createState() => _ClientCreateOrderModalState();
}

class _ClientCreateOrderModalState extends ConsumerState<ClientCreateOrderModal> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAltPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedState = 'Federal Capital Territory';
  String? _selectedLga = 'Abuja Municipal (AMAC)';
  List<String> _availableLgas = [];

  CatalogProduct? _selectedProduct;
  ProductPackage? _selectedPackage;
  int _quantity = 1;
  double _price = 22000.0;
  String _paymentType = 'Pay on Delivery (Cash/POS)';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadLgas();
    _initDefaultProduct();
  }

  void _loadLgas() {
    final lgas = LocationLookupService.getLgasForState(_selectedState);
    setState(() {
      _availableLgas = lgas;
      if (lgas.isNotEmpty) {
        _selectedLga = lgas.contains('Abuja Municipal (AMAC)') ? 'Abuja Municipal (AMAC)' : lgas.first;
      } else {
        _selectedLga = null;
      }
    });
  }

  void _initDefaultProduct() {
    final catalog = ref.read(productCatalogProvider);
    if (catalog.products.isNotEmpty) {
      _selectedProduct = catalog.products.first;
      final pkgs = catalog.getPackagesForProduct(_selectedProduct!.name);
      if (pkgs.isNotEmpty) {
        _selectedPackage = pkgs.first;
        _quantity = _selectedPackage!.quantity;
        _price = _selectedPackage!.packagePrice;
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAltPhoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onProductChanged(CatalogProduct? prod) {
    if (prod == null) return;
    final catalog = ref.read(productCatalogProvider);
    final pkgs = catalog.getPackagesForProduct(prod.name);
    setState(() {
      _selectedProduct = prod;
      if (pkgs.isNotEmpty) {
        _selectedPackage = pkgs.first;
        _quantity = _selectedPackage!.quantity;
        _price = _selectedPackage!.packagePrice;
      } else {
        _selectedPackage = null;
        _quantity = 1;
        _price = prod.defaultUnitPrice;
      }
    });
  }

  void _onPackageChanged(ProductPackage? pkg) {
    if (pkg == null) return;
    setState(() {
      _selectedPackage = pkg;
      _quantity = pkg.quantity;
      _price = pkg.packagePrice;
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLga == null || _selectedLga!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid Local Government Area (LGA)')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final order = await ref.read(clientPortalProvider.notifier).createOrder(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAltPhone: _customerAltPhoneController.text.trim().isNotEmpty
            ? _customerAltPhoneController.text.trim()
            : null,
        deliveryState: _selectedState,
        deliveryLga: _selectedLga!,
        deliveryAddress: _addressController.text.trim(),
        productId: _selectedProduct?.id ?? 'prod-grazer-01',
        productName: _selectedProduct?.name ?? 'Grazer Tea',
        quantity: _quantity,
        totalAmount: _price,
        packageId: _selectedPackage?.id,
        packageName: _selectedPackage?.packageName,
        paymentType: _paymentType,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D9488),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order ${order.orderNumber} created and dispatched successfully to ${order.deliveryLga}!',
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
            content: Text('Error creating order: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final packages = _selectedProduct != null
        ? catalog.getPackagesForProduct(_selectedProduct!.name)
        : <ProductPackage>[];

    // Real-time dispatch preview
    final routingPreview = OrderRoutingService.routeOrder(
      order: OrderEntity(
        id: 'preview',
        orderNumber: 'PREVIEW',
        customerName: _customerNameController.text.trim().isNotEmpty ? _customerNameController.text.trim() : 'Customer',
        customerPhone: _customerPhoneController.text.trim().isNotEmpty ? _customerPhoneController.text.trim() : '08000000000',
        deliveryState: _selectedState,
        deliveryCity: _selectedLga ?? 'AMAC',
        deliveryAddress: _addressController.text,
        lga: _selectedLga,
        status: 'pending_dispatch',
        quantity: _quantity,
        basePrice: _price,
        upsellAmount: 0.0,
        totalAmount: _price,
        paymentType: _paymentType,
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      ),
      distributionCenters: dcState.distributionCenters,
      drivers: dcState.drivers,
      stockAllocations: const [],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF2DD4BF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Customer Order',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Select product commercial bundle & auto-dispatch by State/LGA',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Section 1: Product & Package Selection
                    _buildSectionHeader('1. Product & Commercial Package Deal', Icons.inventory_2_outlined),
                    const SizedBox(height: 12),

                    // Product Selector
                    DropdownButtonFormField<CatalogProduct>(
                      value: _selectedProduct,
                      decoration: _inputDecoration('Product Name', prefixIcon: Icons.shopping_bag_outlined),
                      items: catalog.products.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} (₦${p.defaultUnitPrice.toStringAsFixed(0)} / unit)'),
                        );
                      }).toList(),
                      onChanged: _onProductChanged,
                      validator: (v) => v == null ? 'Please select a product' : null,
                    ),

                    const SizedBox(height: 14),

                    // Commercial Packages / Bundles (e.g. 2 Packs Promo Deal, 3 Packs Family)
                    if (packages.isNotEmpty) ...[
                      Text(
                        'Select Commercial Bundle / Package Deal (Pre-Configured Pricing & Unit Deductions)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: packages.length,
                          separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          itemBuilder: (context, index) {
                            final pkg = packages[index];
                            final isSelected = _selectedPackage?.id == pkg.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                              leading: Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            pkg.packageName,
                                            style: GoogleFonts.inter(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (pkg.freeQuantity > 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+${pkg.freeQuantity} FREE',
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₦${pkg.packagePrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${pkg.quantity} Physical Units • Deducts ${pkg.quantity} units from warehouse stock',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _onPackageChanged(pkg),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Quantity and Order Price Override
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isRow = constraints.maxWidth >= 450;
                        final qtyField = TextFormField(
                          initialValue: _quantity.toString(),
                          decoration: _inputDecoration('Quantity (Physical Units)', prefixIcon: Icons.format_list_numbered),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              setState(() => _quantity = parsed);
                            }
                          },
                          validator: (v) {
                            if (v == null || int.tryParse(v) == null || int.parse(v) <= 0) {
                              return 'Enter valid quantity';
                            }
                            return null;
                          },
                        );

                        final priceField = TextFormField(
                          key: ValueKey(_price),
                          initialValue: _price.toStringAsFixed(0),
                          decoration: _inputDecoration('Total Order Amount (₦)', prefixIcon: Icons.payments_outlined),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed >= 0) {
                              _price = parsed;
                            }
                          },
                          validator: (v) {
                            if (v == null || double.tryParse(v) == null || double.parse(v) < 0) {
                              return 'Enter valid amount';
                            }
                            return null;
                          },
                        );

                        return isRow
                            ? Row(
                                children: [
                                  Expanded(child: qtyField),
                                  const SizedBox(width: 14),
                                  Expanded(child: priceField),
                                ],
                              )
                            : Column(
                                children: [
                                  qtyField,
                                  const SizedBox(height: 12),
                                  priceField,
                                ],
                              );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Customer Details
                    _buildSectionHeader('2. Customer Recipient Information', Icons.person_outline),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: _inputDecoration('Customer Full Name', prefixIcon: Icons.person),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isRow = constraints.maxWidth >= 450;
                        final phoneField = TextFormField(
                          controller: _customerPhoneController,
                          decoration: _inputDecoration('Primary Phone Number', prefixIcon: Icons.phone),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                        );
                        final altPhoneField = TextFormField(
                          controller: _customerAltPhoneController,
                          decoration: _inputDecoration('Alternative Phone (Optional)', prefixIcon: Icons.phone_android_outlined),
                        );

                        return isRow
                            ? Row(
                                children: [
                                  Expanded(child: phoneField),
                                  const SizedBox(width: 14),
                                  Expanded(child: altPhoneField),
                                ],
                              )
                            : Column(
                                children: [
                                  phoneField,
                                  const SizedBox(height: 12),
                                  altPhoneField,
                                ],
                              );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Delivery Location (State & LGA Routing)
                    _buildSectionHeader('3. Destination & Multi-Zone Dispatch', Icons.place_outlined),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isRow = constraints.maxWidth >= 450;
                        final stateField = DropdownButtonFormField<String>(
                          value: _selectedState,
                          isExpanded: true,
                          decoration: _inputDecoration('Delivery State'),
                          items: LocationLookupService.getAllStates().map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedState = val;
                                _loadLgas();
                              });
                            }
                          },
                        );

                        final lgaField = DropdownButtonFormField<String>(
                          value: _selectedLga,
                          isExpanded: true,
                          decoration: _inputDecoration('Local Govt Area (LGA)'),
                          items: _availableLgas.map((lga) {
                            return DropdownMenuItem(
                              value: lga,
                              child: Text(lga, overflow: TextOverflow.ellipsis, maxLines: 1),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedLga = val);
                          },
                          validator: (v) => v == null || v.isEmpty ? 'Select an LGA' : null,
                        );

                        return isRow
                            ? Row(
                                children: [
                                  Expanded(child: stateField),
                                  const SizedBox(width: 14),
                                  Expanded(child: lgaField),
                                ],
                              )
                            : Column(
                                children: [
                                  stateField,
                                  const SizedBox(height: 12),
                                  lgaField,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: _inputDecoration('Street Address / Landmark / House No.', prefixIcon: Icons.home_work_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Delivery address is required' : null,
                    ),

                    const SizedBox(height: 14),

                    // Real-Time Auto Dispatch Live Preview Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: routingPreview.isAssignedToRider
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: routingPreview.isAssignedToRider
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            routingPreview.isAssignedToRider
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            color: routingPreview.isAssignedToRider
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routingPreview.isAssignedToRider
                                      ? 'Automated Dispatch Target: ${routingPreview.distributionCenter?.name}'
                                      : (routingPreview.distributionCenter != null
                                          ? 'Routed to Hub: ${routingPreview.distributionCenter?.name} (Pending Rider Assignment)'
                                          : 'Escalates to Grand DC HQ (Manual Routing)'),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: routingPreview.isAssignedToRider
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  routingPreview.driver != null
                                      ? 'Assigned Rider: ${routingPreview.driver?.name} (${routingPreview.driver?.phone})'
                                      : routingPreview.dispatchDiagnosis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: routingPreview.isAssignedToRider
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 4: Payment Method
                    _buildSectionHeader('4. Payment Method', Icons.payment_outlined),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentType,
                      decoration: _inputDecoration('Payment Type'),
                      items: const [
                        DropdownMenuItem(value: 'Pay on Delivery (Cash/POS)', child: Text('Pay on Delivery (Cash or POS)')),
                        DropdownMenuItem(value: 'Direct Bank Transfer', child: Text('Direct Bank Transfer (Paid Pre-Delivery)')),
                        DropdownMenuItem(value: 'Paystack Card Checkout', child: Text('Paystack Card / Online Gateway')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentType = val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSubmitting ? null : _submitOrder,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Dispatching...' : 'Dispatch Order Now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0D9488), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 20) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
      ),
    );
  }
}
