import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../domain/entities/lead_form.dart';
import '../providers/client_portal_provider.dart';

class ClientFormBuilderModal extends ConsumerStatefulWidget {
  final LeadForm? existingForm;
  final String? initialMarketerId;

  const ClientFormBuilderModal({
    super.key,
    this.existingForm,
    this.initialMarketerId,
  });

  static Future<void> show(
    BuildContext context, {
    LeadForm? existingForm,
    String? initialMarketerId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientFormBuilderModal(
        existingForm: existingForm,
        initialMarketerId: initialMarketerId,
      ),
    );
  }

  @override
  ConsumerState<ClientFormBuilderModal> createState() => _ClientFormBuilderModalState();
}

class _ClientFormBuilderModalState extends ConsumerState<ClientFormBuilderModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _slugController;
  late TextEditingController _redirectUrlController;
  late TextEditingController _pixelIdController;
  late TextEditingController _capiTokenController;
  late TextEditingController _testEventCodeController;
  late TextEditingController _buttonTextController;

  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedMarketerId;
  bool _isSubmitting = false;

  // Packages list
  late List<Map<String, dynamic>> _packages;

  @override
  void initState() {
    super.initState();
    final f = widget.existingForm;
    _titleController = TextEditingController(text: f?.title ?? '');
    _slugController = TextEditingController(text: f?.formSlug ?? '');
    _redirectUrlController = TextEditingController(text: f?.redirectUrl ?? '');
    _pixelIdController = TextEditingController(text: f?.pixelId ?? '');
    _capiTokenController = TextEditingController(text: f?.capiToken ?? '');
    _testEventCodeController = TextEditingController(text: f?.testEventCode ?? '');
    _buttonTextController = TextEditingController(text: f?.buttonText ?? 'CLAIM YOUR ORDER (PAY ON DELIVERY)');

    _selectedProductId = f?.productId;
    _selectedProductName = f?.productName;
    _selectedMarketerId = f?.marketerId ?? widget.initialMarketerId;

    if (f != null && f.packages.isNotEmpty) {
      _packages = f.packages.map((p) {
        final map = Map<String, dynamic>.from(p);
        final paid = (map['paid_quantity'] as num?)?.toInt() ?? ((map['quantity'] as num?)?.toInt() ?? 1);
        final free = (map['free_quantity'] as num?)?.toInt() ?? 0;
        final total = (map['quantity'] as num?)?.toInt() ?? (paid + free);
        final price = (map['price'] as num?)?.toDouble() ?? 25000.0;
        final actual = (map['actual_price'] as num?)?.toDouble() ?? (price * 1.25);
        map['paid_quantity'] = paid;
        map['free_quantity'] = free;
        map['quantity'] = total;
        map['price'] = price;
        map['actual_price'] = actual;
        return map;
      }).toList();
    } else {
      _packages = [
        {
          'id': 'pkg-1',
          'name': '1 Pack (Standard)',
          'price': 25000.0,
          'actual_price': 30000.0,
          'paid_quantity': 1,
          'free_quantity': 0,
          'quantity': 1,
          'is_default': true,
          'badge': 'Standard',
        },
        {
          'id': 'pkg-2',
          'name': '2 Packs + 1 FREE (Best Value)',
          'price': 45000.0,
          'actual_price': 75000.0,
          'paid_quantity': 2,
          'free_quantity': 1,
          'quantity': 3,
          'is_default': false,
          'badge': '🎁 Buy 2 Get 1 FREE (Save ₦30,000)',
        },
      ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _redirectUrlController.dispose();
    _pixelIdController.dispose();
    _capiTokenController.dispose();
    _testEventCodeController.dispose();
    _buttonTextController.dispose();
    super.dispose();
  }

  void _addPackage() {
    setState(() {
      final index = _packages.length + 1;
      _packages.add({
        'id': 'pkg-$index',
        'name': '$index Packs Deal',
        'price': 25000.0 * index,
        'actual_price': 30000.0 * index,
        'paid_quantity': index,
        'free_quantity': 0,
        'quantity': index,
        'is_default': false,
        'badge': '',
      });
    });
  }

  void _removePackage(int index) {
    if (_packages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 package offer is required')),
      );
      return;
    }
    setState(() {
      _packages.removeAt(index);
    });
  }

  void _applyPackagePreset(int index, String name, int paid, int free, double multiplier, String badge) {
    if (index >= _packages.length) return;
    setState(() {
      final pkg = _packages[index];
      pkg['name'] = name;
      pkg['paid_quantity'] = paid;
      pkg['free_quantity'] = free;
      pkg['quantity'] = paid + free;
      pkg['badge'] = badge;

      final catalogState = ref.read(productCatalogProvider);
      final product = catalogState.products.cast<CatalogProduct?>().firstWhere(
            (p) => p?.id == _selectedProductId,
            orElse: () => null,
          );
      final unitPrice = product?.defaultUnitPrice ?? 25000.0;
      final regularTotal = (paid + free) * unitPrice;
      pkg['actual_price'] = regularTotal;
      pkg['price'] = (unitPrice * multiplier).roundToDouble();
    });
  }

  void _importCatalogPackages() {
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first to import its catalog package deals.')),
      );
      return;
    }

    final catalogState = ref.read(productCatalogProvider);
    final clientState = ref.read(clientPortalProvider);

    final catalogPackages = catalogState.products
        .cast<CatalogProduct?>()
        .firstWhere((p) => p?.id == _selectedProductId, orElse: () => null)
        ?.packages ?? [];

    final clientPackages = clientState.packages.where((p) => p.productId == _selectedProductId).toList();
    final allDeals = catalogPackages.isNotEmpty ? catalogPackages : clientPackages;

    if (allDeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No catalog package deals found for this product.')),
      );
      return;
    }

    setState(() {
      _packages = allDeals.map((p) {
        final regularTotal = p.totalPhysicalQuantity > 0 ? (p.totalPhysicalQuantity * p.unitPrice) : p.packagePrice;
        final badge = p.freeQuantity > 0
            ? '🎁 Buy ${p.paidQuantity} Get ${p.freeQuantity} FREE'
            : (p.savingsPercent(p.unitPrice) > 0 ? 'Save ${p.savingsPercent(p.unitPrice).toStringAsFixed(0)}%' : '');
        return {
          'id': p.id,
          'name': p.packageName,
          'price': p.packagePrice,
          'actual_price': regularTotal,
          'paid_quantity': p.paidQuantity,
          'free_quantity': p.freeQuantity,
          'quantity': p.totalPhysicalQuantity,
          'is_default': p.paidQuantity == 1 && p.freeQuantity == 0,
          'badge': badge,
        };
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ Imported ${allDeals.length} package deal(s) directly from product catalog!'),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please select the Catalog Product associated with this form.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final title = _titleController.text.trim();
      final slug = _slugController.text.trim().isNotEmpty
          ? _slugController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-')
          : title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      final redirectUrl = _redirectUrlController.text.trim();
      final pixelId = _pixelIdController.text.trim();
      final capiToken = _capiTokenController.text.trim();
      final testCode = _testEventCodeController.text.trim();
      final buttonText = _buttonTextController.text.trim();

      if (widget.existingForm != null) {
        await ref.read(clientPortalProvider.notifier).updateLeadForm(
          formId: widget.existingForm!.id,
          title: title,
          formSlug: slug,
          productId: _selectedProductId,
          productName: _selectedProductName,
          packages: _packages,
          redirectUrl: redirectUrl,
          pixelId: pixelId,
          capiToken: capiToken,
          testEventCode: testCode,
          buttonText: buttonText,
        );
      } else {
        await ref.read(clientPortalProvider.notifier).createLeadForm(
          title: title,
          formSlug: slug,
          productId: _selectedProductId!,
          productName: _selectedProductName ?? 'Product',
          marketerId: _selectedMarketerId,
          packages: _packages,
          redirectUrl: redirectUrl,
          pixelId: pixelId,
          capiToken: capiToken,
          testEventCode: testCode,
          buttonText: buttonText,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              widget.existingForm != null
                  ? 'Lead Form "$title" updated successfully!'
                  : 'Campaign Lead Form "$title" created and ready for traffic!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final clientProfile = ref.watch(clientPortalProvider).clientProfile;
    final marketers = ref.watch(clientPortalProvider).marketers;
    final products = catalog.products.where((p) =>
        p.clientId == clientProfile.id ||
        p.clientName.toLowerCase() == clientProfile.name.toLowerCase() ||
        p.clientName.toLowerCase() == clientProfile.companyName.toLowerCase() ||
        clientProfile.name.isEmpty).toList();

    final displayProducts = products.isNotEmpty ? products : catalog.products;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_add, color: Color(0xFF6366F1), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingForm != null ? 'Edit Campaign Form' : 'Create Campaign Lead Form',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'High-converting landing page form with Meta CAPI & closer auto-split',
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
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Basic Campaign Info
                      Text('CAMPAIGN & PRODUCT MAPPING', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5)),
                      const SizedBox(height: 10),

                      // Form Title
                      Text('Form Campaign Title', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Ultra Hair Growth Serum - Flash Sale 2026',
                          prefixIcon: const Icon(Icons.title_rounded, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a form title' : null,
                      ),
                      const SizedBox(height: 14),

                      // Product Selector & Marketer Dropdowns
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isRow = constraints.maxWidth >= 500;
                          final productDropdown = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attached Catalog Product *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedProductId,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                hint: const Text('Select product'),
                                items: displayProducts.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(p.name, style: GoogleFonts.inter(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedProductId = val;
                                    final match = displayProducts.firstWhere((p) => p.id == val, orElse: () => displayProducts.first);
                                    _selectedProductName = match.name;
                                    if (_titleController.text.trim().isEmpty) {
                                      _titleController.text = '${match.name} Special Offer';
                                    }
                                  });
                                },
                              ),
                            ],
                          );

                          final marketerDropdown = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attributed Digital Marketer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedMarketerId,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                hint: const Text('Store Default (Direct/Internal)'),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Store Default (Direct/Internal)'),
                                  ),
                                  ...marketers.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m.id,
                                      child: Text('${m.fullName} (${m.marketerCode})', style: GoogleFonts.inter(fontSize: 13)),
                                    );
                                  }),
                                ],
                                onChanged: (val) => setState(() => _selectedMarketerId = val),
                              ),
                            ],
                          );

                          return isRow
                              ? Row(
                                  children: [
                                    Expanded(child: productDropdown),
                                    const SizedBox(width: 14),
                                    Expanded(child: marketerDropdown),
                                  ],
                                )
                              : Column(
                                  children: [
                                    productDropdown,
                                    const SizedBox(height: 14),
                                    marketerDropdown,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Packages & Deals Pricing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'OFFER PACKAGES & BUNDLE PRICING (CLOSER PARITY)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _importCatalogPackages,
                            icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF10B981)),
                            label: Text(
                              'Import Catalog Deals',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: _addPackage,
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF6366F1)),
                            label: Text('Add Deal', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Packages list
                      ..._packages.asMap().entries.map((entry) {
                        final i = entry.key;
                        final pkg = entry.value;

                        final price = (pkg['price'] as num?)?.toDouble() ?? 0.0;
                        final actualPrice = (pkg['actual_price'] as num?)?.toDouble() ?? price;
                        final paidQty = (pkg['paid_quantity'] as num?)?.toInt() ?? ((pkg['quantity'] as num?)?.toInt() ?? 1);
                        final freeQty = (pkg['free_quantity'] as num?)?.toInt() ?? 0;
                        final totalQty = (pkg['quantity'] as num?)?.toInt() ?? (paidQty + freeQty);
                        final hasFree = freeQty > 0;
                        final hasSavings = actualPrice > price;
                        final savingsAmount = hasSavings ? (actualPrice - price) : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasFree ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                              width: hasFree ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar: Option index, Preset Chips & Delete
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: (hasFree ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.15),
                                    child: Text(
                                      '${i + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: hasFree ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Package Option #${i + 1}',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                                    ),
                                  ),
                                  if (_packages.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removePackage(i),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Quick Deal Presets for this card
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: const Text('1 Single', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    onPressed: () => _applyPackagePreset(i, '1 Pack (Standard)', 1, 0, 1.0, 'Standard'),
                                  ),
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: const Text('2 Packs', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    onPressed: () => _applyPackagePreset(i, '2 Packs Value Deal', 2, 0, 1.8, 'Popular (Save 10%)'),
                                  ),
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    label: const Text('🎁 Buy 2 Get 1 FREE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                    onPressed: () => _applyPackagePreset(i, 'Buy 2 Get 1 FREE (3 Total)', 2, 1, 2.0, '🎁 +1 FREE Included'),
                                  ),
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    label: const Text('🔥 Buy 3 Get 2 FREE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                                    onPressed: () => _applyPackagePreset(i, 'Buy 3 Get 2 FREE Mega Bundle (5 Total)', 3, 2, 2.8, '🔥 Mega Deal (2 FREE)'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Inputs Row 1: Name, Deal Price, Actual Price
                              Row(
                                children: [
                                  // Name
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: pkg['name']?.toString() ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Package Name',
                                        hintText: 'e.g. Buy 2 Get 1 FREE',
                                        isDense: true,
                                      ),
                                      onChanged: (v) => pkg['name'] = v.trim(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Offer/Selling Price
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: price.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Offer Price (₦)',
                                        prefixText: '₦',
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState(() {
                                        pkg['price'] = double.tryParse(v.trim()) ?? 0.0;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Actual Retail Price
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: actualPrice.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Actual Price (₦)',
                                        prefixText: '₦',
                                        hintText: 'Strikethrough',
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState(() {
                                        pkg['actual_price'] = double.tryParse(v.trim()) ?? 0.0;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Inputs Row 2: Paid Units, Free Units, Total Units
                              Row(
                                children: [
                                  // Paid
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: paidQty.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Paid Units',
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState(() {
                                        final p = int.tryParse(v.trim()) ?? 1;
                                        pkg['paid_quantity'] = p;
                                        pkg['quantity'] = p + ((pkg['free_quantity'] as num?)?.toInt() ?? 0);
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Free Units
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: freeQty.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Free / Bonus',
                                        prefixIcon: Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFF10B981)),
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState(() {
                                        final f = int.tryParse(v.trim()) ?? 0;
                                        pkg['free_quantity'] = f;
                                        pkg['quantity'] = ((pkg['paid_quantity'] as num?)?.toInt() ?? 1) + f;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Total Units (Stock deduction)
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Total Stock Deduct', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
                                          Text(
                                            '$totalQty Units',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Promo Badge Tag
                              TextFormField(
                                initialValue: pkg['badge']?.toString() ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Promo Badge Tag (Optional)',
                                  hintText: 'e.g. 🎁 Buy 2 Get 1 FREE (Save ₦20,000) or Recommended',
                                  isDense: true,
                                ),
                                onChanged: (v) => pkg['badge'] = v.trim(),
                              ),

                              // Live Deal Summary Banner
                              if (hasFree || hasSavings) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (hasFree ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasFree ? Icons.card_giftcard_rounded : Icons.local_offer_rounded,
                                        size: 14,
                                        color: hasFree ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Customer Deal: $paidQty Paid + $freeQty FREE = $totalQty Total Units • Deal: ₦${price.toStringAsFixed(0)} (Retail: ₦${actualPrice.toStringAsFixed(0)}, Save ₦${savingsAmount.toStringAsFixed(0)})',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: hasFree ? const Color(0xFF047857) : const Color(0xFF4338CA),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      // Section 3: Ad Tracking & Meta CAPI
                      Text('META PIXEL & CONVERSIONS API (CAPI)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(
                        'Orders booked through this form fire Purchase & Lead events automatically back to Facebook Ads Manager.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isRow = constraints.maxWidth >= 500;
                          final pixelField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Meta Pixel ID', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _pixelIdController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 123456789012345',
                                  prefixIcon: const Icon(Icons.radar_rounded, size: 20, color: Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                            ],
                          );

                          final testCodeField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CAPI Test Event Code (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _testEventCodeController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. TEST12345',
                                  prefixIcon: const Icon(Icons.science_outlined, size: 20, color: Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                            ],
                          );

                          return isRow
                              ? Row(
                                  children: [
                                    Expanded(child: pixelField),
                                    const SizedBox(width: 14),
                                    Expanded(child: testCodeField),
                                  ],
                                )
                              : Column(
                                  children: [
                                    pixelField,
                                    const SizedBox(height: 14),
                                    testCodeField,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 14),

                      Text('Meta CAPI Access Token (Optional - Server-to-Server)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _capiTokenController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'EAA...',
                          prefixIcon: const Icon(Icons.key_rounded, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Redirect & Call to Action
                      Text('THANK YOU REDIRECT & CTA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5)),
                      const SizedBox(height: 10),

                      Text('Thank You Page Redirect URL', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _redirectUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://mywebsite.com/thank-you',
                          prefixIcon: const Icon(Icons.link_rounded, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Form Submit Button Text', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _buttonTextController,
                        decoration: InputDecoration(
                          hintText: 'CLAIM YOUR ORDER (PAY ON DELIVERY)',
                          prefixIcon: const Icon(Icons.touch_app_rounded, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                widget.existingForm != null ? 'Save Changes' : 'Publish Lead Form',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
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
}
