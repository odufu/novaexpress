import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/product_package.dart';
import '../providers/dc_console_provider.dart';
import '../providers/product_catalog_provider.dart';
import 'dc_csv_order_import_modal.dart';

class DCCreateOrderDraftState {
  final String selectedState;
  final String selectedCity;
  final String? selectedProductId;
  final String selectedProductName;
  final ProductPackage? selectedPackage;
  final double unitPrice;
  final int quantity;
  final double upsellAmount;
  final String paymentType;
  final String? clientId;
  final String clientName;
  final String clientCompany;
  final String? clientPhone;
  final String? clientEmail;
  final String? selectedRiderId;
  final String? selectedRiderName;
  final String? selectedRiderCode;
  final bool assignImmediately;
  final bool isSubmitting;

  const DCCreateOrderDraftState({
    this.selectedState = 'FCT - Abuja',
    this.selectedCity = 'Wuse 2',
    this.selectedProductId,
    this.selectedProductName = 'Grazer Tea',
    this.selectedPackage,
    this.unitPrice = 22000.0,
    this.quantity = 1,
    this.upsellAmount = 0.0,
    this.paymentType = 'pay_on_delivery',
    this.clientId = 'cli-novacale-001',
    this.clientName = 'Dr. Chuka Okafor',
    this.clientCompany = 'Novacale Limited',
    this.clientPhone = '08034455667',
    this.clientEmail = 'orders@novacale.com',
    this.selectedRiderId,
    this.selectedRiderName,
    this.selectedRiderCode,
    this.assignImmediately = false,
    this.isSubmitting = false,
  });

  double get totalAmount {
    if (selectedPackage != null) {
      return selectedPackage!.packagePrice + upsellAmount;
    }
    return (quantity * unitPrice) + upsellAmount;
  }

