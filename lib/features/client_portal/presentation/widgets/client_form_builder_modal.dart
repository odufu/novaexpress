import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
      _packages = List<Map<String, dynamic>>.from(f.packages);
    } else {
      _packages = [
        {
          'id': 'pkg-1',
          'name': '1 Pack (Standard)',
          'price': 25000,
          'quantity': 1,
          'is_default': true,
          'badge': 'Standard',
        },
        {
          'id': 'pkg-2',
          'name': '2 Packs (Promo - Best Value)',
          'price': 45000,
          'quantity': 2,
          'is_default': false,
          'badge': 'Most Popular (Save ₦5,000)',
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
        'price': 25000 * index,
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
                          Text('OFFER PACKAGES & BUNDLE PRICING', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5)),
                          TextButton.icon(
                            onPressed: _addPackage,
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                            label: Text('Add Package', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Packages list
                      ..._packages.asMap().entries.map((entry) {
                        final i = entry.key;
                        final pkg = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))),
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // Name
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: pkg['name']?.toString() ?? '',
                                      decoration: const InputDecoration(labelText: 'Package Name', hintText: 'e.g. 1 Bottle (Standard)', isDense: true),
                                      onChanged: (v) => pkg['name'] = v.trim(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Price
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: pkg['price']?.toString() ?? '25000',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Price (₦)', prefixText: '₦', isDense: true),
                                      onChanged: (v) => pkg['price'] = double.tryParse(v.trim()) ?? 0.0,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Units
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: pkg['quantity']?.toString() ?? '1',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Units', isDense: true),
                                      onChanged: (v) => pkg['quantity'] = int.tryParse(v.trim()) ?? 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: pkg['badge']?.toString() ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Promo Badge Tag (Optional)',
                                  hintText: 'e.g. Most Popular (Save ₦5,000) or Recommended',
                                  isDense: true,
                                ),
                                onChanged: (v) => pkg['badge'] = v.trim(),
                              ),
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
