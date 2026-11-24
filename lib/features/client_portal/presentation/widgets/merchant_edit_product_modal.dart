import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/merchant_inventory_models.dart';
import '../providers/merchant_inventory_provider.dart';

/// Modal dialog for Merchant Stock Keeper to edit product metadata, description, and images
class MerchantEditProductModal extends ConsumerStatefulWidget {
  final MerchantProductStockView product;

  const MerchantEditProductModal({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, MerchantProductStockView product) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MerchantEditProductModal(product: product),
    );
  }

  @override
  ConsumerState<MerchantEditProductModal> createState() => _MerchantEditProductModalState();
}

class _MerchantEditProductModalState extends ConsumerState<MerchantEditProductModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _imageUrlCtrl;

  bool _isSaving = false;

  // Curated Preset Image Library for quick selection by stock keeper
  static const List<Map<String, String>> _presetImages = [
    {
      'label': 'Herbal Tea / Detox',
      'url': 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Cleanse Infusion',
      'url': 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Kidney & Vitality Detox',
      'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Hair Shampoo & Scalp',
      'url': 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Compression Vest',
      'url': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Cosmetic Essence',
      'url': 'https://images.unsplash.com/photo-1608248597359-0021665a5895?auto=format&fit=crop&w=400&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _skuCtrl = TextEditingController(text: widget.product.sku);
    _categoryCtrl = TextEditingController(text: widget.product.category);
    _priceCtrl = TextEditingController(text: widget.product.unitPrice.toStringAsFixed(0));
    _descriptionCtrl = TextEditingController(text: widget.product.description ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.product.imageUrl ?? '');
    _imageUrlCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final parsedPrice = double.tryParse(_priceCtrl.text.trim()) ?? widget.product.unitPrice;

    setState(() => _isSaving = true);

    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      unitPrice: parsedPrice,
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      imageUrl: _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim(),
    );

    ref.read(merchantInventoryProvider.notifier).updateProduct(updatedProduct);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product "${updatedProduct.name}" updated successfully!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentImage = _imageUrlCtrl.text.trim();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
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
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Product Catalog',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'SKU: ${widget.product.sku}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Live Product Image Preview & URL Input
                      Text(
                        'Product Image & Visuals',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: currentImage.isNotEmpty
                              ? Image.network(
                                  currentImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image_outlined, size: 28, color: Color(0xFF94A3B8)),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Invalid URL',
                                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFF94A3B8)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'No Image',
                                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Image URL input
                      TextFormField(
                        controller: _imageUrlCtrl,
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Image Direct URL',
                          hintText: 'https://...',
                          prefixIcon: const Icon(Icons.link_rounded, size: 18),
                          suffixIcon: currentImage.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => _imageUrlCtrl.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Preset images chips
                      Text(
                        'Or select from curated catalog presets:',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _presetImages.map((preset) {
                          final isSelected = _imageUrlCtrl.text == preset['url'];
                          return ActionChip(
                            avatar: Icon(
                              isSelected ? Icons.check_circle : Icons.image_outlined,
                              size: 14,
                              color: isSelected ? Colors.white : AppColors.orange,
                            ),
                            label: Text(
                              preset['label']!,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                            backgroundColor: isSelected
                                ? AppColors.orange
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            onPressed: () {
                              _imageUrlCtrl.text = preset['url']!;
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 2. Product Name
                      TextFormField(
                        controller: _nameCtrl,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Product name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 3. Subtitle / Description
                      TextFormField(
                        controller: _descriptionCtrl,
                        maxLines: 3,
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Product Subtitle / Description',
                          hintText: 'e.g. Weight lose and Leaver Detox tea',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 36),
                            child: Icon(Icons.description_outlined, size: 18),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Category & Price in Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _categoryCtrl,
                              style: GoogleFonts.inter(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Category *',
                                prefixIcon: const Icon(Icons.category_outlined, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Category required';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Unit Price (₦) *',
                                prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Price required';
                                if (double.tryParse(val.trim()) == null) return 'Enter valid number';
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
            ),

            // Modal Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
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