  DCCreateOrderDraftState copyWith({
    String? selectedState,
    String? selectedCity,
    String? Function()? selectedProductId,
    String? selectedProductName,
    ProductPackage? Function()? selectedPackage,
    double? unitPrice,
    int? quantity,
    double? upsellAmount,
    String? paymentType,
    String? clientId,
    String? clientName,
    String? clientCompany,
    String? clientPhone,
    String? clientEmail,
    String? Function()? selectedRiderId,
    String? Function()? selectedRiderName,
    String? Function()? selectedRiderCode,
    bool? assignImmediately,
    bool? isSubmitting,
  }) {
    return DCCreateOrderDraftState(
      selectedState: selectedState ?? this.selectedState,
      selectedCity: selectedCity ?? this.selectedCity,
      selectedProductId: selectedProductId != null ? selectedProductId() : this.selectedProductId,
      selectedProductName: selectedProductName ?? this.selectedProductName,
      selectedPackage: selectedPackage != null ? selectedPackage() : this.selectedPackage,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      upsellAmount: upsellAmount ?? this.upsellAmount,
      paymentType: paymentType ?? this.paymentType,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientCompany: clientCompany ?? this.clientCompany,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      selectedRiderId: selectedRiderId != null ? selectedRiderId() : this.selectedRiderId,
      selectedRiderName: selectedRiderName != null ? selectedRiderName() : this.selectedRiderName,
      selectedRiderCode: selectedRiderCode != null ? selectedRiderCode() : this.selectedRiderCode,
      assignImmediately: assignImmediately ?? this.assignImmediately,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class DCCreateOrderDraftNotifier extends StateNotifier<DCCreateOrderDraftState> {
  DCCreateOrderDraftNotifier() : super(const DCCreateOrderDraftState());

  void setLocation(String stateVal, String cityVal) => state = state.copyWith(selectedState: stateVal, selectedCity: cityVal);
  void setCity(String cityVal) => state = state.copyWith(selectedCity: cityVal);
  void setUnitPrice(double price) => state = state.copyWith(unitPrice: price);
  void setQuantity(int q) => state = state.copyWith(quantity: q);
  void setPaymentType(String type) => state = state.copyWith(paymentType: type);
  void setClientCompany(String company) => state = state.copyWith(clientCompany: company, clientName: company);
  void setAssignImmediately(bool val) => state = state.copyWith(assignImmediately: val);
  void setRider(String? id, String? name, String? code) => state = state.copyWith(
    selectedRiderId: () => id,
    selectedRiderName: () => name,
    selectedRiderCode: () => code,
  );
  void setSubmitting(bool val) => state = state.copyWith(isSubmitting: val);
  void selectProduct(CatalogProduct product) {
    final packages = product.packages;
    final defaultPkg = packages.isNotEmpty ? packages.first : null;
    state = state.copyWith(
      selectedProductId: () => product.id,
      selectedProductName: product.name,
      clientName: product.clientName,
      selectedPackage: () => defaultPkg,
      quantity: defaultPkg != null ? defaultPkg.quantity : 1,
      unitPrice: defaultPkg != null ? defaultPkg.packagePrice : product.defaultUnitPrice,
    );
  }
  void selectPackage(ProductPackage pkg) {
    state = state.copyWith(
      selectedPackage: () => pkg,
      selectedProductId: () => pkg.productId,
      quantity: pkg.quantity,
      unitPrice: pkg.packagePrice,
    );
  }
}

final dcCreateOrderDraftProvider = StateNotifierProvider.autoDispose<DCCreateOrderDraftNotifier, DCCreateOrderDraftState>((ref) {
  return DCCreateOrderDraftNotifier();
});

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

  final _productNameController = TextEditingController(text: 'Grazer Tea');
  final _priceController = TextEditingController(text: '22000');
  final _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_onPriceChanged);
    _quantityController.addListener(_onQuantityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productCatalogProvider.notifier).reloadCatalog();
      final stockItems = ref.read(stockProvider).stockItems;
      if (stockItems.isNotEmpty) {
        ref.read(productCatalogProvider.notifier).syncFromStockItems(stockItems);
      }
    });
  }

  void _onPriceChanged() {
    final clean = _priceController.text.replaceAll(',', '').replaceAll('₦', '').trim();
    final parsed = double.tryParse(clean) ?? 0.0;
    final current = ref.read(dcCreateOrderDraftProvider).unitPrice;
    if (parsed != current) {
      ref.read(dcCreateOrderDraftProvider.notifier).setUnitPrice(parsed);
    }
  }

  void _onQuantityChanged() {
    final clean = _quantityController.text.trim();
    final q = int.tryParse(clean) ?? 1;
    final current = ref.read(dcCreateOrderDraftProvider).quantity;
    if (q != current && q > 0) {
      ref.read(dcCreateOrderDraftProvider.notifier).setQuantity(q);
    }
  }

  void _selectProduct(CatalogProduct product) {
    final packages = product.packages;
    final defaultPkg = packages.isNotEmpty ? packages.first : null;
    _productNameController.text = product.name;
    if (defaultPkg != null) {
      _quantityController.text = '${defaultPkg.quantity}';
      _priceController.text = defaultPkg.packagePrice.toStringAsFixed(0);
    } else {
      _quantityController.text = '1';
      _priceController.text = product.defaultUnitPrice.toStringAsFixed(0);
    }
    ref.read(dcCreateOrderDraftProvider.notifier).selectProduct(product);
  }

  void _selectPackage(ProductPackage pkg) {
    _quantityController.text = '${pkg.quantity}';
    _priceController.text = pkg.packagePrice.toStringAsFixed(0);
    ref.read(dcCreateOrderDraftProvider.notifier).selectPackage(pkg);
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

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final draft = ref.read(dcCreateOrderDraftProvider);
    final notifier = ref.read(dcCreateOrderDraftProvider.notifier);
    notifier.setSubmitting(true);

    final randomCode = 1000 + Random().nextInt(8999);
    final orderNumber = 'TRK-$randomCode';
    final dcState = ref.read(dcConsoleProvider);

    final pkg = draft.selectedPackage;
    final totalUnits = pkg?.totalPhysicalQuantity ?? draft.quantity;
    final paidUnits = pkg?.paidQuantity ?? draft.quantity;
    final freeUnits = pkg?.freeQuantity ?? 0;
    final basePrice = pkg != null ? pkg.packagePrice : (draft.quantity * draft.unitPrice);

    final fullProductName = pkg != null
        ? '${draft.selectedProductName} (${pkg.packageName})'
        : (_productNameController.text.trim().isNotEmpty
            ? _productNameController.text.trim()
            : draft.selectedProductName);

    final orderPayload = <String, dynamic>{
      'id': 'ord-${DateTime.now().millisecondsSinceEpoch}',
      'order_number': orderNumber,
      'product_id': draft.selectedProductId ?? pkg?.productId,
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_alt_phone': _altPhoneController.text.trim().isNotEmpty ? _altPhoneController.text.trim() : null,
      'delivery_state': draft.selectedState,
      'delivery_city': draft.selectedCity,
      'delivery_address': _addressController.text.trim(),
      'landmark': _landmarkController.text.trim().isNotEmpty ? _landmarkController.text.trim() : null,
      'product_name': fullProductName,
      'quantity': totalUnits,
      'paid_quantity': paidUnits,
      'free_quantity': freeUnits,
      'base_price': basePrice,
      'upsell_amount': draft.upsellAmount,
      'total_amount': draft.totalAmount,
      'payment_type': draft.paymentType,
      'payment_status': draft.paymentType == 'prepaid' ? 'paid' : 'pending',
      'fulfillment_type': 'distributed_inventory',
      'client_id': draft.clientId,
      'client_name': draft.clientName,
      'client_company': draft.clientCompany,
      'client_phone': draft.clientPhone,
      'client_email': draft.clientEmail,
      'package_deal_id': draft.selectedPackage?.id,
      'package_deal_name': draft.selectedPackage?.packageName,
      'client_delivery_fee': 5000.0,
      'agent_entitlement': 2500.0,
      'delivery_notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      'status': draft.assignImmediately && draft.selectedRiderId != null ? 'assigned' : 'unassigned',
      'financial_settlement_status': draft.paymentType == 'prepaid' ? 'direct_transfer_settled' : 'pending_remittance',
      'distribution_center_id': dcState.activeHubId,
      'delivery_agent_id': draft.assignImmediately ? draft.selectedRiderId : null,
      'delivery_agent_name': draft.assignImmediately ? draft.selectedRiderName : null,
      'delivery_agent_code': draft.assignImmediately ? draft.selectedRiderCode : null,
      'created_at': DateTime.now().toIso8601String(),
    };

    final success = await ref.read(ordersProvider.notifier).createOrder(orderPayload);

    if (mounted) {
      ref.read(dcCreateOrderDraftProvider.notifier).setSubmitting(false);
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
    final stockState = ref.watch(stockProvider);
    final catalogState = ref.watch(productCatalogProvider);
    final draft = ref.watch(dcCreateOrderDraftProvider);
    final availablePackages = catalogState.getPackagesForProduct(draft.selectedProductName);
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
                      // CSV Bulk Import Prompt Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need to create multiple orders at once?',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                  Text(
                                    'Import a spreadsheet / CSV file to batch upload orders.',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const DCCsvOrderImportModal(),
                                );
                              },
                              icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                              label: const Text('Import CSV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                          value: draft.selectedState,
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
                              ref.read(dcCreateOrderDraftProvider.notifier).setLocation(
                                    v,
                                    newCities.isNotEmpty ? newCities.first : 'Central',
                                  );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: NigeriaLocations.getCitiesForState(draft.selectedState).contains(draft.selectedCity)
                              ? draft.selectedCity
                              : (NigeriaLocations.getCitiesForState(draft.selectedState).isNotEmpty
                                  ? NigeriaLocations.getCitiesForState(draft.selectedState).first
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
                          items: NigeriaLocations.getCitiesForState(draft.selectedState).map((z) {
                            return DropdownMenuItem(
                              value: z,
                              child: Text(z, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(dcCreateOrderDraftProvider.notifier).setCity(v);
                            }
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: draft.selectedState,
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
                                    ref.read(dcCreateOrderDraftProvider.notifier).setLocation(
                                          v,
                                          newCities.isNotEmpty ? newCities.first : 'Central',
                                        );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: NigeriaLocations.getCitiesForState(draft.selectedState).contains(draft.selectedCity)
                                    ? draft.selectedCity
                                    : (NigeriaLocations.getCitiesForState(draft.selectedState).isNotEmpty
                                        ? NigeriaLocations.getCitiesForState(draft.selectedState).first
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
                                items: NigeriaLocations.getCitiesForState(draft.selectedState).map((z) {
                                  return DropdownMenuItem(
                                    value: z,
                                    child: Text(z, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    ref.read(dcCreateOrderDraftProvider.notifier).setCity(v);
                                  }
                                },
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
                              final isSelected = p.name == draft.selectedProductName;
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
                                      'Seller Packages for ${draft.selectedProductName}',
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
                                    final isSelected = draft.selectedPackage?.id == pkg.id;
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
                                          onPressed: draft.quantity > 1
                                              ? () {
                                                  final next = draft.quantity - 1;
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
                                            final next = draft.quantity + 1;
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
                          value: draft.paymentType,
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
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(dcCreateOrderDraftProvider.notifier).setPaymentType(v);
                            }
                          },
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
                                          onPressed: draft.quantity > 1
                                              ? () {
                                                  final next = draft.quantity - 1;
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
                                            final next = draft.quantity + 1;
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
                                value: draft.paymentType,
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
                                onChanged: (v) {
                                  if (v != null) {
                                    ref.read(dcCreateOrderDraftProvider.notifier).setPaymentType(v);
                                  }
                                },
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
                                      if (draft.selectedPackage != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            draft.selectedPackage!.packageName,
                                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatNaira(draft.totalAmount),
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
                                color: draft.paymentType == 'pay_on_delivery' ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                draft.paymentType == 'pay_on_delivery' ? 'POD Cash' : 'Prepaid Cleared',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: draft.paymentType == 'pay_on_delivery' ? const Color(0xFFD97706) : const Color(0xFF059669),
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
                        value: draft.assignImmediately,
                        onChanged: (val) => ref.read(dcCreateOrderDraftProvider.notifier).setAssignImmediately(val),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Assign immediately to a Rider', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          draft.assignImmediately
                              ? 'Order routes directly to selected rider terminal'
                              : 'Order enters DC Unassigned Pool for queue dispatching',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                        activeColor: const Color(0xFF2563EB),
                      ),

                      if (draft.assignImmediately) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: draft.selectedRiderId,
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

                            final driverAllocations = stockState.getAllocationsForRider(d.id, d.driverCode);
                            final matchingAllocations = driverAllocations.where((a) {
                              final prodA = a.productName.toLowerCase();
                              final orderP = draft.selectedProductName.toLowerCase();
                              return (orderP.isNotEmpty && (prodA.contains(orderP) || orderP.contains(prodA))) ||
                                  (a.sku.isNotEmpty && orderP.contains(a.sku.toLowerCase()));
                            }).toList();

                            final totalCustodyUnits = matchingAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);

                            final activeReservedUnits = ordersState.orders.where((o) {
                              final isThisDriver = (o.deliveryAgentId == d.id || o.deliveryAgentCode == d.driverCode);
                              final isActive = o.status == 'in_transit' || o.status == 'accepted' || o.status == 'out_for_delivery' || o.status == 'assigned' || o.status == 'contacting';
                              final isSameProduct = o.productName.toLowerCase().contains(draft.selectedProductName.toLowerCase()) || draft.selectedProductName.toLowerCase().contains(o.productName.toLowerCase());
                              return isThisDriver && isActive && isSameProduct;
                            }).fold(0, (sum, o) => sum + o.quantity);

                            final availableCustodyUnits = (totalCustodyUnits - activeReservedUnits).clamp(0, 999999);
                            final hasStock = availableCustodyUnits >= draft.quantity;
                            final stockLabel = hasStock
                                ? '✓ Stock: $availableCustodyUnits'
                                : (totalCustodyUnits > 0 ? '⚠️ Stock: $availableCustodyUnits (Low)' : '⚠️ 0 in Vehicle');

                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                '${d.name} (${d.driverCode}) • $stockLabel • $activeCount Active',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: !hasStock && !isDark ? const Color(0xFFDC2626) : null,
                                  fontWeight: hasStock ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final driver = dcState.drivers.firstWhere((d) => d.id == val);
                              ref.read(dcCreateOrderDraftProvider.notifier).setRider(driver.id, driver.name, driver.driverCode);
                            }
                          },
                          validator: (v) {
                            if (draft.assignImmediately) {
                              if (v == null || v.isEmpty) {
                                return 'Please select a rider or toggle off immediate assignment';
                              }
                              final targetDriver = dcState.drivers.firstWhere((d) => d.id == v);
                              final driverAlloc = stockState.getAllocationsForRider(targetDriver.id, targetDriver.driverCode);
                              final matching = driverAlloc.where((a) {
                                final pA = a.productName.toLowerCase();
                                final oP = draft.selectedProductName.toLowerCase();
                                return (oP.isNotEmpty && (pA.contains(oP) || oP.contains(pA))) ||
                                    (a.sku.isNotEmpty && oP.contains(a.sku.toLowerCase()));
                              }).toList();
                              final total = matching.fold(0, (sum, a) => sum + a.inCustodyUnits);
                              final reserved = ordersState.orders.where((o) {
                                final isThis = (o.deliveryAgentId == targetDriver.id || o.deliveryAgentCode == targetDriver.driverCode);
                                final isActive = o.status == 'in_transit' || o.status == 'accepted' || o.status == 'out_for_delivery' || o.status == 'assigned' || o.status == 'contacting';
                                final isSame = o.productName.toLowerCase().contains(draft.selectedProductName.toLowerCase()) || draft.selectedProductName.toLowerCase().contains(o.productName.toLowerCase());
                                return isThis && isActive && isSame;
                              }).fold(0, (sum, o) => sum + o.quantity);
                              final avail = (total - reserved).clamp(0, 999999);
                              if (total == 0 || avail < draft.quantity) {
                                return 'Rider ${targetDriver.name} has insufficient vehicle stock ($avail avail vs ${draft.quantity} needed)';
                              }
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
                            onPressed: draft.isSubmitting ? null : () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: draft.isSubmitting ? null : _submitOrder,
                            icon: draft.isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                            label: Text(
                              draft.isSubmitting ? 'Creating...' : 'Create Order',
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
                          onPressed: draft.isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: draft.isSubmitting ? null : _submitOrder,
                          icon: draft.isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: Text(
                            draft.isSubmitting ? 'Creating...' : 'Create Order & Log Waybill',
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
                'New Package for ${ref.read(dcCreateOrderDraftProvider).selectedProductName}',
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

              final draft = ref.read(dcCreateOrderDraftProvider);
              final newPkg = ref.read(productCatalogProvider.notifier).addPackageToProduct(
                    productName: draft.selectedProductName,
                    packageName: name,
                    quantity: qty,
                    packagePrice: price,
                    clientName: draft.clientName,
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
            final stock = ref.read(stockProvider);

            final allProducts = List<CatalogProduct>.from(catalog.products);
            for (final item in stock.stockItems) {
              if (!allProducts.any((p) => p.name.toLowerCase() == item.name.toLowerCase() || p.sku.toLowerCase() == item.sku.toLowerCase())) {
                allProducts.add(CatalogProduct(
                  id: item.id,
                  name: item.name,
                  sku: item.sku,
                  clientName: item.ownerName,
                  defaultUnitPrice: item.price,
                  category: item.category,
                  packages: [
                    ProductPackage(
                      id: 'pkg-${item.sku.toLowerCase()}-1',
                      productId: item.id,
                      productName: item.name,
                      productSku: item.sku,
                      packageName: '1 Unit (Single)',
                      quantity: 1,
                      paidQuantity: 1,
                      freeQuantity: 0,
                      packagePrice: item.price,
                      clientName: item.ownerName,
                      createdAt: DateTime.now(),
                    ),
                  ],
                ));
              }
            }

            final filtered = allProducts.where((p) {
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
                        final isSelected = p.name == ref.read(dcCreateOrderDraftProvider).selectedProductName;
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
