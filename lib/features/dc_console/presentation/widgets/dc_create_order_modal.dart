import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/product_package.dart';
import '../providers/dc_console_provider.dart';
import '../providers/product_catalog_provider.dart';

class DCCreateOrderModal extends ConsumerStatefulWidget {
  const DCCreateOrderModal({super.key});

  @override
  ConsumerState<DCCreateOrderModal> createState() => _DCCreateOrderModalState();
}

class _DCCreateOrderModalState extends ConsumerState<DCCreateOrderModal> {
  final _formKey = GlobalKey<FormState>();

  // Customer controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  // Commercial & Order Values (Decoupled: Product, Seller Packages, Quantity, Price)
  String _selectedState = 'FCT - Abuja';
  String _selectedCity = 'Wuse 2';
  String _selectedProductName = 'Grazer Tea';
  ProductPackage? _selectedPackage;
  final _productNameController = TextEditingController(text: 'Grazer Tea');
  final _priceController = TextEditingController(text: '22000');
  final _quantityController = TextEditingController(text: '1');
  double _unitPrice = 22000.0;
  int _quantity = 1;
  final double _upsellAmount = 0.0;
  String _paymentType = 'pay_on_delivery'; // 'pay_on_delivery', 'prepaid'
  String _clientName = 'Novacare Limited';

