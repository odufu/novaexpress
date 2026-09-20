import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/client_supplier.dart';
import '../providers/client_portal_provider.dart';

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
                      'Supplier "${updated.name}" updated successfully!',
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
          clientId: ref.read(clientPortalProvider).clientProfile.id,
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
}
