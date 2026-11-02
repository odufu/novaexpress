import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

class AdminDCModal extends StatefulWidget {
  final AdminDistributionCenter? initialDc;
  final ValueChanged<AdminDistributionCenter> onSave;

  const AdminDCModal({
    super.key,
    this.initialDc,
    required this.onSave,
  });

  @override
  State<AdminDCModal> createState() => _AdminDCModalState();
}

class _AdminDCModalState extends State<AdminDCModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _addressController;
  late TextEditingController _supervisorController;
  late TextEditingController _capacityController;
  late bool _isGrandDc;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDc;
    _nameController = TextEditingController(text: d?.name ?? '');
    _codeController = TextEditingController(text: d?.code ?? '');
    _cityController = TextEditingController(text: d?.city ?? '');
    _stateController = TextEditingController(text: d?.state ?? 'Lagos');
    _addressController = TextEditingController(text: d?.address ?? '');
    _supervisorController = TextEditingController(text: d?.supervisorName ?? '');
    _capacityController = TextEditingController(text: (d?.capacity ?? 5000).toString());
    _isGrandDc = d?.isGrandDc ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _supervisorController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final dc = AdminDistributionCenter(
      id: widget.initialDc?.id ?? 'DC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      code: _codeController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      address: _addressController.text.trim(),
      supervisorName: _supervisorController.text.trim().isEmpty ? 'Unassigned' : _supervisorController.text.trim(),
      capacity: int.tryParse(_capacityController.text.trim()) ?? 5000,
      activeRiders: widget.initialDc?.activeRiders ?? 0,
      currentStockCount: widget.initialDc?.currentStockCount ?? 0,
      vaultBalance: widget.initialDc?.vaultBalance ?? 0.0,
      status: widget.initialDc?.status ?? 'operational',
      isGrandDc: _isGrandDc,
    );

    widget.onSave(dc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialDc != null;

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
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.hub_outlined, color: Color(0xFF3B82F6), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Edit Distribution Center' : 'Add Distribution Center',
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
                    controller: _nameController,
                    label: 'Hub Name',
                    hint: 'e.g. Abuja Regional Gateway (Idu)',
                    isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _codeController,
                          label: 'Hub Code',
                          hint: 'e.g. DC-ABJ-01',
                          isDark: isDark,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _capacityController,
                          label: 'Parcel Capacity',
                          hint: '5000',
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
                          controller: _cityController,
                          label: 'City / LGA',
                          hint: 'e.g. Ikeja',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'e.g. Lagos',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _addressController,
                    label: 'Physical Address',
                    hint: 'Plot 14, Commercial Avenue...',
                    isDark: isDark,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _supervisorController,
                    label: 'Lead Operations Supervisor',
                    hint: 'e.g. Babatunde Adeleke',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Grand Hub Flag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Set as Grand Central Mega-Hub (HQ)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Switch(
                        value: _isGrandDc,
                        activeColor: AppColors.orange,
                        onChanged: (val) => setState(() => _isGrandDc = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Buttons
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
                          isEditing ? 'Save Changes' : 'Create Hub',
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
    int maxLines = 1,
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
          maxLines: maxLines,
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