  // Assignment
  String? _selectedRiderId;
  String? _selectedRiderName;
  String? _selectedRiderCode;
  bool _assignImmediately = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_onPriceChanged);
    _quantityController.addListener(_onQuantityChanged);
  }

  void _onPriceChanged() {
    final clean = _priceController.text.replaceAll(',', '').replaceAll('₦', '').trim();
    final parsed = double.tryParse(clean) ?? 0.0;
    if (parsed != _unitPrice) {
      setState(() => _unitPrice = parsed);
    }
  }

  void _onQuantityChanged() {
    final clean = _quantityController.text.trim();
    final q = int.tryParse(clean) ?? 1;
    if (q != _quantity && q > 0) {
      setState(() => _quantity = q);
    }
  }

  void _selectProduct(CatalogProduct product) {
    final packages = product.packages;
    final defaultPkg = packages.isNotEmpty ? packages.first : null;
    setState(() {
      _selectedProductName = product.name;
      _productNameController.text = product.name;
      _clientName = product.clientName;
      _selectedPackage = defaultPkg;
      if (defaultPkg != null) {
        _quantity = defaultPkg.quantity;
        _quantityController.text = '${defaultPkg.quantity}';
        _unitPrice = defaultPkg.packagePrice;
        _priceController.text = defaultPkg.packagePrice.toStringAsFixed(0);
      } else {
        _quantity = 1;
        _quantityController.text = '1';
        _unitPrice = product.defaultUnitPrice;
        _priceController.text = product.defaultUnitPrice.toStringAsFixed(0);
      }
    });
  }

  void _selectPackage(ProductPackage pkg) {
    setState(() {
      _selectedPackage = pkg;
      _quantity = pkg.quantity;
      _quantityController.text = '${pkg.quantity}';
      _unitPrice = pkg.packagePrice;
      _priceController.text = pkg.packagePrice.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    _productNameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  double get _totalAmount => (_quantity * _unitPrice) + _upsellAmount;

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final randomCode = 1000 + Random().nextInt(8999);
    final orderNumber = 'TRK-$randomCode';
    final dcState = ref.read(dcConsoleProvider);

    final fullProductName = _selectedPackage != null
        ? '$_selectedProductName (${_selectedPackage!.packageName})'
        : (_productNameController.text.trim().isNotEmpty
            ? _productNameController.text.trim()
            : _selectedProductName);

    final orderPayload = <String, dynamic>{
      'id': 'ord-${DateTime.now().millisecondsSinceEpoch}',
      'order_number': orderNumber,
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_alt_phone': _altPhoneController.text.trim().isNotEmpty ? _altPhoneController.text.trim() : null,
      'delivery_state': _selectedState,
      'delivery_city': _selectedCity,
      'delivery_address': _addressController.text.trim(),
      'landmark': _landmarkController.text.trim().isNotEmpty ? _landmarkController.text.trim() : null,
      'product_name': fullProductName,
      'quantity': _quantity,
      'paid_quantity': _quantity,
      'free_quantity': 0,
      'base_price': _unitPrice,
      'upsell_amount': _upsellAmount,
      'total_amount': _totalAmount,
      'payment_type': _paymentType,
      'payment_status': _paymentType == 'prepaid' ? 'paid' : 'pending',
      'fulfillment_type': 'distributed_inventory',
      'client_name': _clientName,
      'client_delivery_fee': 5000.0,
      'agent_entitlement': 2500.0,
      'delivery_notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      'status': _assignImmediately && _selectedRiderId != null ? 'assigned' : 'pending',
      'distribution_center_id': dcState.activeHubId,
      'delivery_agent_id': _assignImmediately ? _selectedRiderId : null,
      'delivery_agent_name': _assignImmediately ? _selectedRiderName : null,
      'delivery_agent_code': _assignImmediately ? _selectedRiderCode : null,
      'created_at': DateTime.now().toIso8601String(),
    };

    final success = await ref.read(ordersProvider.notifier).createOrder(orderPayload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order $orderNumber created successfully and logged in database!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
            content: Text('⚠️ Failed to save order. Please check inputs and retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final ordersState = ref.watch(ordersProvider);
    final catalogState = ref.watch(productCatalogProvider);
    final availablePackages = catalogState.getPackagesForProduct(_selectedProductName);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 14 : 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFF37021), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intake / Create New Merchant Order',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 15 : 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dcState.activeHubName} (${dcState.activeHubCode})',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: CUSTOMER INFORMATION
                      _buildSectionTitle(
                        icon: Icons.person_outline_rounded,
                        title: 'Customer & Delivery Contact',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.inter(fontSize: 13.5),
                        decoration: _buildInputDecoration(
                          label: 'Customer Full Name *',
                          hint: 'e.g. Senator Kashim Shettima',
                          icon: Icons.person_rounded,
                          isDark: isDark,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Responsive Phone Numbers
                      if (isMobile) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 13.5),
                          decoration: _buildInputDecoration(
                            label: 'Primary Phone Number *',
                            hint: '08012345678',
                            icon: Icons.phone_rounded,
                            isDark: isDark,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Phone number required';
                            if (v.trim().length < 10) return 'Enter valid phone number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _altPhoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 13.5),
                          decoration: _buildInputDecoration(
                            label: 'Alt Phone (Optional)',
                            hint: '08098765432',
                            icon: Icons.phone_android_rounded,
                            isDark: isDark,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.inter(fontSize: 13.5),
                                decoration: _buildInputDecoration(
                                  label: 'Primary Phone Number *',
                                  hint: '08012345678',
                                  icon: Icons.phone_rounded,
                                  isDark: isDark,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Phone number required';
                                  if (v.trim().length < 10) return 'Enter valid phone number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _altPhoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.inter(fontSize: 13.5),
                                decoration: _buildInputDecoration(
                                  label: 'Alt Phone (Optional)',
                                  hint: '08098765432',
                                  icon: Icons.phone_android_rounded,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Responsive State & Zone Pickers (All 36 Nigerian States + FCT)
                      if (isMobile) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedState,
                          isExpanded: true,
                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: _buildInputDecoration(
                            label: 'Delivery State (36 States + FCT)',
                            hint: 'Select State',
                            icon: Icons.map_rounded,
                            isDark: isDark,
                          ),
                          items: NigeriaLocations.states.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              final newCities = NigeriaLocations.getCitiesForState(v);
                              setState(() {
                                _selectedState = v;
                                _selectedCity = newCities.isNotEmpty ? newCities.first : 'Central';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: NigeriaLocations.getCitiesForState(_selectedState).contains(_selectedCity)
                              ? _selectedCity
                              : (NigeriaLocations.getCitiesForState(_selectedState).isNotEmpty
                                  ? NigeriaLocations.getCitiesForState(_selectedState).first
                                  : null),
                          isExpanded: true,
                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: _buildInputDecoration(
                            label: 'Delivery Zone / LGA / City',
                            hint: 'Select Zone',
                            icon: Icons.location_city_rounded,
                            isDark: isDark,
                          ),
                          items: NigeriaLocations.getCitiesForState(_selectedState).map((z) {
                            return DropdownMenuItem(
                              value: z,
                              child: Text(z, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedCity = v ?? _selectedCity),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedState,
                                isExpanded: true,
                                style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: _buildInputDecoration(
                                  label: 'Delivery State (36 States + FCT)',
                                  hint: 'Select State',
                                  icon: Icons.map_rounded,
                                  isDark: isDark,
                                ),
                                items: NigeriaLocations.states.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    final newCities = NigeriaLocations.getCitiesForState(v);
                                    setState(() {
                                      _selectedState = v;
                                      _selectedCity = newCities.isNotEmpty ? newCities.first : 'Central';
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: NigeriaLocations.getCitiesForState(_selectedState).contains(_selectedCity)
                                    ? _selectedCity
                                    : (NigeriaLocations.getCitiesForState(_selectedState).isNotEmpty
                                        ? NigeriaLocations.getCitiesForState(_selectedState).first
                                        : null),
                                isExpanded: true,
                                style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: _buildInputDecoration(
                                  label: 'Delivery Zone / LGA / City',
                                  hint: 'Select Zone',
                                  icon: Icons.location_city_rounded,
                                  isDark: isDark,
                                ),
                                items: NigeriaLocations.getCitiesForState(_selectedState).map((z) {
                                  return DropdownMenuItem(
                                    value: z,
                                    child: Text(z, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedCity = v ?? _selectedCity),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13.5),
                        decoration: _buildInputDecoration(
                          label: 'Detailed Street Address *',
                          hint: 'Plot 104 Shehu Shagari Way, Maitama, Abuja',
                          icon: Icons.home_work_rounded,
                          isDark: isDark,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _landmarkController,
                        style: GoogleFonts.inter(fontSize: 13.5),
                        decoration: _buildInputDecoration(
                          label: 'Landmark / Nearest Junction (Optional)',
                          hint: 'Opposite Transcorp Hilton, Near Total Station',
                          icon: Icons.explore_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2: PRODUCT & SELLER COMMERCIAL PACKAGES
                      _buildSectionTitle(
                        icon: Icons.inventory_2_outlined,
                        title: 'Product & Seller Commercial Packages',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      // Searchable Base Product Field
                      TextFormField(
                        controller: _productNameController,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          label: 'Base Product *',
                          hint: 'Select product or browse catalog...',
                          icon: Icons.shopping_bag_outlined,
                          isDark: isDark,
                        ).copyWith(
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.search_rounded, color: Color(0xFFF37021), size: 20),
                                tooltip: 'Search Catalog & Packages',
                                onPressed: () => _showProductSearchModal(isDark),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B), size: 24),
                                tooltip: 'Browse Products',
                                onPressed: () => _showProductSearchModal(isDark),
                              ),
                            ],
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product is required' : null,
                      ),
                      const SizedBox(height: 8),

                      // Quick Product Switcher Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...catalogState.products.map((p) {
                              final isSelected = p.name == _selectedProductName;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    p.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    ),
                                  ),
                                  backgroundColor: isSelected
                                      ? const Color(0xFFF37021)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: () => _selectProduct(p),
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                avatar: const Icon(Icons.search, size: 14, color: Color(0xFFF37021)),
                                label: Text(
                                  'More...',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                ),
                                backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.1),
                                side: const BorderSide(color: Color(0xFFF37021)),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onPressed: () => _showProductSearchModal(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Seller Packages Container for Selected Product
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_offer_outlined, size: 15, color: Color(0xFFF37021)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Seller Packages for $_selectedProductName',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showCreatePackageDialog(isDark),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFFF37021)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+ Add Package',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFF37021),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (availablePackages.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...availablePackages.map((pkg) {
                                    final isSelected = _selectedPackage?.id == pkg.id;
                                    return ChoiceChip(
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) _selectPackage(pkg);
                                      },
                                      label: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pkg.packageName,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${CurrencyFormatter.formatNaira(pkg.packagePrice)} (${pkg.quantity} unit${pkg.quantity > 1 ? 's' : ''})',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      selectedColor: const Color(0xFF2563EB),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    );
                                  }),
                                  ActionChip(
                                    avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFF37021)),
                                    label: Text(
                                      'Custom Deal...',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                    ),
                                    backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.08),
                                    side: const BorderSide(color: Color(0xFFF37021)),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    onPressed: () => _showCreatePackageDialog(isDark),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'No predefined packages. Click "+ Add Package" to register a reusable bundle deal.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Decoupled Quantity, Unit Price & Payment Terms
                      if (isMobile) ...[
                        Row(
                          children: [
                            // Quantity with Stepper
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, top: 4),
                                      child: Text(
                                        'Quantity (Units)',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: _quantity > 1
                                              ? () {
                                                  final next = _quantity - 1;
                                                  _quantityController.text = '$next';
                                                }
                                              : null,
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _quantityController,
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            final next = _quantity + 1;
                                            _quantityController.text = '$next';
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Editable Package Price (₦)
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: _buildInputDecoration(
                                  label: 'Package Price (₦) *',
                                  hint: 'e.g. 22000',
                                  icon: Icons.payments_outlined,
                                  isDark: isDark,
                                ).copyWith(
                                  prefixText: '₦ ',
                                  prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2563EB)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Price required';
                                  final num = double.tryParse(v.replaceAll(',', '').replaceAll('₦', '').trim());
                                  if (num == null || num < 0) return 'Invalid price';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Payment Type Full Width
                        DropdownButtonFormField<String>(
                          value: _paymentType,
                          isExpanded: true,
                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: _buildInputDecoration(
                            label: 'Payment Terms',
                            hint: 'Select Type',
                            icon: Icons.account_balance_wallet_outlined,
                            isDark: isDark,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pay_on_delivery', child: Text('POD (Cash on Delivery)')),
                            DropdownMenuItem(value: 'prepaid', child: Text('Prepaid (Direct Transfer)')),
                          ],
                          onChanged: (v) => setState(() => _paymentType = v ?? _paymentType),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            // Quantity with Stepper
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, top: 4),
                                      child: Text(
                                        'Quantity (Units)',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: _quantity > 1
                                              ? () {
                                                  final next = _quantity - 1;
                                                  _quantityController.text = '$next';
                                                }
                                              : null,
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _quantityController,
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            final next = _quantity + 1;
                                            _quantityController.text = '$next';
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Editable Package Price (₦)
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: _buildInputDecoration(
                                  label: 'Package Price (₦) *',
                                  hint: 'e.g. 22000',
                                  icon: Icons.payments_outlined,
                                  isDark: isDark,
                                ).copyWith(
                                  prefixText: '₦ ',
                                  prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2563EB)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Price required';
                                  final num = double.tryParse(v.replaceAll(',', '').replaceAll('₦', '').trim());
                                  if (num == null || num < 0) return 'Invalid price';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Payment Type
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: _paymentType,
                                isExpanded: true,
                                style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: _buildInputDecoration(
                                  label: 'Payment Terms',
                                  hint: 'Select Type',
                                  icon: Icons.account_balance_wallet_outlined,
                                  isDark: isDark,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'pay_on_delivery', child: Text('POD (Cash on Delivery)')),
                                  DropdownMenuItem(value: 'prepaid', child: Text('Prepaid (Direct Transfer)')),
                                ],
                                onChanged: (v) => setState(() => _paymentType = v ?? _paymentType),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Live Total Amount Card with Calculation Breakdown
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Total Payable Amount',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      if (_selectedPackage != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _selectedPackage!.packageName,
                                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatNaira(_totalAmount),
                                    style: GoogleFonts.inter(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _paymentType == 'pay_on_delivery' ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _paymentType == 'pay_on_delivery' ? 'POD Cash' : 'Prepaid Cleared',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _paymentType == 'pay_on_delivery' ? const Color(0xFFD97706) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3: ALLOCATION & DISPATCH
                      _buildSectionTitle(
                        icon: Icons.local_shipping_outlined,
                        title: 'Dispatch & Fleet Assignment',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        value: _assignImmediately,
                        onChanged: (val) => setState(() => _assignImmediately = val),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Assign immediately to a Rider', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          _assignImmediately
                              ? 'Order routes directly to selected rider terminal'
                              : 'Order enters DC Unassigned Pool for queue dispatching',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                        activeColor: const Color(0xFF2563EB),
                      ),

                      if (_assignImmediately) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedRiderId,
                          isExpanded: true,
                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: _buildInputDecoration(
                            label: 'Select Dispatch Rider *',
                            hint: 'Choose Rider',
                            icon: Icons.sports_motorsports_rounded,
                            isDark: isDark,
                          ),
                          items: dcState.drivers.map((d) {
                            final activeCount = ordersState.orders.where((o) {
                              final isMatching = o.deliveryAgentId == d.id || o.deliveryAgentCode == d.driverCode;
                              return isMatching && o.status != 'delivered' && o.status != 'failed' && o.status != 'cancelled';
                            }).length;

                            final loadText = activeCount == 0 ? 'Available' : '$activeCount Active';

                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                '${d.name} (${d.driverCode}) • $loadText',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final driver = dcState.drivers.firstWhere((d) => d.id == val);
                              setState(() {
                                _selectedRiderId = driver.id;
                                _selectedRiderName = driver.name;
                                _selectedRiderCode = driver.driverCode;
                              });
                            }
                          },
                          validator: (v) {
                            if (_assignImmediately && (v == null || v.isEmpty)) {
                              return 'Please select a rider or toggle off immediate assignment';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: isMobile ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: isMobile
                  ? Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitOrder,
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _isSubmitting ? 'Creating...' : 'Create Order',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitOrder,
                          icon: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _isSubmitting ? 'Creating...' : 'Create Order & Log Waybill',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildSectionTitle({required IconData icon, required String title, required bool isDark}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFF37021)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  void _showCreatePackageDialog(bool isDark) {
    final titleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFF37021), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'New Package for $_selectedProductName',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a seller commercial package deal that will be saved and reusable across future orders.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titleCtrl,
                  decoration: _buildInputDecoration(
                    label: 'Package Name / Title *',
                    hint: 'e.g. 4 Packs Promo Deal, 5 Bottles Wholesale',
                    icon: Icons.inventory_2_outlined,
                    isDark: isDark,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter package name' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          label: 'Units (Qty) *',
                          hint: 'e.g. 4',
                          icon: Icons.format_list_numbered_rounded,
                          isDark: isDark,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _buildInputDecoration(
                          label: 'Package Deal Price (₦) *',
                          hint: 'e.g. 45000',
                          icon: Icons.payments_outlined,
                          isDark: isDark,
                        ).copyWith(
                          prefixText: '₦ ',
                          prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.replaceAll(',', '').replaceAll('₦', '').trim() ?? '');
                          if (n == null || n <= 0) return 'Enter price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save & Select Package'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF37021),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = titleCtrl.text.trim();
              final qty = int.parse(qtyCtrl.text.trim());
              final price = double.parse(priceCtrl.text.replaceAll(',', '').replaceAll('₦', '').trim());

              final newPkg = ref.read(productCatalogProvider.notifier).addPackageToProduct(
                    productName: _selectedProductName,
                    packageName: name,
                    quantity: qty,
                    packagePrice: price,
                    clientName: _clientName,
                  );

              _selectPackage(newPkg);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('✅ Package "$name" saved and reusable across future orders!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProductSearchModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final catalog = ref.read(productCatalogProvider);
            final filtered = catalog.products.where((p) {
              final name = p.name.toLowerCase();
              final sku = p.sku.toLowerCase();
              final client = p.clientName.toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || sku.contains(q) || client.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFFF37021)),
                        const SizedBox(width: 8),
                        Text(
                          'Search Base Products',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type product name, SKU, or client...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      onChanged: (v) => setModalState(() => searchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final p = filtered[idx];
                        final isSelected = p.name == _selectedProductName;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? const Color(0xFFF37021)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${p.clientName} • ${p.packages.length} package${p.packages.length != 1 ? "s" : ""}',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'From ${CurrencyFormatter.formatNaira(p.defaultUnitPrice)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          onTap: () {
                            _selectProduct(p);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
