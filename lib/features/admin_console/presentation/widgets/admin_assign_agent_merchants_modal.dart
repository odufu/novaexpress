import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/admin_models.dart';

class AdminAssignAgentMerchantsModal extends StatefulWidget {
  final AdminLogisticsAgent agent;
  final List<AdminMerchant> availableMerchants;
  final void Function(List<String> merchantIds, List<String> merchantNames) onSave;

  const AdminAssignAgentMerchantsModal({
    super.key,
    required this.agent,
    required this.availableMerchants,
    required this.onSave,
  });

  @override
  State<AdminAssignAgentMerchantsModal> createState() => _AdminAssignAgentMerchantsModalState();
}

class _AdminAssignAgentMerchantsModalState extends State<AdminAssignAgentMerchantsModal> {
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
    _selectedMerchantIds = List<String>.from(widget.agent.assignedMerchantIds);
    _selectedMerchantNames = List<String>.from(widget.agent.assignedMerchantNames);

    // Pre-populate both lists based on current matches
    for (final m in _effectiveMerchants) {
      if (_matchesMerchant(m)) {
        if (!_selectedMerchantIds.contains(m.id)) _selectedMerchantIds.add(m.id);
        if (!_selectedMerchantNames.contains(m.businessName)) _selectedMerchantNames.add(m.businessName);
      }
    }
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

    widget.onSave(_selectedMerchantIds, selectedMerchantNames);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final merchants = _effectiveMerchants;

    final selectedCount = merchants.where(_matchesMerchant).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub_outlined, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Merchants / Partners',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.agent.name,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
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

            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select which merchants can utilize ${widget.agent.name} as a designated stock holding custodian. You can assign or unassign at any time.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
              ),
            ),

            // Merchant Checkbox List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shrinkWrap: true,
                itemCount: merchants.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final merchant = merchants[index];
                  final isChecked = _matchesMerchant(merchant);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _toggleMerchant(merchant, !isChecked),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChecked
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            activeColor: const Color(0xFF8B5CF6),
                            onChanged: (val) => _toggleMerchant(merchant, val ?? false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant.businessName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${merchant.tier} Tier • ${merchant.email.isNotEmpty ? merchant.email : 'support@novaxpress.ng'}',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (isChecked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ASSIGNED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
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

            // Footer
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$selectedCount of ${merchants.length} selected',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _handleSave,
                        child: const Text('Save Assignments'),
                      ),
                    ],
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
