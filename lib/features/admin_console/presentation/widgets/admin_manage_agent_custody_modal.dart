import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

/// Modal dialog allowing operators to add, edit, update, or remove
/// product inventory quantities held in custody by an agent.
/// Requires explicit confirmation via [NovaCriticalActionConfirmationModal] before applying.
class AdminManageAgentCustodyModal extends ConsumerStatefulWidget {
  final AdminLogisticsAgent agent;
  final List<AdminGlobalStockItem> catalogProducts;

  const AdminManageAgentCustodyModal({
    super.key,
    required this.agent,
    required this.catalogProducts,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminLogisticsAgent agent,
    required List<AdminGlobalStockItem> catalogProducts,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminManageAgentCustodyModal(
        agent: agent,
        catalogProducts: catalogProducts,
      ),
    );
  }

  @override
  ConsumerState<AdminManageAgentCustodyModal> createState() =>
      _AdminManageAgentCustodyModalState();
}

class _AdminManageAgentCustodyModalState
    extends ConsumerState<AdminManageAgentCustodyModal> {
  late Map<String, int> _quantities;
  late final Map<String, int> _initialQuantities;
  final TextEditingController _reasonController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  String? _selectedNewProductSku;

  @override
  void initState() {
    super.initState();
    _quantities = {};
    _initialQuantities = {};

    // Populate from agent.heldStock, mapping to SKU where possible
    widget.agent.heldStock.forEach((key, val) {
      if (val > 0) {
        // Find matching SKU from catalog
        final matchingProd = widget.catalogProducts.firstWhere(
          (p) =>
              p.sku.toLowerCase() == key.toLowerCase() ||
              p.id.toLowerCase() == key.toLowerCase() ||
              p.productName.toLowerCase() == key.toLowerCase(),
          orElse: () => AdminGlobalStockItem(
            id: key,
            productId: key,
            productName: key,
            sku: key,
            merchantId: '',
            merchantName: 'Platform Partner',
            unitPrice: 0.0,
            totalWarehouseStock: 0,
            totalRiderCustodyStock: val,
            totalStock: val,
          ),
        );

        final canonicalSku = matchingProd.sku;
        _quantities[canonicalSku] = val;
        _initialQuantities[canonicalSku] = val;
        _controllers[canonicalSku] = TextEditingController(text: '$val');
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _currentTotalUnits =>
      _initialQuantities.values.fold<int>(0, (s, q) => s + q);
  int get _proposedTotalUnits =>
      _quantities.values.fold<int>(0, (s, q) => s + q);
  int get _deltaUnits => _proposedTotalUnits - _currentTotalUnits;

  void _updateQuantity(String sku, int newQty) {
    setState(() {
      final safeQty = newQty.clamp(0, 999999);
      if (safeQty > 0) {
        _quantities[sku] = safeQty;
        if (!_controllers.containsKey(sku)) {
          _controllers[sku] = TextEditingController(text: '$safeQty');
        } else {
          _controllers[sku]!.text = '$safeQty';
        }
      } else {
        _quantities.remove(sku);
        _controllers[sku]?.text = '0';
      }
    });
  }

  void _addProduct(String sku) {
    if (sku.isEmpty) return;
    setState(() {
      _quantities[sku] = (_quantities[sku] ?? 0) + 10;
      if (!_controllers.containsKey(sku)) {
        _controllers[sku] = TextEditingController(text: '${_quantities[sku]}');
      } else {
        _controllers[sku]!.text = '${_quantities[sku]}';
      }
      _selectedNewProductSku = null;
    });
  }

  void _removeProduct(String sku) {
    setState(() {
      _quantities.remove(sku);
      _controllers[sku]?.text = '0';
    });
  }

  Future<void> _handleConfirm() async {
    // Check if any change was made
    bool hasChanges = false;
    final allSkus = {..._initialQuantities.keys, ..._quantities.keys};
    final changesBreakdown = <String>[];

    for (final sku in allSkus) {
      final oldVal = _initialQuantities[sku] ?? 0;
      final newVal = _quantities[sku] ?? 0;
      if (oldVal != newVal) {
        hasChanges = true;
        final diff = newVal - oldVal;
        // Lookup product name
        final prod = widget.catalogProducts.firstWhere(
          (p) => p.sku == sku,
          orElse: () => AdminGlobalStockItem(
            id: sku,
            productId: sku,
            productName: sku,
            sku: sku,
            merchantId: '',
            merchantName: '',
            unitPrice: 0.0,
            totalWarehouseStock: 0,
            totalRiderCustodyStock: 0,
            totalStock: 0,
          ),
        );
        changesBreakdown.add(
            '${prod.productName} ($sku): $oldVal -> $newVal units (${diff >= 0 ? "+$diff" : "$diff"})');
      }
    }

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No custody stock modifications detected.'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    String operatorName = 'Operations Controller';
    try {
      final user = ref.read(authProvider).user;
      if (user != null && user.fullName.isNotEmpty) {
        operatorName = user.fullName;
      }
    } catch (_) {}

    // Prompt strict critical confirmation modal
    final confirmed = await NovaCriticalActionConfirmationModal.show(
      context: context,
      title: 'Confirm Agent Custody Stock Adjustment',
      actionName: 'Adjust Custody for ${widget.agent.name}',
      promptMessage:
          'You are about to adjust physical product custody for agent ${widget.agent.name} (${widget.agent.agentCode}). This action immediately recalculates multi-hub inventory balances and registers an indelible audit record.',
      valuesets: {
        'Agent Name & Code': '${widget.agent.name} (${widget.agent.agentCode})',
        'Managing DC Hub':
            widget.agent.assignedWarehouseName ?? 'Abuja Central DC',
        'Current Total Custody': '$_currentTotalUnits units',
        'Proposed New Custody': '$_proposedTotalUnits units',
        'Net Units Delta':
            '${_deltaUnits >= 0 ? "+$_deltaUnits" : "$_deltaUnits"} units',
        'Itemized SKU Adjustments': changesBreakdown.join(' | '),
        'Authorized Operator': operatorName,
      },
      operatorAccount: operatorName,
      confirmLabel: 'Confirm & Apply Stock Update',
      cancelLabel: 'Cancel / Abort',
      brandColor: const Color(0xFFF97316),
      isDestructive: _deltaUnits < 0,
    );

    if (!confirmed || !mounted) return;

    // Apply update via notifier
    await ref.read(adminConsoleProvider.notifier).updateAgentCustodyStock(
          agentId: widget.agent.id,
          newHeldStock: _quantities,
          operatorName: operatorName,
          reason: _reasonController.text.trim().isNotEmpty
              ? _reasonController.text.trim()
              : 'Direct physical custody reallocation by $operatorName',
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully updated custody stock for ${widget.agent.name}. Network inventory balanced.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Available products that can be added
    final unassignedCatalog = widget.catalogProducts
        .where((p) => !_quantities.containsKey(p.sku) || _quantities[p.sku] == 0)
        .toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Manage Agent Stock Custody',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.agent.agentCode,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.agent.name} • Hub: ${widget.agent.assignedWarehouseName ?? "Abuja Central DC"}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
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
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Metric Strip
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Custody',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_currentTotalUnits units',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Proposed Custody',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_proposedTotalUnits units',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _deltaUnits == 0
                                  ? const Color(0xFF64748B).withValues(alpha: 0.12)
                                  : (_deltaUnits > 0
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _deltaUnits == 0
                                  ? 'No Change'
                                  : (_deltaUnits > 0
                                      ? '+${_deltaUnits} units (Inbound)'
                                      : '${_deltaUnits} units (Outbound)'),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _deltaUnits == 0
                                  ? const Color(0xFF64748B)
                                  : (_deltaUnits > 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add Product Section
                    if (unassignedCatalog.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedNewProductSku,
                              isExpanded: true,
                              hint: Text('Select product from catalog to allocate...',
                                  style: GoogleFonts.inter(fontSize: 12)),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.add_box_outlined,
                                    size: 16, color: Color(0xFF10B981)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              items: unassignedCatalog.map((p) {
                                return DropdownMenuItem<String>(
                                  value: p.sku,
                                  child: Text(
                                    '${p.productName} (${p.sku}) • ${p.merchantName}',
                                    style: GoogleFonts.inter(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedNewProductSku = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add to Agent'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _selectedNewProductSku != null
                                ? () => _addProduct(_selectedNewProductSku!)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Products in Custody Table
                    Text(
                      'Products Allocated in Agent Custody',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (_quantities.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  size: 32, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                'No products currently assigned to this agent.',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a product from the dropdown above to allocate stock custody.',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quantities.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (ctx, i) {
                            final sku = _quantities.keys.elementAt(i);
                            final qty = _quantities[sku] ?? 0;
                            final initialQty = _initialQuantities[sku] ?? 0;

                            // Lookup catalog details
                            final prod = widget.catalogProducts.firstWhere(
                              (p) => p.sku == sku,
                              orElse: () => AdminGlobalStockItem(
                                id: sku,
                                productId: sku,
                                productName: sku,
                                sku: sku,
                                merchantId: '',
                                merchantName: 'Platform Partner',
                                unitPrice: 0.0,
                                totalWarehouseStock: 0,
                                totalRiderCustodyStock: 0,
                                totalStock: 0,
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      size: 18,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.productName,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'SKU: $sku • Merchant: ${prod.merchantName}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (initialQty != qty)
                                          Text(
                                            'Initial: $initialQty units -> Delta: ${qty - initialQty >= 0 ? "+${qty - initialQty}" : "${qty - initialQty}"}',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: qty >= initialQty
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Counter & Controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline,
                                            size: 20, color: Color(0xFF64748B)),
                                        tooltip: 'Decrease 10 units',
                                        onPressed: () =>
                                            _updateQuantity(sku, qty - 10),
                                      ),
                                      SizedBox(
                                        width: 75,
                                        height: 36,
                                        child: TextFormField(
                                          controller: _controllers[sku],
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 6),
                                            filled: true,
                                            fillColor: isDark
                                                ? const Color(0xFF0F172A)
                                                : Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            final parsed = int.tryParse(val) ?? 0;
                                            _updateQuantity(sku, parsed);
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline,
                                            size: 20, color: Color(0xFF0284C7)),
                                        tooltip: 'Increase 10 units',
                                        onPressed: () =>
                                            _updateQuantity(sku, qty + 10),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            size: 20, color: Color(0xFFEF4444)),
                                        tooltip: 'Remove product from custody',
                                        onPressed: () => _removeProduct(sku),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Audit / Operational Reason Input
                    Text(
                      'Operational Change Note (Mandatory for Audit Trail)',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Physical stock replenishment to agent vehicle / Stock balance audit...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Confirm & Apply Custody Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleConfirm,
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
