import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/merchant_inventory_models.dart';
import '../providers/merchant_inventory_provider.dart';

class MerchantLogAgentSalesModal extends ConsumerStatefulWidget {
  final MerchantPartnerAgent? initialAgent;
  final String? initialSku;

  const MerchantLogAgentSalesModal({
    super.key,
    this.initialAgent,
    this.initialSku,
  });

  static Future<void> show(
    BuildContext context, {
    MerchantPartnerAgent? initialAgent,
    String? initialSku,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MerchantLogAgentSalesModal(
        initialAgent: initialAgent,
        initialSku: initialSku,
      ),
    );
  }

  @override
  ConsumerState<MerchantLogAgentSalesModal> createState() =>
      _MerchantLogAgentSalesModalState();
}

class _MerchantLogAgentSalesModalState
    extends ConsumerState<MerchantLogAgentSalesModal> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedAgentId;
  String? _selectedSku;

  final _unitsSoldCtrl = TextEditingController(text: '0');
  final _unitsReturnedCtrl = TextEditingController(text: '0');
  final _replenishedCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  // Ambush Audit Fields
  bool _includeAmbushAudit = false;
  final _physicalAuditCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedAgentId = widget.initialAgent?.id;
    _selectedSku = widget.initialSku;

    _unitsSoldCtrl.addListener(() => setState(() {}));
    _unitsReturnedCtrl.addListener(() => setState(() {}));
    _replenishedCtrl.addListener(() => setState(() {}));
    _physicalAuditCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _unitsSoldCtrl.dispose();
    _unitsReturnedCtrl.dispose();
    _replenishedCtrl.dispose();
    _notesCtrl.dispose();
    _physicalAuditCtrl.dispose();
    super.dispose();
  }

  int _getOpeningCustody(List<MerchantPartnerAgent> agents) {
    if (_selectedAgentId == null || _selectedSku == null) return 0;
    final agent = agents.firstWhere(
      (a) => a.id == _selectedAgentId,
      orElse: () => agents.first,
    );
    return agent.productCustody[_selectedSku] ?? 0;
  }

  int get _soldUnits => int.tryParse(_unitsSoldCtrl.text.trim()) ?? 0;
  int get _returnedUnits => int.tryParse(_unitsReturnedCtrl.text.trim()) ?? 0;
  int get _replenishedUnits => int.tryParse(_replenishedCtrl.text.trim()) ?? 0;

  void _adjustField(TextEditingController ctrl, int delta) {
    final current = int.tryParse(ctrl.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 99999);
    ctrl.text = '$next';
    setState(() {});
  }

  int _computeBalancedClosing(int opening) {
    final closing = opening + _replenishedUnits - _soldUnits - _returnedUnits;
    return closing < 0 ? 0 : closing;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgentId == null || _selectedSku == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please select both an Agent and a Product SKU.'),
        ),
      );
      return;
    }

    if (_soldUnits <= 0 && _returnedUnits <= 0 && _replenishedUnits <= 0 && !_includeAmbushAudit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please enter at least one movement: units sold, returned, replenished, or audit count.'),
        ),
      );
      return;
    }

    final authState = ref.read(authProvider);
    final loggedBy = authState.user?.fullName.isNotEmpty == true
        ? authState.user!.fullName
        : 'Amaka Obi (Stock Keeper)';

    final invState = ref.read(merchantInventoryProvider);
    final agent = invState.agents.firstWhere(
      (a) => a.id == _selectedAgentId,
      orElse: () => invState.agents.first,
    );
    final product = invState.products.firstWhere(
      (p) => p.sku == _selectedSku,
      orElse: () => invState.products.first,
    );

    final opening = _getOpeningCustody(invState.agents);
    final closing = _computeBalancedClosing(opening);

    // Mandatory Critical Action Confirmation Modal
    final confirmed = await NovaCriticalActionConfirmationModal.show(
      context: context,
      title: 'Confirm Daily Sales & Balance Stock',
      actionName: 'Post Sales for ${agent.name}',
      promptMessage:
          'You are about to record daily sales and balance stock for ${agent.name} on ${product.name}. Delivered sales will be automatically subtracted from custody.',
      valuesets: {
        'Delivery Agent': '${agent.name} (${agent.code})',
        'Product SKU': '${product.name} [$_selectedSku]',
        'Opening Custody': '$opening units',
        'Units Sold Today': '$_soldUnits units',
        'Units Returned': '$_returnedUnits units',
        'Inbound DC Restock': '+$_replenishedUnits units',
        'Balanced Closing Custody': '$closing units',
        'Authorizing Account': loggedBy,
      },
      operatorAccount: loggedBy,
      confirmLabel: 'Confirm & Post Sales',
      cancelLabel: 'Cancel',
      brandColor: const Color(0xFF059669),
      isDestructive: false,
    );

    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      int? physicalCount;
      if (_includeAmbushAudit) {
        physicalCount = int.tryParse(_physicalAuditCtrl.text.trim());
      }

      final record = ref.read(merchantInventoryProvider.notifier).recordDailySalesAndBalance(
            agentId: _selectedAgentId!,
            sku: _selectedSku!,
            unitsSold: _soldUnits,
            unitsReturned: _returnedUnits,
            replenishedUnits: _replenishedUnits,
            physicalAuditCount: physicalCount,
            notes: _notesCtrl.text.trim(),
            loggedBy: loggedBy,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: record.discrepancyFlagged ? const Color(0xFFF59E0B) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                record.discrepancyFlagged ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  record.discrepancyFlagged
                      ? 'Daily sales logged with audit variance flagged: ${record.closingCustody} balanced units.'
                      : 'Stock balanced! ${record.agentName} new custody: ${record.closingCustody} units.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Error balancing stock: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final merchantInv = ref.watch(merchantInventoryProvider);
    final agents = merchantInv.agents;
    final products = merchantInv.products;

    if (_selectedAgentId == null && agents.isNotEmpty) {
      _selectedAgentId = agents.first.id;
    }
    if (_selectedSku == null && products.isNotEmpty) {
      _selectedSku = products.first.sku;
    }

    final openingCustody = _getOpeningCustody(agents);
    final balancedClosing = _computeBalancedClosing(openingCustody);

    // Audit calculation
    int? physicalCount = _includeAmbushAudit ? int.tryParse(_physicalAuditCtrl.text.trim()) : null;
    double? variancePct;
    int? varianceUnits;
    bool exceedsThreshold = false;

    if (physicalCount != null) {
      varianceUnits = physicalCount - balancedClosing;
      if (balancedClosing > 0) {
        variancePct = (varianceUnits / balancedClosing) * 100.0;
        exceedsThreshold = variancePct.abs() > 5.0;
      } else if (varianceUnits != 0) {
        variancePct = 100.0;
        exceedsThreshold = true;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Daily Sales & Balance Stock',
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Record delivered units and sync partner agent custody ledger',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 14),

              // Agent Selector (Professional Mobile Searchable Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Delivery Agent / Partner *',
                placeholder: 'Tap to select delivery agent or 3PL...',
                value: _selectedAgentId,
                prefixIcon: Icons.two_wheeler_rounded,
                brandColor: const Color(0xFF0284C7),
                pickerTitle: 'Select Delivery Agent',
                pickerSubtitle: 'Choose assigned fleet courier or 3PL partner',
                options: agents.map((a) {
                  final isFleet = a.agentType.contains('Fleet') || a.code.startsWith('NX-');
                  final heldForSku = _selectedSku != null ? (a.productCustody[_selectedSku] ?? 0) : null;
                  return NovaPickerOption<String>(
                    value: a.id,
                    title: a.name,
                    subtitle: 'Code: ${a.code} • ${a.state}',
                    badgeText: isFleet ? 'FLEET' : '3PL',
                    badgeColor: isFleet ? const Color(0xFF0284C7) : const Color(0xFFF97316),
                    icon: Icons.two_wheeler_rounded,
                    trailingText: heldForSku != null ? '$heldForSku units held' : '${a.totalHeldUnits} held',
                    trailingTextColor: const Color(0xFF7C3AED),
                    searchTerms: [a.name, a.code, a.state, a.agentType],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAgentId = val);
                },
              ),
              const SizedBox(height: 14),

              // Product SKU Selector (Professional Mobile Searchable Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Product SKU *',
                placeholder: 'Tap to select product SKU...',
                value: _selectedSku,
                prefixIcon: Icons.inventory_2_outlined,
                brandColor: const Color(0xFF059669),
                pickerTitle: 'Select Product SKU',
                pickerSubtitle: 'Select product to balance custody ledger',
                options: products.map((p) {
                  return NovaPickerOption<String>(
                    value: p.sku,
                    title: p.name,
                    subtitle: 'SKU: ${p.sku} • Category: ${p.category}',
                    badgeText: p.sku,
                    badgeColor: const Color(0xFF059669),
                    icon: Icons.inventory_2_outlined,
                    trailingText: '₦${p.unitPrice.toStringAsFixed(0)}',
                    trailingTextColor: const Color(0xFF059669),
                    searchTerms: [p.name, p.sku, p.category],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSku = val);
                },
              ),
              const SizedBox(height: 16),

              // Stock Mathematical Balancing Ledger Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Starting Agent Custody',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                          ),
                        ),
                        Text(
                          '$openingCustody units',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '+ New Replenishment from DC',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF0284C7)),
                          ),
                        ),
                        Text(
                          '+$_replenishedUnits',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '- Delivered Daily Sales',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF059669)),
                          ),
                        ),
                        Text(
                          '-$_soldUnits',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '- Returns / Damaged from Field',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFEF4444)),
                          ),
                        ),
                        Text(
                          '-$_returnedUnits',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '= Balanced Closing Custody',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$balancedClosing units',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Inputs for Movement: Sales, Returns, Replenishment
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units Sold *',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unitsSoldCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF059669),
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildQuickChip('+1', () => _adjustField(_unitsSoldCtrl, 1), const Color(0xFF059669), isDark),
                            _buildQuickChip('+5', () => _adjustField(_unitsSoldCtrl, 5), const Color(0xFF059669), isDark),
                            _buildQuickChip('-1', () => _adjustField(_unitsSoldCtrl, -1), const Color(0xFF64748B), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Returned',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unitsReturnedCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFEF4444),
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildQuickChip('+1', () => _adjustField(_unitsReturnedCtrl, 1), const Color(0xFFEF4444), isDark),
                            _buildQuickChip('+5', () => _adjustField(_unitsReturnedCtrl, 5), const Color(0xFFEF4444), isDark),
                            _buildQuickChip('-1', () => _adjustField(_unitsReturnedCtrl, -1), const Color(0xFF64748B), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DC Restock',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _replenishedCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0284C7),
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildQuickChip('+5', () => _adjustField(_replenishedCtrl, 5), const Color(0xFF0284C7), isDark),
                            _buildQuickChip('+10', () => _adjustField(_replenishedCtrl, 10), const Color(0xFF0284C7), isDark),
                            _buildQuickChip('-5', () => _adjustField(_replenishedCtrl, -5), const Color(0xFF64748B), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ambush Stock Take / Random Audit Toggle
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _includeAmbushAudit = !_includeAmbushAudit),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _includeAmbushAudit
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _includeAmbushAudit
                          ? const Color(0xFFF59E0B)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _includeAmbushAudit ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: _includeAmbushAudit ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Random Ambush Stock-Taking (Audit Mode)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _includeAmbushAudit ? const Color(0xFFD97706) : null,
                              ),
                            ),
                            Text(
                              'Audit count must match CRM stock balance within ±5% margin',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_includeAmbushAudit) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Physical Ambush Count (Field Stock Takers) *',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _physicalAuditCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 178',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      if (variancePct != null && varianceUnits != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              exceedsThreshold ? Icons.error_rounded : Icons.check_circle_rounded,
                              size: 16,
                              color: exceedsThreshold ? const Color(0xFFEF4444) : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                exceedsThreshold
                                    ? '🚨 Discrepancy (${variancePct.toStringAsFixed(1)}%) EXCEEDS the ±5% investigation limit ($varianceUnits units).'
                                    : '✅ Count verified: ${variancePct.toStringAsFixed(1)}% variance (within acceptable ±5% threshold).',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: exceedsThreshold ? const Color(0xFFEF4444) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Notes
              Text(
                'Reconciliation Notes / Waybill Ref',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. POD delivery manifests signed, payment remittances deposited',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Action
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sync_rounded, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Post Daily Sales & Balance Custody',
                                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, Color color, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
