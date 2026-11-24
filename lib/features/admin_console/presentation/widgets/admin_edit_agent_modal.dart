import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/admin_models.dart';

class AdminEditAgentModal extends StatefulWidget {
  final AdminLogisticsAgent agent;
  final List<AdminMerchant> availableMerchants;
  final ValueChanged<AdminLogisticsAgent> onSave;

  const AdminEditAgentModal({
    super.key,
    required this.agent,
    required this.availableMerchants,
    required this.onSave,
  });

  @override
  State<AdminEditAgentModal> createState() => _AdminEditAgentModalState();
}

class _AdminEditAgentModalState extends State<AdminEditAgentModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _contactController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _deliveryFeeController;
  late TextEditingController _failedFeeController;
  late TextEditingController _commissionRateController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  late TextEditingController _statesController;

  late String _type;
  late String _status;
  late String _warehouseId;
  late String _warehouseName;
  late List<String> _selectedMerchantIds;
  late List<String> _selectedMerchantNames;

  static const List<AdminMerchant> _fallbackMerchants = [
    AdminMerchant(
      id: 'merchant-novacare',
      businessName: 'NOVACARE LIMITED',
      contactName: 'Operations Lead',
      phone: '+234 803 123 4567',
      email: 'novacare@novaxpress.ng',
      tier: 'Enterprise',
    ),
    AdminMerchant(
      id: 'merchant-shop11',
      businessName: 'Shop Eleven Limited',
      contactName: 'Fulfillment Desk',
      phone: '+234 802 987 6543',
      email: 'shopeleven@novaxpress.ng',
      tier: 'Enterprise',
    ),
    AdminMerchant(
      id: 'merchant-leafora',
      businessName: 'Leafora Direct',
      contactName: 'Brand Manager',
      phone: '+234 809 555 4321',
      email: 'leafora@novaxpress.ng',
      tier: 'Standard',
    ),
  ];

  List<AdminMerchant> get _effectiveMerchants {
    if (widget.availableMerchants.isNotEmpty) {
      return widget.availableMerchants;
    }
    return _fallbackMerchants;
  }

  bool _matchesMerchant(AdminMerchant m) {
    if (_selectedMerchantIds.contains(m.id)) return true;
    if (_selectedMerchantNames.any((n) =>
        n.toLowerCase() == m.businessName.toLowerCase() ||
        n.toLowerCase().contains(m.businessName.toLowerCase()) ||
        m.businessName.toLowerCase().contains(n.toLowerCase()))) {
      return true;
    }
    final bLower = m.businessName.toLowerCase();
    if (bLower.contains('nova') && _selectedMerchantIds.any((id) => id.contains('novacare'))) {
      return true;
    }
    if ((bLower.contains('shop') || bLower.contains('eleven')) &&
        _selectedMerchantIds.any((id) => id.contains('shop11') || id.contains('shopeleven'))) {
      return true;
    }
    if (bLower.contains('leafora') && _selectedMerchantIds.any((id) => id.contains('leafora'))) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final a = widget.agent;
    _nameController = TextEditingController(text: a.name);
    _codeController = TextEditingController(text: a.agentCode);
    _contactController = TextEditingController(text: a.contactPerson);
    _phoneController = TextEditingController(text: a.phone);
    _emailController = TextEditingController(text: a.email);
    _deliveryFeeController = TextEditingController(text: a.deliveryFee.toStringAsFixed(0));
    _failedFeeController = TextEditingController(text: a.failedDeliveryFee.toStringAsFixed(0));
    _commissionRateController = TextEditingController(text: a.commissionRate.toStringAsFixed(1));
    _bankNameController = TextEditingController(text: a.bankName.isNotEmpty ? a.bankName : 'Zenith Bank');
    _accountNumberController = TextEditingController(text: a.accountNumber);
    _accountNameController = TextEditingController(text: a.accountName);
    _statesController = TextEditingController(text: a.coverageStates.join(', '));

    _type = const ['3pl_partner', 'internal_logistics', 'distributor_agent', 'rider_agent'].contains(a.type)
        ? a.type
        : '3pl_partner';
    _status = const ['active', 'pending_approval', 'suspended'].contains(a.status)
        ? a.status
        : 'active';

    final rawWhId = (a.assignedWarehouseId ?? '').toUpperCase();
    final rawWhName = (a.assignedWarehouseName ?? '').toUpperCase();
    if (rawWhId.contains('LAG') || rawWhId.contains('7924') || rawWhId.contains('0039') || rawWhName.contains('LAGOS')) {
      _warehouseId = 'DC-LAG-01';
      _warehouseName = 'Lagos Central DC';
    } else {
      _warehouseId = 'DC-ABJ-01';
      _warehouseName = 'Abuja Central DC';
    }
    _selectedMerchantIds = List<String>.from(a.assignedMerchantIds);
    _selectedMerchantNames = List<String>.from(a.assignedMerchantNames);

    for (final m in _effectiveMerchants) {
      if (_matchesMerchant(m)) {
        if (!_selectedMerchantIds.contains(m.id)) _selectedMerchantIds.add(m.id);
        if (!_selectedMerchantNames.contains(m.businessName)) _selectedMerchantNames.add(m.businessName);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _deliveryFeeController.dispose();
    _failedFeeController.dispose();
    _commissionRateController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _statesController.dispose();
    super.dispose();
  }

  void _toggleMerchant(AdminMerchant merchant, bool select) {
    setState(() {
      final bLower = merchant.businessName.toLowerCase();
      String slug = '';
      if (bLower.contains('nova')) {
        slug = 'merchant-novacare';
      } else if (bLower.contains('shop') || bLower.contains('eleven')) {
        slug = 'merchant-shop11';
      } else if (bLower.contains('leafora')) {
        slug = 'merchant-leafora';
      }

      if (select) {
        if (!_selectedMerchantIds.contains(merchant.id)) _selectedMerchantIds.add(merchant.id);
        if (slug.isNotEmpty && !_selectedMerchantIds.contains(slug)) _selectedMerchantIds.add(slug);
        if (!_selectedMerchantNames.contains(merchant.businessName)) _selectedMerchantNames.add(merchant.businessName);
      } else {
        _selectedMerchantIds.remove(merchant.id);
        if (slug.isNotEmpty) {
          _selectedMerchantIds.remove(slug);
          _selectedMerchantIds.remove('merchant-shopeleven');
        }
        _selectedMerchantNames.removeWhere((n) =>
            n.toLowerCase() == merchant.businessName.toLowerCase() ||
            n.toLowerCase().contains(merchant.businessName.toLowerCase()) ||
            merchant.businessName.toLowerCase().contains(n.toLowerCase()));
      }
    });
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final selectedMerchantNames = <String>[];
    for (final m in _effectiveMerchants) {
      if (_matchesMerchant(m)) {
        if (!selectedMerchantNames.contains(m.businessName)) {
          selectedMerchantNames.add(m.businessName);
        }
      }
    }
    for (final n in _selectedMerchantNames) {
      if (!selectedMerchantNames.contains(n)) {
        selectedMerchantNames.add(n);
      }
    }

    final updated = widget.agent.copyWith(
      name: _nameController.text.trim(),
      agentCode: _codeController.text.trim(),
      type: _type,
      status: _status,
      contactPerson: _contactController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      deliveryFee: double.tryParse(_deliveryFeeController.text.trim()) ?? widget.agent.deliveryFee,
      failedDeliveryFee: double.tryParse(_failedFeeController.text.trim()) ?? widget.agent.failedDeliveryFee,
      commissionRate: double.tryParse(_commissionRateController.text.trim()) ?? widget.agent.commissionRate,
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim(),
      assignedWarehouseId: _warehouseId,
      assignedWarehouseName: _warehouseName,
      coverageStates: _statesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      assignedMerchantIds: _selectedMerchantIds,
      assignedMerchantNames: selectedMerchantNames,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
                          'Edit Agent Details & Fees',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Update delivery charges, failed fees, commissions, primary DC, and assigned merchants.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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

            // Modal Body Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      _sectionTitle('1. AGENT IDENTITY & ASSIGNED DISTRIBUTION CENTER'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: _inputDeco('Agent / Company Name *', isDark),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: _inputDeco('Agent Code *', isDark),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: const ['3pl_partner', 'internal_logistics', 'distributor_agent', 'rider_agent'].contains(_type)
                                  ? _type
                                  : '3pl_partner',
                              decoration: _inputDeco('Agent Classification', isDark),
                              items: const [
                                DropdownMenuItem(value: '3pl_partner', child: Text('3PL Partner Company')),
                                DropdownMenuItem(value: 'internal_logistics', child: Text('Internal Hub (NovaXpress)')),
                                DropdownMenuItem(value: 'distributor_agent', child: Text('Regional Distributor')),
                                DropdownMenuItem(value: 'rider_agent', child: Text('Rider Courier Agent')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _type = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: const ['DC-ABJ-01', 'DC-LAG-01'].contains(_warehouseId)
                                  ? _warehouseId
                                  : 'DC-ABJ-01',
                              decoration: _inputDeco('Primary Distribution Center', isDark),
                              items: const [
                                DropdownMenuItem(
                                  value: 'DC-ABJ-01',
                                  child: Text('Abuja Central DC'),
                                ),
                                DropdownMenuItem(
                                  value: 'DC-LAG-01',
                                  child: Text('Lagos Central DC'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _warehouseId = val;
                                    _warehouseName = val == 'DC-ABJ-01'
                                        ? 'Abuja Central DC'
                                        : 'Lagos Central DC';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: const ['active', 'pending_approval', 'suspended'].contains(_status)
                                  ? _status
                                  : 'active',
                              decoration: _inputDeco('Operating Status', isDark),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active (Authorized)')),
                                DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _status = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _statesController,
                              decoration: _inputDeco('Coverage States (comma separated)', isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Commercial Fees & Commission
                      _sectionTitle('2. LOGISTICS FEES & COMMISSIONS'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _deliveryFeeController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('Delivery Fee (₦) *', isDark),
                              validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid ₦ required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _failedFeeController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('Failed Delivery Fee (₦) *', isDark),
                              validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid ₦ required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _commissionRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDeco('Commission Rate (%) *', isDark),
                              validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid % required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Assigned Merchants / Partners Multi-Select
                      _sectionTitle('3. ASSIGNED MERCHANTS / PARTNERS (CUSTODY ACCESS)'),
                      const SizedBox(height: 6),
                      Text(
                        'When an agent is assigned to a merchant, that merchant can view the agent as authorized to hold their products and log daily sales.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: _effectiveMerchants.map((merchant) {
                            final isChecked = _matchesMerchant(merchant);
                            return CheckboxListTile(
                              value: isChecked,
                              dense: true,
                              activeColor: const Color(0xFF0284C7),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: Text(
                                merchant.businessName,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                'Tier: ${merchant.tier} • Email: ${merchant.email.isNotEmpty ? merchant.email : 'support@novaxpress.ng'}',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              ),
                              onChanged: (val) => _toggleMerchant(merchant, val ?? false),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dispatch Contact & Banking
                      _sectionTitle('4. DISPATCH CONTACT & SETTLEMENT ACCOUNT'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _contactController,
                              decoration: _inputDeco('Contact Person *', isDark),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: _inputDeco('Phone Number *', isDark),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDeco('Dispatch Email *', isDark),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bankNameController,
                              decoration: _inputDeco('Settlement Bank', isDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _accountNumberController,
                              decoration: _inputDeco('Account Number', isDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _accountNameController,
                              decoration: _inputDeco('Account Name', isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Actions
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
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Save Agent Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
      ),
    );
  }

  InputDecoration _inputDeco(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
