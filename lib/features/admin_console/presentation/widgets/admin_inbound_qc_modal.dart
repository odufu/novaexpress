import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../core/widgets/nova_tooltip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

class AdminInboundQCModal extends ConsumerStatefulWidget {
  final AdminGlobalStockItem? initialItem;

  const AdminInboundQCModal({super.key, this.initialItem});

  @override
  ConsumerState<AdminInboundQCModal> createState() => _AdminInboundQCModalState();
}

class _AdminInboundQCModalState extends ConsumerState<AdminInboundQCModal> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedSku;
  final _batchNumberCtrl = TextEditingController(text: 'BATCH-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01');
  final _producerCtrl = TextEditingController(text: 'Apex Botanical Labs Co.');
  final _totalUnitsCtrl = TextEditingController(text: '10000');
  final _abujaSplitCtrl = TextEditingController(text: '4500');
  final _lagosSplitCtrl = TextEditingController(text: '5500');
  final _sampleUnitsCtrl = TextEditingController(text: '20');
  final _quarantineUnitsCtrl = TextEditingController(text: '0');
  final _inspectorCtrl = TextEditingController(text: 'Usman Bello (Quality Officer)');
  final _qcNotesCtrl = TextEditingController();

  String _colorCheck = 'Passed (Vibrant/Uniform)';
  String _grindCheck = 'Passed (Fine Uniform Grind)';
  String _packagingCheck = 'Passed (Security Seal Intact)';
  String _overallRating = 'Good';

  @override
  void initState() {
    super.initState();
    final stockItems = ref.read(adminConsoleProvider).globalStock;
    _selectedSku = widget.initialItem?.sku ?? (stockItems.isNotEmpty ? stockItems.first.sku : 'SKU-PRD-8309');
  }

  @override
  void dispose() {
    _batchNumberCtrl.dispose();
    _producerCtrl.dispose();
    _totalUnitsCtrl.dispose();
    _abujaSplitCtrl.dispose();
    _lagosSplitCtrl.dispose();
    _sampleUnitsCtrl.dispose();
    _quarantineUnitsCtrl.dispose();
    _inspectorCtrl.dispose();
    _qcNotesCtrl.dispose();
    super.dispose();
  }

  void _rebalanceSplits(String val) {
    final total = int.tryParse(val) ?? 0;
    final half = (total / 2).round();
    _abujaSplitCtrl.text = '$half';
    _lagosSplitCtrl.text = '${total - half}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsoleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedProduct = state.globalStock.firstWhere(
      (p) => p.sku == _selectedSku,
      orElse: () => state.globalStock.isNotEmpty
          ? state.globalStock.first
          : const AdminGlobalStockItem(
              id: '',
              productId: '',
              productName: 'Select Product',
              sku: '',
              merchantId: '',
              merchantName: '',
              unitPrice: 0,
              totalWarehouseStock: 0,
              totalRiderCustodyStock: 0,
              totalStock: 0,
            ),
    );

    final total = int.tryParse(_totalUnitsCtrl.text) ?? 0;
    final quarantined = int.tryParse(_quarantineUnitsCtrl.text) ?? 0;
    final netAccepted = (total - quarantined).clamp(0, 9999999);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inbound Batch Intake & Quality Assurance (QC)',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '48-Hour Spot Reconciliation • Bag Sampling • Color/Grind Check • Quarantine Buffer',
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

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Producer & Batch Waybill
                      Text(
                        '1. Producer Batch & Waybill Intake',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedSku,
                              isExpanded: true,
                              decoration: _inputDeco('Product Target *', isDark),
                              items: state.globalStock.map((item) {
                                return DropdownMenuItem(
                                  value: item.sku,
                                  child: Text(
                                    '${item.productName} (${item.merchantName})',
                                    style: GoogleFonts.inter(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSku = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _batchNumberCtrl,
                              decoration: _inputDeco('Batch Manifest ID *', isDark),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w600),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _producerCtrl,
                              decoration: _inputDeco('Producer / Supplier *', isDark),
                              style: GoogleFonts.inter(fontSize: 12.5),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _totalUnitsCtrl,
                              decoration: _inputDeco('Total Inbound Units *', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                              onChanged: _rebalanceSplits,
                              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid units' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 2: 48-Hour Hub Allocation Split
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
                              children: [
                                const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '48-Hour Spot Distribution Split (Abuja Gateway vs Lagos Grand Hub)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _abujaSplitCtrl,
                                    decoration: _inputDeco('Abuja Central DC (Units) *', isDark),
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lagosSplitCtrl,
                                    decoration: _inputDeco('Lagos Grand Hub (Units) *', isDark),
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Quality Check (QC) Sampling
                      Text(
                        '2. Quality Assurance Protocol (Sample Inspection)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sampleUnitsCtrl,
                              decoration: _inputDeco('Sample Units Extracted (e.g. 2 per bag) *', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _overallRating,
                              isExpanded: true,
                              decoration: _inputDeco('Overall Batch Rating *', isDark),
                              items: const [
                                DropdownMenuItem(value: 'Excellent', child: Text('Excellent (Zero Flaws)')),
                                DropdownMenuItem(value: 'Good', child: Text('Good (Standard Sellable)')),
                                DropdownMenuItem(value: 'Fair', child: Text('Fair (Minor Variation)')),
                                DropdownMenuItem(value: 'Rejected', child: Text('Rejected (Critical Fail)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _overallRating = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Criteria Checkboxes / Radios
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _colorCheck,
                              isExpanded: true,
                              decoration: _inputDeco('Color Dilation Test', isDark),
                              items: const [
                                DropdownMenuItem(value: 'Passed (Vibrant/Uniform)', child: Text('Passed (Vibrant/Uniform)')),
                                DropdownMenuItem(value: 'Flagged (Diluted/Pale)', child: Text('Flagged (Diluted/Pale)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _colorCheck = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _grindCheck,
                              isExpanded: true,
                              decoration: _inputDeco('Grind / Texture Consistency', isDark),
                              items: const [
                                DropdownMenuItem(value: 'Passed (Fine Uniform Grind)', child: Text('Passed (Fine Uniform Grind)')),
                                DropdownMenuItem(value: 'Flagged (Sticks/Coarse)', child: Text('Flagged (Sticks/Coarse)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _grindCheck = val);
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
                              value: _packagingCheck,
                              isExpanded: true,
                              decoration: _inputDeco('Packaging & Security Seal', isDark),
                              items: const [
                                DropdownMenuItem(value: 'Passed (Security Seal Intact)', child: Text('Passed (Security Seal Intact)')),
                                DropdownMenuItem(value: 'Flagged (Damaged)', child: Text('Flagged (Damaged)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _packagingCheck = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _quarantineUnitsCtrl,
                              decoration: _inputDeco('Quarantined Defect Units (Kept Aside)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _inspectorCtrl,
                              decoration: _inputDeco('QC Inspector Name *', isDark),
                              style: GoogleFonts.inter(fontSize: 12.5),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _qcNotesCtrl,
                        maxLines: 2,
                        decoration: _inputDeco('Inspection Findings, Observations & Defect Notes', isDark),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Net Calculation Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Accepted to Live Sellable Inventory: $netAccepted units',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                  ),
                                  Text(
                                    'Quarantined Substandard Bags: $quarantined units • Total Batch: $total units',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'QA GRADE: $_overallRating',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                  color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Sign Off Batch & Onboard Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState?.validate() != true) return;

                        final abuja = int.tryParse(_abujaSplitCtrl.text) ?? 0;
                        final lagos = int.tryParse(_lagosSplitCtrl.text) ?? 0;
                        final samples = int.tryParse(_sampleUnitsCtrl.text) ?? 20;
                        final currentUser = ref.read(authProvider).user;

                        final confirmed = await NovaCriticalActionConfirmationModal.show(
                          context: context,
                          actionName: 'Inbound Batch Intake & QC Certification',
                          operatorAccount: currentUser?.email ?? _inspectorCtrl.text.trim(),
                          valuesets: {
                            'Batch Number': _batchNumberCtrl.text.trim(),
                            'Target Product SKU': _selectedSku,
                            'Producer / Supplier': _producerCtrl.text.trim(),
                            'Total Units Received': '$total units',
                            'Abuja Central DC Allocation': '$abuja units',
                            'Lagos Central DC Allocation': '$lagos units',
                            'Net Accepted to Shelves': '$netAccepted units',
                            'Quarantined Units': '$quarantined units',
                            'QC Certification Status': '$_overallRating (PASSED)',
                          },
                        );
                        if (!confirmed || !mounted) return;

                        ref.read(adminConsoleProvider.notifier).recordInboundBatchQA(
                          sku: _selectedSku,
                          batchNumber: _batchNumberCtrl.text.trim(),
                          producerName: _producerCtrl.text.trim(),
                          totalUnitsReceived: total,
                          abujaSplit: abuja,
                          lagosSplit: lagos,
                          sampleUnitsTested: samples,
                          colorDilationCheck: _colorCheck,
                          grindConsistencyCheck: _grindCheck,
                          packagingCheck: _packagingCheck,
                          overallQualityRating: _overallRating,
                          quarantinedUnits: quarantined,
                          qcNotes: _qcNotesCtrl.text.trim(),
                          inspectorName: _inspectorCtrl.text.trim(),
                        );

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Successfully recorded Batch ${_batchNumberCtrl.text} ($netAccepted units accepted into warehouse shelves, $quarantined units quarantined).',
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
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

