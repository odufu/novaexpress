import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

class AdminEditProductModal extends ConsumerStatefulWidget {
  final AdminGlobalStockItem product;

  const AdminEditProductModal({
    super.key,
    required this.product,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminGlobalStockItem product,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminEditProductModal(product: product),
    );
  }

  @override
  ConsumerState<AdminEditProductModal> createState() => _AdminEditProductModalState();
}

class _AdminEditProductModalState extends ConsumerState<AdminEditProductModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _abujaShelfCtrl;
  late TextEditingController _lagosShelfCtrl;

  String? _selectedMerchantId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.productName);
    _skuCtrl = TextEditingController(text: p.sku);
    _priceCtrl = TextEditingController(text: p.unitPrice.toStringAsFixed(0));
    _abujaShelfCtrl = TextEditingController(
      text: (p.dcStockBreakdown['Abuja Central DC'] ?? 0).toString(),
    );
    _lagosShelfCtrl = TextEditingController(
      text: (p.dcStockBreakdown['Lagos Central DC'] ?? 0).toString(),
    );
    _selectedMerchantId = p.merchantId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _abujaShelfCtrl.dispose();
    _lagosShelfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsoleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final merchants = state.merchants;
    final selectedMerchant = merchants.where((m) => m.id == _selectedMerchantId).firstOrNull ??
        (merchants.isNotEmpty
            ? merchants.first
            : AdminMerchant(id: widget.product.merchantId, businessName: widget.product.merchantName, contactName: '', phone: '', email: ''));

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Product & Inventory',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Update master SKU metadata and DC warehouse inventory allocations',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Identification
                      Text(
                        'PRODUCT IDENTIFICATION',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Product Title / Commercial Name', isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuCtrl,
                              decoration: _inputDeco('Unique Master SKU Code', isDark),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              decoration: _inputDeco('Retail Selling Price (NGN)', isDark),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Price is required';
                                if (double.tryParse(v) == null) return 'Must be a valid number';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Merchant Assignment
                      DropdownButtonFormField<String>(
                        value: _selectedMerchantId,
                        decoration: _inputDeco('Assigned Merchant / Brand Owner', isDark),
                        items: merchants.map((m) {
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text(m.businessName, style: GoogleFonts.inter(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMerchantId = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Warehouse Inventory
                      Text(
                        'WAREHOUSE INVENTORY ALLOCATION (SHELF UNITS)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _abujaShelfCtrl,
                              decoration: _inputDeco('Abuja Central DC (Units)', isDark),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lagosShelfCtrl,
                              decoration: _inputDeco('Lagos Central DC (Units)', isDark),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Saving changes will automatically synchronize product details in the database and reconcile physical inventory balances across both Abuja and Lagos Distribution Centers.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(_isSaving ? 'Persisting...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _saveChanges,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState?.validate() != true) return;

    final abuja = int.tryParse(_abujaShelfCtrl.text) ?? 0;
    final lagos = int.tryParse(_lagosShelfCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? widget.product.unitPrice;
    final currentUser = ref.read(authProvider).user;
    final state = ref.read(adminConsoleProvider);
    final merchant = state.merchants.where((m) => m.id == _selectedMerchantId).firstOrNull;

    final confirmed = await NovaCriticalActionConfirmationModal.show(
      context: context,
      actionName: 'Modify Product Specification & Inventory',
      operatorAccount: currentUser?.email ?? 'operations@novaxpress.ng',
      valuesets: {
        'Product Name': _nameCtrl.text.trim(),
        'Product SKU': _skuCtrl.text.trim(),
        'Retail Price': CurrencyFormatter.formatNaira(price),
        'Merchant': merchant?.businessName ?? widget.product.merchantName,
        'Abuja DC Shelf Stock': '$abuja units',
        'Lagos DC Shelf Stock': '$lagos units',
      },
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final success = await ref.read(adminConsoleProvider.notifier).updateProduct(
        productId: widget.product.productId,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        unitPrice: price,
        merchantId: _selectedMerchantId,
        merchantName: merchant?.businessName,
        dcStocks: {
          'Abuja Central DC': abuja,
          'Lagos Central DC': lagos,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Product ${_nameCtrl.text.trim()} successfully updated.'
                : 'Updated product locally; database sync logged.',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDeco(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }
}
