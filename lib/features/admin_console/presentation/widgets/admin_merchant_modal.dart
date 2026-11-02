import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

class AdminMerchantModal extends StatefulWidget {
  final AdminMerchant? initialMerchant;
  final ValueChanged<AdminMerchant> onSave;

  const AdminMerchantModal({
    super.key,
    this.initialMerchant,
    required this.onSave,
  });

  @override
  State<AdminMerchantModal> createState() => _AdminMerchantModalState();
}

class _AdminMerchantModalState extends State<AdminMerchantModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _contactNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  late TextEditingController _closerLimitController;

  late String _tier;
  late String _settlementSchedule;
  late bool _isBankVerified;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMerchant;
    _businessNameController = TextEditingController(text: m?.businessName ?? '');
    _contactNameController = TextEditingController(text: m?.contactName ?? '');
    _phoneController = TextEditingController(text: m?.phone ?? '');
    _emailController = TextEditingController(text: m?.email ?? '');
    _bankNameController = TextEditingController(text: m?.bankName ?? 'Zenith Bank');
    _accountNumberController = TextEditingController(text: m?.accountNumber ?? '');
    _accountNameController = TextEditingController(text: m?.accountName ?? '');
    _closerLimitController = TextEditingController(text: (m?.closerLimit ?? 5).toString());
    _tier = m?.tier ?? 'Standard';
    _settlementSchedule = m?.settlementSchedule ?? 'daily_t1';
    _isBankVerified = m?.isBankVerified ?? true;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _closerLimitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final merchant = AdminMerchant(
      id: widget.initialMerchant?.id ?? 'CLI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      businessName: _businessNameController.text.trim(),
      contactName: _contactNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      tier: _tier,
      closerCount: widget.initialMerchant?.closerCount ?? 0,
      closerLimit: int.tryParse(_closerLimitController.text.trim()) ?? 5,
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim(),
      isBankVerified: _isBankVerified,
      settlementSchedule: _settlementSchedule,
      status: widget.initialMerchant?.status ?? 'active',
      activeOrdersCount: widget.initialMerchant?.activeOrdersCount ?? 0,
      totalRemittedNaira: widget.initialMerchant?.totalRemittedNaira ?? 0.0,
    );

    widget.onSave(merchant);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialMerchant != null;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storefront_outlined, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Edit Merchant Account' : 'Onboard New Merchant',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _buildTextField(
                    controller: _businessNameController,
                    label: 'Business / Company Name',
                    hint: 'e.g. ComfortCare Health Direct',
                    isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _contactNameController,
                          label: 'Primary Contact Person',
                          hint: 'Dr. Michael Obi',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _closerLimitController,
                          label: 'Max Closers Limit',
                          hint: '8',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: '+234 803 888 9900',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _emailController,
                          label: 'Orders Email',
                          hint: 'orders@brand.ng',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tier & Settlement schedule
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Tier',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _tier,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  items: ['Standard', 'Enterprise'].map((t) {
                                    return DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(t, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _tier = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COD Remittance Schedule',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _settlementSchedule,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  items: const [
                                    DropdownMenuItem(value: 'daily_t1', child: Text('Daily T+1 (Fastest)')),
                                    DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly (Twice a week)')),
                                    DropdownMenuItem(value: 'weekly', child: Text('Weekly Settlement')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _settlementSchedule = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bank Account Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COD Remittance Bank Account (NUBAN)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                controller: _bankNameController,
                                label: 'Bank Name',
                                hint: 'Zenith Bank',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildTextField(
                                controller: _accountNumberController,
                                label: '10-Digit Account Number',
                                hint: '1014829104',
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _accountNameController,
                          label: 'Account Name (Must match CAC / Director)',
                          hint: 'ComfortCare Health Direct Ltd',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Onboard Merchant',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
