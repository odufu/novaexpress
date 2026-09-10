import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/client_portal_provider.dart';

class ClientSupplyStockModal extends ConsumerStatefulWidget {
  final CatalogProduct product;

  const ClientSupplyStockModal({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, CatalogProduct product) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientSupplyStockModal(product: product),
    );
  }

  @override
  ConsumerState<ClientSupplyStockModal> createState() => _ClientSupplyStockModalState();
}

class _ClientSupplyStockModalState extends ConsumerState<ClientSupplyStockModal> {
  final _formKey = GlobalKey<FormState>();
  final _totalUnitsCtrl = TextEditingController(text: '100');
  final _waybillCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isEqualSplit = true;
  final Map<String, TextEditingController> _dcControllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final randomSuffix = (1000 + math.Random().nextInt(9000)).toString();
    _waybillCtrl.text = 'CONSIGN-${widget.product.sku}-$randomSuffix';
  }

  @override
  void dispose() {
    _totalUnitsCtrl.dispose();
    _waybillCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _dcControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _stateMatches(String dcState, String targetState) {
    final cleanDc = dcState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanTarget = targetState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanDc.isEmpty || cleanTarget.isEmpty) return false;
    if (cleanDc == cleanTarget) return true;
    if (cleanDc.contains(cleanTarget) || cleanTarget.contains(cleanDc)) return true;
    if ((cleanDc.contains('abuja') || cleanDc.contains('fct')) &&
        (cleanTarget.contains('abuja') || cleanTarget.contains('fct'))) {
      return true;
    }
    return false;
  }

  List<DistributionCenter> _getCoveredDcs(List<DistributionCenter> allDcs) {
    if (widget.product.coveringStates.isEmpty) {
      return allDcs;
    }
    final matched = allDcs.where((dc) {
      return widget.product.coveringStates.any((st) => _stateMatches(dc.state, st));
    }).toList();
    return matched.isNotEmpty ? matched : allDcs;
  }

  void _recalculateEqualSplit(List<DistributionCenter> dcs) {
    if (!_isEqualSplit || dcs.isEmpty) return;
    final total = int.tryParse(_totalUnitsCtrl.text.trim()) ?? 0;
    final perDc = (total / dcs.length).floor();
    var remainder = total - (perDc * dcs.length);

    for (var i = 0; i < dcs.length; i++) {
      final dcId = dcs[i].id;
      final ctrl = _dcControllers.putIfAbsent(dcId, () => TextEditingController());
      final alloc = perDc + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      ctrl.text = alloc.toString();
    }
  }

  Map<String, int> _getAllocations(List<DistributionCenter> dcs) {
    final map = <String, int>{};
    for (final dc in dcs) {
      final ctrl = _dcControllers[dc.id];
      final val = int.tryParse(ctrl?.text.trim() ?? '') ?? 0;
      if (val > 0) {
        map[dc.id] = val;
      }
    }
    return map;
  }

  int _computeSumAllocated(List<DistributionCenter> dcs) {
    int sum = 0;
    for (final dc in dcs) {
      final ctrl = _dcControllers[dc.id];
      sum += int.tryParse(ctrl?.text.trim() ?? '') ?? 0;
    }
    return sum;
  }

  Future<void> _handleSubmit(List<DistributionCenter> dcs) async {
    if (!_formKey.currentState!.validate()) return;

    final allocations = _getAllocations(dcs);
    final totalAllocated = allocations.values.fold(0, (a, b) => a + b);

    if (totalAllocated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please allocate at least 1 unit to a distribution hub.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(clientPortalProvider.notifier).supplyProductStock(
        productId: widget.product.id,
        sku: widget.product.sku,
        productName: widget.product.name,
        dcAllocations: allocations,
        waybillNumber: _waybillCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Consignment of $totalAllocated units supplied to NovaExpress! Allocated to ${allocations.length} covering distribution hubs.',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
          content: Text('Stock supply error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);

    final allDcs = dcState.distributionCenters.isNotEmpty
        ? dcState.distributionCenters
        : defaultDistributionCenters;
    final coveredDcs = _getCoveredDcs(allDcs);

    // Initialize controllers
    for (final dc in coveredDcs) {
      _dcControllers.putIfAbsent(dc.id, () => TextEditingController(text: '0'));
    }

    if (_isEqualSplit) {
      _recalculateEqualSplit(coveredDcs);
    }

    final sumAllocated = _computeSumAllocated(coveredDcs);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF10172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
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
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supply Stock to NovaExpress',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Send inbound physical units to distribution centers covering your product',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFF37021), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.product.name,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: ${widget.product.sku} • Retail: ₦${widget.product.defaultUnitPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.product.totalStockAcrossHubs > 0
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.product.totalStockAcrossHubs > 0
                                    ? '${widget.product.totalStockAcrossHubs} Units Available'
                                    : 'Awaiting Initial Supply (0)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: widget.product.totalStockAcrossHubs > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Covering States Chips
                      if (widget.product.coveringStates.isNotEmpty) ...[
                        Text(
                          'Designated Covering States:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.product.coveringStates.map((st) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                st,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Consignment Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Physical Units to Supply *',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _totalUnitsCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 500',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (v) {
                                    final val = int.tryParse(v?.trim() ?? '');
                                    if (val == null || val <= 0) return 'Enter a valid quantity';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Waybill / Batch Reference *',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _waybillCtrl,
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'CONSIGN-001',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Waybill required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Distribution Mode Selector
                      Row(
                        children: [
                          Text(
                            'Distribution Allocation Mode:',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                          const Spacer(),
                          ChoiceChip(
                            label: Text('Equal Split', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            selected: _isEqualSplit,
                            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isEqualSplit = true;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Custom Allocation', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            selected: !_isEqualSplit,
                            selectedColor: const Color(0xFFF37021).withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isEqualSplit = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hub Allocation List
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Covering Distribution Hubs (${coveredDcs.length})',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Total to Dispatch: $sumAllocated Units',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...coveredDcs.map((dc) {
                              final ctrl = _dcControllers[dc.id];
                              // Find existing units in this DC from stock state
                              final existingItem = stockState.stockItems.where((i) => i.sku.toUpperCase() == widget.product.sku.toUpperCase()).firstOrNull;
                              final existingUnits = existingItem?.availableCount ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dc.name,
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            '${dc.city}, ${dc.state} • Current shelf stock: $existingUnits units',
                                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        controller: ctrl,
                                        enabled: !_isEqualSplit,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        onChanged: (_) => setState(() {}),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          suffixText: 'pcs',
                                          suffixStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      Text(
                        'Dispatch / Delivery Notes (Optional)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g. Dispatched via interstate transit from central factory, expected arrival Friday...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : () => _handleSubmit(coveredDcs),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Supplying to Hubs...' : 'Confirm & Supply to NovaExpress',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
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
