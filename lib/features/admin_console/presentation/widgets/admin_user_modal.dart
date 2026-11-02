import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

class AdminUserModal extends StatefulWidget {
  final AdminUserItem? initialUser;
  final List<AdminDistributionCenter> distributionCenters;
  final List<AdminMerchant> merchants;
  final ValueChanged<AdminUserItem> onSave;

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

  late String _role;
  String? _selectedDcId;
  String? _selectedClientId;
  late String _status;

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
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final dc = widget.distributionCenters.where((d) => d.id == _selectedDcId).firstOrNull;
    final merchant = widget.merchants.where((m) => m.id == _selectedClientId).firstOrNull;

    final user = AdminUserItem(
      id: widget.initialUser?.id ?? 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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

    widget.onSave(user);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialUser != null;

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
                        value: _selectedDcId,
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
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
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
