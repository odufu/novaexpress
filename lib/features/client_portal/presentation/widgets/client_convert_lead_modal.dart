import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../domain/entities/customer_lead.dart';
import '../providers/client_portal_provider.dart';

final convertLeadSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ClientConvertLeadModal extends ConsumerStatefulWidget {
  final CustomerLead lead;

  const ClientConvertLeadModal({super.key, required this.lead});

  @override
  ConsumerState<ClientConvertLeadModal> createState() => _ClientConvertLeadModalState();
}

class _ClientConvertLeadModalState extends ConsumerState<ClientConvertLeadModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  late String _selectedState;
  late String _selectedLga;
  CatalogProduct? _selectedProduct;
  ProductPackage? _selectedPackage;
  int _quantity = 2;
  double _price = 35000.0;
  String _paymentType = 'Pay on Delivery (Cash/POS)';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lead.customerName);
    _phoneController = TextEditingController(text: widget.lead.customerPhone);
    _addressController = TextEditingController(text: widget.lead.customerAddress);
    _notesController = TextEditingController(text: widget.lead.callNotes ?? '');

    _selectedState = widget.lead.deliveryState.isNotEmpty
        ? widget.lead.deliveryState
        : 'Federal Capital Territory';
    final lgas = NigeriaLocations.getCitiesForState(_selectedState);
    _selectedLga = lgas.contains(widget.lead.deliveryLga)
        ? widget.lead.deliveryLga
        : (lgas.isNotEmpty ? lgas.first : 'Abuja Municipal (AMAC)');

    _initProductAndPackage();
  }

  void _initProductAndPackage() {
    final catalog = ref.read(productCatalogProvider);
    if (catalog.products.isNotEmpty) {
      _selectedProduct = catalog.products.first;
      final packages = catalog.getPackagesForProduct(_selectedProduct!.name);
      if (packages.isNotEmpty) {
        // Try to match lead's packageInterest
        final leadPkgName = widget.lead.packageInterest.toLowerCase();
        _selectedPackage = packages.firstWhere(
          (p) => p.packageName.toLowerCase().contains(leadPkgName) || leadPkgName.contains(p.packageName.toLowerCase()),
          orElse: () => packages.length > 1 ? packages[1] : packages.first,
        );
        _quantity = _selectedPackage!.quantity;
        _price = _selectedPackage!.packagePrice;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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

  Future<void> _submitConversion() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(convertLeadSubmittingProvider.notifier).state = true;

    try {
      final updatedLead = widget.lead.copyWith(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerAddress: _addressController.text.trim(),
        deliveryState: _selectedState,
        deliveryLga: _selectedLga,
        packageInterest: _selectedPackage?.packageName ?? widget.lead.packageInterest,
        callNotes: _notesController.text.trim(),
      );

      final order = await ref.read(clientPortalProvider.notifier).convertLeadToOrder(
        lead: updatedLead,
        productId: _selectedProduct?.id ?? 'prod-grazer-01',
        productName: _selectedProduct?.name ?? 'Grazer Tea',
        packageName: _selectedPackage?.packageName ?? '2 Packs Promo Deal',
        quantity: _quantity,
        totalAmount: _price,
        paymentType: _paymentType,
        notes: _notesController.text.trim(),
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
                    'Order ${order.orderNumber} created & auto-routed to ${order.deliveryCity} (${order.assignedAgentName ?? "DC"})!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to convert lead: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(convertLeadSubmittingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(convertLeadSubmittingProvider);
    final catalog = ref.watch(productCatalogProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final packages = _selectedProduct != null
        ? catalog.getPackagesForProduct(_selectedProduct!.name)
        : <ProductPackage>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Convert Lead to Live Order',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              'Auto-dispatches to matching DC & LGA Rider',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Customer Name & Phone (Responsive)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final nameField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Name', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                        ),
                      ],
                    );

                    final phoneField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Phone', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone required' : null,
                        ),
                      ],
                    );

                    return isRow
                        ? Row(
                            children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 12),
                              Expanded(child: phoneField),
                            ],
                          )
                        : Column(
                            children: [
                              nameField,
                              const SizedBox(height: 12),
                              phoneField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),

                // State & LGA (Responsive)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final stateField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery State', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: NigeriaLocations.states.contains(_selectedState) ? _selectedState : NigeriaLocations.states.first,
                          isExpanded: true,
                          items: NigeriaLocations.states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedState = val;
                                final lgas = NigeriaLocations.getCitiesForState(val);
                                _selectedLga = lgas.isNotEmpty ? lgas.first : '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    );

                    final lgaField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery LGA / Area', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedLga.isNotEmpty && NigeriaLocations.getCitiesForState(_selectedState).contains(_selectedLga)
                              ? _selectedLga
                              : (NigeriaLocations.getCitiesForState(_selectedState).isNotEmpty ? NigeriaLocations.getCitiesForState(_selectedState).first : null),
                          isExpanded: true,
                          items: NigeriaLocations.getCitiesForState(_selectedState).map((lga) => DropdownMenuItem(value: lga, child: Text(lga, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLga = val);
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    );

                    return isRow
                        ? Row(
                            children: [
                              Expanded(child: stateField),
                              const SizedBox(width: 12),
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
                const SizedBox(height: 14),

                // Street Address
                Text('Delivery Street Address', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'House No. / Street / Landmark',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Delivery address required' : null,
                ),
                const SizedBox(height: 14),

                // Product Selection with ProductImageWidget
                Text('Ordered Product', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<CatalogProduct>(
                  value: _selectedProduct,
                  isExpanded: true,
                  items: catalog.products.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          ProductImageWidget(imageUrl: p.imageUrl, width: 28, height: 28, borderRadius: 6),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${p.name} (₦${p.defaultUnitPrice.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onProductChanged,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 14),

                // Package & Deal Selection
                Text('Commercial Package Deal', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                if (packages.isNotEmpty)
                  DropdownButtonFormField<ProductPackage>(
                    value: _selectedPackage,
                    isExpanded: true,
                    items: packages.map((pkg) {
                      return DropdownMenuItem(
                        value: pkg,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${pkg.packageName} (${pkg.quantity} Units)', overflow: TextOverflow.ellipsis),
                            ),
                            if (pkg.freeQuantity > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('+${pkg.freeQuantity} FREE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text('₦${pkg.packagePrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _onPackageChanged,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                const SizedBox(height: 14),

                // Payment Method & Live Total
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final paymentField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Method', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _paymentType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Pay on Delivery (Cash/POS)', child: Text('Pay on Delivery (Cash/POS)')),
                            DropdownMenuItem(value: 'Direct Bank Transfer', child: Text('Direct Bank Transfer')),
                            DropdownMenuItem(value: 'Paystack Card Checkout', child: Text('Online Card Payment')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentType = val);
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    );

                    final totalField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Amount', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            currencyFormatter.format(_price),
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                          ),
                        ),
                      ],
                    );

                    return isRow
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: paymentField),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: totalField),
                            ],
                          )
                        : Column(
                            children: [
                              paymentField,
                              const SizedBox(height: 12),
                              totalField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitConversion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm & Dispatch Live Order',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
