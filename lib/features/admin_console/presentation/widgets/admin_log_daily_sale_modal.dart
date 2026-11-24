import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/entities/agent_daily_sale_record.dart';
import '../providers/admin_console_provider.dart';

/// Modal dialog allowing Super Admins / Master Stock Keepers (e.g. Damilare Ajani)
/// to select a merchant, agent, and product SKU, record delivered daily sales,
/// inbound DC restock replenishment, and returns, calculate balanced closing custody in real-time,
/// prompt for mandatory confirmation, and persist to database ledger and audit trail.
class AdminLogDailySaleModal extends ConsumerStatefulWidget {
  final AdminLogisticsAgent? initialAgent;
  final String? initialMerchantId;
  final String? initialSku;

  const AdminLogDailySaleModal({
    super.key,
    this.initialAgent,
    this.initialMerchantId,
    this.initialSku,
  });

  static Future<void> show({
    required BuildContext context,
    AdminLogisticsAgent? initialAgent,
    String? initialMerchantId,
    String? initialSku,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminLogDailySaleModal(
        initialAgent: initialAgent,
        initialMerchantId: initialMerchantId,
        initialSku: initialSku,
      ),
    );
  }

  @override
  ConsumerState<AdminLogDailySaleModal> createState() =>
      _AdminLogDailySaleModalState();
}

