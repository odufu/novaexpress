import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/client_supplier.dart';
import '../providers/client_portal_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ClientAddSupplierModal extends ConsumerStatefulWidget {
  final ClientSupplier? existingSupplier;

  const ClientAddSupplierModal({
    super.key,
    this.existingSupplier,
  });

  static Future<ClientSupplier?> show(BuildContext context, {ClientSupplier? existingSupplier}) {
    return showDialog<ClientSupplier>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientAddSupplierModal(existingSupplier: existingSupplier),
    );
  }

  @override
  ConsumerState<ClientAddSupplierModal> createState() => _ClientAddSupplierModalState();
}

class _ClientAddSupplierModalState extends ConsumerState<ClientAddSupplierModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Herbal Formulations & Pharma');
  final _paymentTermsController = TextEditingController(text: 'Net 30 Days');
  final _leadTimeController = TextEditingController(text: '7');
  final _bankNameController = TextEditingController(text: 'Access Bank');
  final _bankAccountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  List<String> _selectedProductNames = [];

  final List<String> _commonCategories = [
    'Herbal Formulations & Pharma',
    'Packaging Materials & Bottling',
    'Logistics, Haulage & Clearing',
    'Finished Goods Manufacturing',
    'Raw Ingredients Supply',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingSupplier != null) {
      final s = widget.existingSupplier!;
      _nameController.text = s.name;
      _contactPersonController.text = s.contactPerson;
      _emailController.text = s.email;
      _phoneController.text = s.phone;
      _categoryController.text = s.category;
      _paymentTermsController.text = s.paymentTerms;
      _leadTimeController.text = s.leadTimeDays.toString();
      _bankNameController.text = s.bankName;
      _bankAccountController.text = s.accountNumber;
      _notesController.text = s.notes;
      _selectedProductNames = List<String>.from(s.suppliedProducts);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _categoryController.dispose();
    _paymentTermsController.dispose();
    _leadTimeController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final profile = ref.read(clientPortalProvider).clientProfile;
      var clientId = profile.id.isNotEmpty
          ? profile.id
          : (ref.read(authProvider).user?.clientId ?? '');
      if (clientId.isEmpty) {
        clientId = '00000000-0000-4000-8000-789382731303';
      }

      if (widget.existingSupplier != null) {
        final updated = widget.existingSupplier!.copyWith(
          supplierName: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'General',
          paymentTerms: _paymentTermsController.text.trim(),
          leadTimeDays: int.tryParse(_leadTimeController.text.trim()) ?? 7,
          bankName: _bankNameController.text.trim(),
          accountNumber: _bankAccountController.text.trim(),
          accountName: _nameController.text.trim(),
          notes: _notesController.text.trim(),
          suppliedProducts: _selectedProductNames,
        );
        await ref.read(clientPortalProvider.notifier).updateSupplier(updated);

        if (mounted) {
          Navigator.of(context).pop(updated);
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
                      'Supplier "${updated.name}" updated successfully (${_selectedProductNames.length} products linked)!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        final newSupplier = ClientSupplier(
          id: '',
          clientId: clientId,
          supplierName: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'General',
          paymentTerms: _paymentTermsController.text.trim(),
          leadTimeDays: int.tryParse(_leadTimeController.text.trim()) ?? 7,
          bankName: _bankNameController.text.trim(),
          accountNumber: _bankAccountController.text.trim(),
          accountName: _nameController.text.trim(),
          notes: _notesController.text.trim(),
          suppliedProducts: _selectedProductNames,
          createdAt: DateTime.now(),
        );
        final supplier = await ref.read(clientPortalProvider.notifier).createSupplier(newSupplier);

        if (mounted) {
          Navigator.of(context).pop(supplier);
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
                      'Supplier "${supplier.name}" added to procurement directory!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to save supplier: $e'),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_rounded, color: Color(0xFF0D9488), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingSupplier != null
                              ? 'Edit Supplier / Vendor'
                              : 'Register Product Supplier / Vendor',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Maintain direct procurement vendor records, lead times & bank details',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 480;

                  Widget buildFieldPair({
                    required Widget first,
                    required Widget second,
                    int firstFlex = 1,
                    int secondFlex = 1,
                  }) {
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          first,
                          const SizedBox(height: 14),
                          second,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: firstFlex, child: first),
                        const SizedBox(width: 14),
                        Expanded(flex: secondFlex, child: second),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 16 : 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Supplier / Vendor Company Name *', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                            decoration: _inputDecoration(
                              hintText: 'e.g. Apex Herbal Labs Ltd',
                              icon: Icons.store_rounded,
                              isDark: isDark,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Supplier name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          buildFieldPair(
                            first: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Procurement Category', isDark),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _commonCategories.contains(_categoryController.text)
                                      ? _categoryController.text
                                      : _commonCategories.first,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                  decoration: _inputDecoration(hintText: 'Category', icon: Icons.category_rounded, isDark: isDark),
                                  items: _commonCategories
                                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) _categoryController.text = val;
                                  },
                                ),
                              ],
                            ),
                            second: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Payment Terms', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _paymentTermsController,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                                  decoration: _inputDecoration(hintText: 'e.g. Net 30 Days', icon: Icons.payments_rounded, isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          buildFieldPair(
                            first: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Contact Person', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactPersonController,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                                  decoration: _inputDecoration(hintText: 'e.g. Dr. Patrick Okonjo', icon: Icons.person_rounded, isDark: isDark),
                                ),
                              ],
                            ),
                            second: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Lead Time (Days)', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _leadTimeController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                                  decoration: _inputDecoration(hintText: '7', icon: Icons.timelapse_rounded, isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          buildFieldPair(
                            first: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Phone Number', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                                  decoration: _inputDecoration(hintText: 'e.g. 08031234567', icon: Icons.phone_rounded, isDark: isDark),
                                ),
                              ],
                            ),
                            second: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Email Address', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                                  decoration: _inputDecoration(hintText: 'procurement@vendor.com', icon: Icons.email_rounded, isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bank Details
                          _buildLabel('Supplier Bank Account (For Remittances)', isDark),
                          const SizedBox(height: 6),
                          buildFieldPair(
                            firstFlex: 2,
                            secondFlex: 3,
                            first: TextFormField(
                              controller: _bankNameController,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                              decoration: _inputDecoration(hintText: 'Bank Name', icon: Icons.account_balance_rounded, isDark: isDark),
                            ),
                            second: TextFormField(
                              controller: _bankAccountController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                              decoration: _inputDecoration(hintText: 'Account Number (10-digit NUBAN)', icon: Icons.numbers_rounded, isDark: isDark),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildLabel('Procurement Notes & Delivery Location', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                            decoration: _inputDecoration(
                              hintText: 'e.g. Depot factory location, batch quality certification notes...',
                              icon: Icons.notes_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Linked Catalog Products Selection Section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF0D9488)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Linked Catalog Products',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_selectedProductNames.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedProductNames.length} linked',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select the products supplied by this vendor to calculate network stock, evaluate stock health, and enable 1-click reorder intake.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          _buildProductSelectionGrid(isDark),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : (widget.existingSupplier != null ? 'Update Vendor' : 'Register Supplier'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0D9488)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
      ),
    );
  }

  Widget _buildProductSelectionGrid(bool isDark) {
    final allProducts = ref.watch(clientPortalProvider).products;
    if (allProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No products found in catalog. Create products in "Products & Deals" to link them to this vendor.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action toolbar: Quick Select All / Clear
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select all products supplied by this vendor:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedProductNames = allProducts.map((p) => p.name).toList();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Select All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedProductNames.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Clear', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Product Cards List
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: allProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final product = allProducts[index];
              final isSelected = _selectedProductNames.any((sp) {
                final target = sp.trim().toLowerCase();
                return target == product.name.trim().toLowerCase() ||
                    target == product.sku.trim().toLowerCase() ||
                    target == product.id.trim().toLowerCase();
              });

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedProductNames.removeWhere((sp) {
                        final target = sp.trim().toLowerCase();
                        return target == product.name.trim().toLowerCase() ||
                            target == product.sku.trim().toLowerCase() ||
                            target == product.id.trim().toLowerCase();
                      });
                    } else {
                      _selectedProductNames.add(product.name);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF0D9488).withValues(alpha: 0.18) : const Color(0xFF0D9488).withValues(alpha: 0.08))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D9488)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'SKU: ${product.sku.isNotEmpty ? product.sku : 'N/A'} • ${product.category}',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: product.stockQuantity <= product.lowStockThreshold
                              ? const Color(0xFFFEE2E2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${product.stockQuantity} units',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: product.stockQuantity <= product.lowStockThreshold
                                ? const Color(0xFFDC2626)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
