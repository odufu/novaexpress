import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/uuid_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

class AdminUserModal extends StatefulWidget {
  final AdminUserItem? initialUser;
  final List<AdminDistributionCenter> distributionCenters;
  final List<AdminMerchant> merchants;
  final FutureOr<void> Function(AdminUserItem user, String? password) onSave;

  const AdminUserModal({
    super.key,
    this.initialUser,
    required this.distributionCenters,
    required this.merchants,
    required this.onSave,
  });

  @override
  State<AdminUserModal> createState() => _AdminUserModalState();
}

class _AdminUserModalState extends State<AdminUserModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;

  late String _role;
  String? _selectedDcId;
  String? _selectedClientId;
  late String _status;
  bool _obscurePassword = true;
  bool _enablePasswordReset = false;

  final List<Map<String, String>> _availableRoles = const [
    {'value': 'super_admin', 'label': 'Super Administrator'},
    {'value': 'dc_manager', 'label': 'DC Operations Supervisor'},
    {'value': 'dc_operations', 'label': 'DC Orders & Dispatch Officer'},
    {'value': 'dc_stock_admin', 'label': 'DC Stock Management Officer'},
    {'value': 'dc_finance_admin', 'label': 'DC Finance & Remittance Officer'},
    {'value': 'general_accountant', 'label': 'General Accountant'},
    {'value': 'sales_supervisor', 'label': 'Merchant Sales Rep Supervisor'},
    {'value': 'closer', 'label': 'Telesales Closer'},
    {'value': 'marketer', 'label': 'Digital Marketer'},
    {'value': 'client', 'label': 'E-Commerce Merchant'},
    {'value': 'merchant_inventory_officer', 'label': 'Merchant Inventory Officer'},
    {'value': 'delivery_agent', 'label': 'Field Delivery Agent (PDA / Rider)'},
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    _firstNameController = TextEditingController(text: u?.firstName ?? '');
    _lastNameController = TextEditingController(text: u?.lastName ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _passwordController = TextEditingController();
    _role = u?.role ?? 'dc_operations';
    _selectedDcId = u?.distributionCenterId;
    _selectedClientId = u?.clientId;
    _status = u?.status ?? 'active';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final rand = DateTime.now().millisecondsSinceEpoch;
    final num = 1000 + (rand % 9000);
    const symbols = ['!', '@', '#', '\$', '%', '&'];
    final sym = symbols[rand % symbols.length];
    setState(() {
      _passwordController.text = 'Nova$sym$num';
      _obscurePassword = false;
    });
  }

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final isEditing = widget.initialUser != null;
    final dc = widget.distributionCenters.where((d) => d.id == _selectedDcId).firstOrNull;
    final merchant = widget.merchants.where((m) => m.id == _selectedClientId).firstOrNull;

    final user = AdminUserItem(
      id: widget.initialUser?.id ?? UuidHelper.generate(),
      email: _emailController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _role,
      distributionCenterId: _selectedDcId,
      distributionCenterName: dc?.name ?? widget.initialUser?.distributionCenterName,
      clientId: _selectedClientId,
      clientCompanyName: merchant?.businessName ?? widget.initialUser?.clientCompanyName,
      status: _status,
      deliveryAgentCode: widget.initialUser?.deliveryAgentCode,
      closerCode: widget.initialUser?.closerCode,
      createdAt: widget.initialUser?.createdAt ?? DateTime.now(),
      lastActiveAt: widget.initialUser?.lastActiveAt ?? DateTime.now(),
    );

    final String? passwordToSave;
    if (!isEditing) {
      passwordToSave = _passwordController.text.trim();
    } else if (_enablePasswordReset && _passwordController.text.trim().isNotEmpty) {
      passwordToSave = _passwordController.text.trim();
    } else {
      passwordToSave = null;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSave(user, passwordToSave);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to onboard user: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialUser != null;

    final showMerchantAssignment = _role == 'client' ||
        _role == 'merchant_inventory_officer' ||
        _role == 'closer' ||
        _role == 'sales_supervisor';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_outline_rounded, color: AppColors.orange, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Edit System User' : 'Onboard New User',
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

                  // Name Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name',
                          hint: 'e.g. Tunde',
                          isDark: isDark,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          hint: 'e.g. Adeleke',
                          isDark: isDark,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Email & Phone
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'user@novaxpress.ng',
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '+234 812 345 6789',
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Role Selection
                  Text(
                    'Operational Role',
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
                        value: _role,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        items: _availableRoles.map((r) {
                          return DropdownMenuItem<String>(
                            value: r['value'],
                            child: Text(
                              r['label']!,
                              style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _role = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Optional Merchant Assignment
                  if (showMerchantAssignment) ...[
                    Text(
                      'Assigned Merchant / Partner',
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
                        child: DropdownButton<String?>(
                          value: _selectedClientId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          hint: Text('None / Platform Wide', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8))),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None / Platform Wide', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                            ),
                            ...widget.merchants.map((m) {
                              return DropdownMenuItem<String?>(
                                value: m.id,
                                child: Text(m.businessName, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedClientId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Distribution Center Assignment
                  Text(
                    'Assigned Distribution Center',
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
                      child: DropdownButton<String?>(
                        value: _selectedDcId == null
                            ? null
                            : (widget.distributionCenters.any((dc) => dc.id == _selectedDcId)
                                ? _selectedDcId
                                : (_selectedDcId!.contains('2222') || _selectedDcId!.contains('ABJ')
                                    ? (widget.distributionCenters.any((dc) => dc.id == 'DC-ABJ-01') ? 'DC-ABJ-01' : null)
                                    : (_selectedDcId!.contains('7924') || _selectedDcId!.contains('LAG')
                                        ? (widget.distributionCenters.any((dc) => dc.id == 'DC-LAG-01') ? 'DC-LAG-01' : null)
                                        : null))),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        hint: Text('None / Corporate Wide', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8))),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None / Corporate Wide', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                          ),
                          ...widget.distributionCenters.map((dc) {
                            return DropdownMenuItem<String?>(
                              value: dc.id,
                              child: Text('${dc.name} (${dc.city})', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedDcId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password Management
                  if (!isEditing) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Initial Account Password *',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppColors.orange),
                          label: Text(
                            'Generate Secure',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange),
                          ),
                          onPressed: _generatePassword,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Password is required for user onboarding';
                        if (v.trim().length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter login password (e.g. Nova@2026!)',
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
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The user will log in with this initial password and can change it anytime in their profile.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Reset User Password',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _enablePasswordReset,
                                activeColor: AppColors.orange,
                                onChanged: (val) {
                                  setState(() {
                                    _enablePasswordReset = val;
                                    if (!val) _passwordController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_enablePasswordReset) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'New Password *',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppColors.orange),
                                  label: Text(
                                    'Generate',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange),
                                  ),
                                  onPressed: _generatePassword,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              validator: (v) {
                                if (_enablePasswordReset) {
                                  if (v == null || v.trim().isEmpty) return 'Enter the new password';
                                  if (v.trim().length < 6) return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Enter new password for user',
                                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Account Status Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Account Status',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Switch(
                        value: _status == 'active',
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() => _status = val ? 'active' : 'suspended');
                        },
                      ),
                    ],
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
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isEditing ? 'Save Changes' : 'Create User',
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