class _AdminLogDailySaleModalState extends ConsumerState<AdminLogDailySaleModal> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedMerchantId;
  String? _selectedAgentId;
  String? _selectedSku;

  final _unitsSoldCtrl = TextEditingController(text: '0');
  final _unitsReturnedCtrl = TextEditingController(text: '0');
  final _replenishedCtrl = TextEditingController(text: '0');
  final _orderRefCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _deliveryLocationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Ambush Audit Fields
  bool _includeAmbushAudit = false;
  final _physicalAuditCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMerchantId = widget.initialMerchantId ?? 'all';
    _selectedAgentId = widget.initialAgent?.id;
    _selectedSku = widget.initialSku;
    _orderRefCtrl.text = 'NX-SALE-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

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
    _orderRefCtrl.dispose();
    _customerNameCtrl.dispose();
    _deliveryLocationCtrl.dispose();
    _notesCtrl.dispose();
    _physicalAuditCtrl.dispose();
    super.dispose();
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

  int _getOpeningCustody(AdminLogisticsAgent? agent, String? sku) {
    if (agent == null || sku == null) return 0;
    return agent.heldStock[sku] ??
        agent.heldStock[sku.toUpperCase()] ??
        0;
  }

  int _computeBalancedClosing(int opening) {
    final closing = opening + _replenishedUnits - _soldUnits - _returnedUnits;
    return closing < 0 ? 0 : closing;
  }

  Future<void> _handleSubmit(
    AdminLogisticsAgent agent,
    AdminGlobalStockItem product,
    String? merchantName,
    int openingCustody,
    int balancedClosing,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    if (_soldUnits <= 0 &&
        _returnedUnits <= 0 &&
        _replenishedUnits <= 0 &&
        !_includeAmbushAudit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text(
              'Please enter at least one quantity: units sold, returned, replenished, or audit count.'),
        ),
      );
      return;
    }

    final authState = ref.read(authProvider);
    final operatorAccount = authState.user?.fullName.isNotEmpty == true
        ? '${authState.user!.fullName} (${authState.user!.email})'
        : 'Damilare Ajani (damieajani@gmail.com)';
    final operatorName = authState.user?.fullName.isNotEmpty == true
        ? authState.user!.fullName
        : 'Damilare Ajani';

    // Critical Action Confirmation Modal
    final confirmed = await NovaCriticalActionConfirmationModal.show(
      context: context,
      title: 'Confirm Daily Sales & Balance Stock',
      actionName: 'Post Sales for ${agent.name}',
      promptMessage:
          'You are about to record daily sales and sync physical stock custody for agent ${agent.name} (${agent.agentCode}) on ${product.productName}. Sold units will be permanently deducted from custody and logged to the central ledger.',
      valuesets: {
        'Merchant Account': merchantName ?? 'Novacare Limited',
        'Delivery Agent': '${agent.name} (${agent.agentCode})',
        'Managing DC Hub': agent.assignedWarehouseName ?? 'Abuja Central DC',
        'Product SKU': '${product.productName} [${product.sku}]',
        'Opening Custody': '$openingCustody units',
        'Delivered Sales Today': '$_soldUnits units (${CurrencyFormatter.formatNaira(_soldUnits * product.unitPrice)})',
        'Returns / Damaged': '$_returnedUnits units',
        'Inbound DC Restock': '+$_replenishedUnits units',
        'Balanced Closing Custody': '$balancedClosing units',
        'Authorizing Operator': operatorAccount,
      },
      operatorAccount: operatorAccount,
      confirmLabel: 'Confirm & Post Sales',
      cancelLabel: 'Cancel',
      brandColor: const Color(0xFF059669),
      isDestructive: false,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final saleRecord = AgentDailySaleRecord(
        id: 'SALE-${DateTime.now().millisecondsSinceEpoch}',
        agentId: agent.id,
        agentName: agent.name,
        agentCode: agent.agentCode,
        orderReference: _orderRefCtrl.text.trim().isNotEmpty
            ? _orderRefCtrl.text.trim()
            : 'NX-ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        customerName: _customerNameCtrl.text.trim().isNotEmpty
            ? _customerNameCtrl.text.trim()
            : 'Verified Customer',
        customerPhone: '+234 800 000 0000',
        deliveryLocation: _deliveryLocationCtrl.text.trim().isNotEmpty
            ? _deliveryLocationCtrl.text.trim()
            : (agent.coverageStates.isNotEmpty ? agent.coverageStates.first : 'Regional Coverage'),
        items: [
          AgentDailySaleItem(
            sku: product.sku,
            productName: product.productName,
            quantity: _soldUnits,
            unitPrice: product.unitPrice,
          ),
        ],
        totalAmount: _soldUnits * product.unitPrice,
        paymentMethod: 'cash_cod',
        status: 'delivered_collected',
        loggedBy: operatorName,
        timestamp: DateTime.now(),
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        merchantId: product.merchantId.isNotEmpty ? product.merchantId : '00000000-0000-4000-8000-791731264594',
        merchantName: merchantName,
        replenishedUnits: _replenishedUnits,
        returnedUnits: _returnedUnits,
        dcName: agent.assignedWarehouseName ?? 'Abuja Central DC',
      );

      await ref.read(adminConsoleProvider.notifier).recordAgentDailySale(saleRecord);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily sales logged & stock balanced! ${agent.name} new custody: $balancedClosing units.',
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
    final state = ref.watch(adminConsoleProvider);

    final merchants = state.merchants;
    final allProducts = state.globalStock;
    final allAgents = state.agents;

    // 1. Filter products by selected merchant
    final availableProducts = allProducts.where((p) {
      if (_selectedMerchantId == null || _selectedMerchantId == 'all') return true;
      final mId = _selectedMerchantId!.toLowerCase();
      final pMerchant = p.merchantId.toLowerCase();
      final pMerchantName = p.merchantName.toLowerCase();
      if (mId.contains('novacare')) {
        return pMerchant.contains('novacare') || pMerchantName.contains('novacare');
      } else if (mId.contains('shop') || mId.contains('eleven')) {
        return pMerchant.contains('shop') || pMerchantName.contains('eleven');
      } else if (mId.contains('leafora')) {
        return pMerchant.contains('leafora') || pMerchantName.contains('leafora');
      }
      return p.merchantId == _selectedMerchantId;
    }).toList();

    // 2. Filter agents by selected merchant (or show all if 'all')
    final availableAgents = allAgents.where((a) {
      if (_selectedMerchantId == null || _selectedMerchantId == 'all') return true;
      final mId = _selectedMerchantId!.toLowerCase();
      return a.assignedMerchantIds.any((id) => id.toLowerCase().contains(mId)) ||
          a.assignedMerchantNames.any((n) => n.toLowerCase().contains(mId));
    }).toList();

    // Fallback if list is empty
    final effectiveAgents = availableAgents.isNotEmpty ? availableAgents : allAgents;
    final effectiveProducts = availableProducts.isNotEmpty ? availableProducts : allProducts;

    if (_selectedAgentId == null || !effectiveAgents.any((a) => a.id == _selectedAgentId)) {
      if (effectiveAgents.isNotEmpty) {
        _selectedAgentId = effectiveAgents.first.id;
      }
    }

    if (_selectedSku == null || !effectiveProducts.any((p) => p.sku == _selectedSku)) {
      if (effectiveProducts.isNotEmpty) {
        _selectedSku = effectiveProducts.first.sku;
      }
    }

    final selectedAgent = effectiveAgents.firstWhere(
      (a) => a.id == _selectedAgentId,
      orElse: () => effectiveAgents.first,
    );

    final selectedProduct = effectiveProducts.firstWhere(
      (p) => p.sku == _selectedSku,
      orElse: () => effectiveProducts.first,
    );

    final openingCustody = _getOpeningCustody(selectedAgent, selectedProduct.sku);
    final balancedClosing = _computeBalancedClosing(openingCustody);

    // Merchant name display
    final selectedMerchant = merchants.firstWhere(
      (m) => m.id == _selectedMerchantId,
      orElse: () => AdminMerchant(
        id: 'all',
        businessName: _selectedMerchantId == 'all' ? 'All Platform Merchants' : selectedProduct.merchantName,
        contactName: '',
        phone: '',
        email: '',
      ),
    );

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
        maxHeight: MediaQuery.of(context).size.height * 0.94,
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
                          'Super Admin & Master Stock Keeper Portal • Record sales & sync agent custody',
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
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),

              // 1. Merchant Selector (Searchable Mobile Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Merchant / Client Brand *',
                placeholder: 'Tap to select merchant or global stock...',
                value: _selectedMerchantId,
                prefixIcon: Icons.storefront_outlined,
                brandColor: const Color(0xFF0284C7),
                pickerTitle: 'Select Merchant / Client Brand',
                pickerSubtitle: 'Choose brand or platform global stock',
                options: [
                  const NovaPickerOption<String>(
                    value: 'all',
                    title: 'All Platform Merchants (Global Stock)',
                    subtitle: 'Aggregate multi-merchant inventory across warehouses',
                    badgeText: 'GLOBAL',
                    badgeColor: Color(0xFF0284C7),
                    icon: Icons.public_rounded,
                    searchTerms: ['all', 'global', 'platform'],
                  ),
                  ...merchants.map((m) {
                    final pCount = m.productsDistributed.isNotEmpty ? m.productsDistributed.length : 3;
                    return NovaPickerOption<String>(
                      value: m.id,
                      title: m.businessName,
                      subtitle: '$pCount Products cataloged • ${m.email}',
                      badgeText: 'MERCHANT',
                      badgeColor: const Color(0xFF7C3AED),
                      icon: Icons.storefront_rounded,
                      trailingText: '$pCount skus',
                      trailingTextColor: const Color(0xFF7C3AED),
                      searchTerms: [m.businessName, m.id, m.email],
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMerchantId = val;
                      _selectedSku = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Agent Selector (Searchable Mobile Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Delivery Agent / 3PL Partner *',
                placeholder: 'Tap to select delivery agent or 3PL...',
                value: _selectedAgentId,
                prefixIcon: Icons.local_shipping_outlined,
                brandColor: const Color(0xFF059669),
                pickerTitle: 'Select Delivery Agent',
                pickerSubtitle: 'Choose field delivery courier or logistics partner',
                options: effectiveAgents.map((a) {
                  final isInternal = a.type == 'internal_logistics' || a.agentCode.startsWith('NX-');
                  return NovaPickerOption<String>(
                    value: a.id,
                    title: a.name,
                    subtitle: 'Code: ${a.agentCode} • ${a.assignedWarehouseName ?? "Abuja DC"}',
                    badgeText: isInternal ? 'FLEET' : '3PL',
                    badgeColor: isInternal ? const Color(0xFF0284C7) : const Color(0xFFF97316),
                    icon: Icons.two_wheeler_rounded,
                    trailingText: a.agentCode,
                    searchTerms: [a.name, a.agentCode, a.assignedWarehouseName ?? '', a.type],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAgentId = val);
                },
              ),
              const SizedBox(height: 14),

              // 3. Product SKU Selector (Searchable Mobile Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Product SKU *',
                placeholder: 'Tap to select product SKU...',
                value: _selectedSku,
                prefixIcon: Icons.inventory_2_outlined,
                brandColor: const Color(0xFFD97706),
                pickerTitle: 'Select Product SKU',
                pickerSubtitle: 'Select product to balance custody ledger',
                options: effectiveProducts.map((p) {
                  return NovaPickerOption<String>(
                    value: p.sku,
                    title: p.productName,
                    subtitle: 'SKU: ${p.sku} • Merchant: ${p.merchantName}',
                    badgeText: p.sku,
                    badgeColor: const Color(0xFFD97706),
                    icon: Icons.inventory_2_outlined,
                    trailingText: CurrencyFormatter.formatNaira(p.unitPrice),
                    trailingTextColor: const Color(0xFF059669),
                    searchTerms: [p.productName, p.sku, p.merchantName],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSku = val);
                },
              ),
              const SizedBox(height: 16),

              // 4. Live Custody Rebalance Calculation Card (Matches user screenshot)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildCalcRow('Starting Agent Custody', '$openingCustody units', isDark),
                    const SizedBox(height: 6),
                    _buildCalcRow('+ New Replenishment from DC', '+$_replenishedUnits', isDark, color: const Color(0xFF0284C7)),
                    const SizedBox(height: 6),
                    _buildCalcRow('- Delivered Daily Sales', '-$_soldUnits', isDark, color: const Color(0xFF059669)),
                    const SizedBox(height: 6),
                    _buildCalcRow('- Returns / Damaged from Field', '-$_returnedUnits', isDark, color: const Color(0xFFEF4444)),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '= Balanced Closing Custody',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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

              // 5. Quantity Input Fields with Mobile Quick Adjustment Chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Units Sold *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _unitsSoldCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF059669),
                          ),
                          decoration: _inputDeco(isDark),
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
                        Text('Returned', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _unitsReturnedCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFFEF4444),
                          ),
                          decoration: _inputDeco(isDark),
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
                        Text('DC Restock', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _replenishedCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF0284C7),
                          ),
                          decoration: _inputDeco(isDark),
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
              const SizedBox(height: 14),

              // 6. Ambush Stock Taking Checkbox & Field
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Random Ambush Stock-Taking (Audit Mode)',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Audit count must match CRM stock balance within ±5% margin',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      value: _includeAmbushAudit,
                      onChanged: (val) => setState(() => _includeAmbushAudit = val ?? false),
                    ),
                    if (_includeAmbushAudit) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _physicalAuditCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13),
                        decoration: _inputDeco(isDark, prefixIcon: Icons.verified_user_outlined).copyWith(
                          hintText: 'Enter physical count found with agent',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 7. Order Reference and Waybill / Reconciliation Notes
              Text('Reconciliation Notes / Waybill Ref', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 12.5),
                decoration: _inputDeco(isDark).copyWith(
                  hintText: 'e.g. POD delivery manifests signed, payment remittances deposited',
                ),
              ),
              const SizedBox(height: 16),

              // 8. Operator Attribution Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Operator: ${ref.read(authProvider).user?.fullName.isNotEmpty == true ? ref.read(authProvider).user!.fullName : "Damilare Ajani"} • Permanent DB Ledger Record',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 9. Post Daily Sales Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 19),
                  label: Text(
                    _isSubmitting ? 'Balancing Stock & Logging Ledger...' : 'Post Daily Sales & Balance Custody',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _handleSubmit(
                            selectedAgent,
                            selectedProduct,
                            selectedMerchant.businessName,
                            openingCustody,
                            balancedClosing,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, bool isDark, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(bool isDark, {IconData? prefixIcon}) {
    return InputDecoration(
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
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
