import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientAddProductModal extends ConsumerStatefulWidget {
  const ClientAddProductModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClientAddProductModal(),
    );
  }

  @override
  ConsumerState<ClientAddProductModal> createState() => _ClientAddProductModalState();
}

class _ClientAddProductModalState extends ConsumerState<ClientAddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'Health & Wellness';

  final List<String> _categories = [
    'Health & Wellness',
    'Supplements',
    'Cosmetics & Beauty',
    'Personal Care',
    'Beverages & Teas',
    'General Merchandise',
  ];

  final Set<String> _selectedStates = {'Federal Capital Territory'};
  String _stateSearchQuery = '';
  bool _isSubmitting = false;
  String? _selectedImageUrl;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _generateSku() {
    final name = _nameCtrl.text.trim();
    final prefix = name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : 'PRD';
    final randomNum = (1000 + math.Random().nextInt(9000)).toString();
    setState(() {
      _skuCtrl.text = 'SKU-$prefix-$randomNum';
    });
  }

  bool _stateMatches(String dcState, String targetState) {
    final cleanDc = dcState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanTarget = targetState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanDc.isEmpty || cleanTarget.isEmpty) return false;
    if (cleanDc == cleanTarget) return true;
    if (cleanDc.contains(cleanTarget) || cleanTarget.contains(cleanDc)) return true;
    if ((cleanDc.contains('abuja') || cleanDc.contains('fct')) &&
        (cleanTarget.contains('abuja') || cleanTarget.contains('fct'))) {
      return true;
    }
    return false;
  }

  List<DistributionCenter> _getMatchingDcs(List<DistributionCenter> allDcs) {
    return allDcs.where((dc) {
      return _selectedStates.any((st) => _stateMatches(dc.state, st));
    }).toList();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please select at least one covering state for this product.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final price = double.parse(_priceCtrl.text.trim().replaceAll(',', ''));
      final newProd = await ref.read(clientPortalProvider.notifier).createProduct(
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().toUpperCase(),
        category: _selectedCategory,
        unitPrice: price,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        imageUrl: _selectedImageUrl,
        coveringStates: _selectedStates.toList(),
      );

      if (!mounted) return;

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
                  '${newProd.name} registered! Initialized in ${_selectedStates.length} covering state DCs at 0 units awaiting supply.',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Product creation error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final allDcs = dcState.distributionCenters.isNotEmpty
        ? dcState.distributionCenters
        : defaultDistributionCenters;
    final matchingDcs = _getMatchingDcs(allDcs);

    final filteredStates = NigeriaLocations.states.where((s) {
      if (_stateSearchQuery.isEmpty) return true;
      return s.toLowerCase().contains(_stateSearchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF10172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFF37021), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Merchant Product',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Assign covering states so inventory is provisioned only to designated Hubs',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image Upload Card (Styled like DC Console)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ProductImageWidget(
                                  imageUrl: _selectedImageUrl,
                                  width: 68,
                                  height: 68,
                                  borderRadius: 10,
                                  fit: BoxFit.cover,
                                ),
                                if (_isUploadingImage)
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Product Image / Photo',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedImageUrl != null
                                        ? 'Image attached for catalog, stock & rider apps'
                                        : 'Upload a product photo to represent this item across Hubs & Rider apps',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: (_isUploadingImage || _isSubmitting)
                                            ? null
                                            : () async {
                                                final messenger = ScaffoldMessenger.of(context);
                                                try {
                                                  setState(() => _isUploadingImage = true);
                                                  final result = await FilePickerPlatform.instance.pickFiles(
                                                    type: FileType.image,
                                                  );

                                                  if (result.isNotEmpty) {
                                                    final file = result.first;
                                                    final bytes = await file.readAsBytes();

                                                    if (bytes.isNotEmpty) {
                                                      final ext = file.extension?.toLowerCase() ?? 'jpg';
                                                      final uploadedUrl = await SignatureStorageService.uploadProductImage(
                                                        bytes: bytes,
                                                        extension: ext,
                                                      );

                                                      if (mounted) {
                                                        setState(() {
                                                          _selectedImageUrl = uploadedUrl;
                                                          _isUploadingImage = false;
                                                        });
                                                      }
                                                    } else {
                                                      if (mounted) setState(() => _isUploadingImage = false);
                                                    }
                                                  } else {
                                                    if (mounted) setState(() => _isUploadingImage = false);
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    setState(() => _isUploadingImage = false);
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text('⚠️ Image selection error: $e'),
                                                        backgroundColor: const Color(0xFFEF4444),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                        icon: const Icon(Icons.cloud_upload_rounded, size: 14, color: Colors.white),
                                        label: Text(
                                          _selectedImageUrl != null ? 'Change Photo' : 'Upload Image',
                                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                      if (_selectedImageUrl != null)
                                        OutlinedButton.icon(
                                          onPressed: (_isUploadingImage || _isSubmitting)
                                              ? null
                                              : () {
                                                  setState(() => _selectedImageUrl = null);
                                                },
                                          icon: const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                                          label: const Text('Remove', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Product Name
                      Text(
                        'Product Name *',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        onChanged: (v) {
                          if (_skuCtrl.text.isEmpty && v.trim().isNotEmpty) {
                            _generateSku();
                          }
                        },
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g. Respira Detox Herbal Tea',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // SKU & Category Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Item SKU *',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                                    ),
                                    InkWell(
                                      onTap: _generateSku,
                                      child: Text(
                                        'Auto-Gen',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _skuCtrl,
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'SKU-RESP-01',
                                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'SKU is required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category *',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCategory = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Base Single Unit Price
                      Text(
                        'Base Single Unit Price (₦) *',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g. 25000',
                          prefixText: '₦ ',
                          prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Price is required';
                          final num = double.tryParse(v.trim().replaceAll(',', ''));
                          if (num == null || num <= 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Product Description (Optional)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Key health benefits, usage guidelines, ingredients...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // COVERING STATES MULTI-SELECTOR
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.map_rounded, size: 16, color: Color(0xFFF37021)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Product Covering States (${_selectedStates.length} Selected)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedStates.length == NigeriaLocations.states.length) {
                                        _selectedStates.clear();
                                      } else {
                                        _selectedStates.addAll(NigeriaLocations.states);
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedStates.length == NigeriaLocations.states.length ? 'Clear All' : 'Select All',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Only Distribution Centers located in these states will initialize this product in their inventory (initial quantity 0 units, awaiting consignment supply).',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // State Search Bar
                            TextField(
                              onChanged: (v) => setState(() => _stateSearchQuery = v.trim()),
                              style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Search Nigerian states (e.g. Abuja, Lagos, Benue)...',
                                hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // State Selection Chips
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 140),
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: filteredStates.map((state) {
                                    final isSelected = _selectedStates.contains(state);
                                    return FilterChip(
                                      selected: isSelected,
                                      showCheckmark: true,
                                      checkmarkColor: Colors.white,
                                      selectedColor: const Color(0xFFF37021),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      label: Text(
                                        state,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedStates.add(state);
                                          } else {
                                            _selectedStates.remove(state);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ==========================================
                      // LIVE DC COVERAGE PREVIEW
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: matchingDcs.isNotEmpty
                              ? (isDark ? const Color(0xFF0D251A) : const Color(0xFFECFDF5))
                              : (isDark ? const Color(0xFF2D1616) : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: matchingDcs.isNotEmpty
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  matchingDcs.isNotEmpty ? Icons.hub_rounded : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: matchingDcs.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  matchingDcs.isNotEmpty
                                      ? 'Distribution Hubs Receiving Initial Inventory (${matchingDcs.length})'
                                      : 'No Active Distribution Centers In Selected States',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: matchingDcs.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (matchingDcs.isNotEmpty) ...[
                              Text(
                                'This product will appear in the inventory of the following hubs with 0 available units awaiting initial stock consignment:',
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                              const SizedBox(height: 8),
                              ...matchingDcs.map((dc) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${dc.name} (${dc.state}) • Initial: 0 Units',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ] else ...[
                              Text(
                                'No distribution centers currently match your selected states. NovaExpress is rapidly expanding hubs across Nigeria. Select additional covering states like "Federal Capital Territory" or "Benue" to connect with active hubs.',
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Registering Product...' : 'Register Product & Provision DCs',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
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
