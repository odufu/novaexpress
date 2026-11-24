import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

/// Modal dialog allowing NovaXpress Master Stock Keeper (Damilare Ajani)
/// to allocate warehouse shelf inventory directly to an agent (including NovaXpress Logistics).
class AdminAllocateToAgentModal extends ConsumerStatefulWidget {
  final AdminLogisticsAgent? initialAgent;
  final String? initialSku;
  final String? initialWarehouse;

  const AdminAllocateToAgentModal({
    super.key,
    this.initialAgent,
    this.initialSku,
    this.initialWarehouse,
  });

  static Future<void> show({
    required BuildContext context,
    AdminLogisticsAgent? initialAgent,
    String? initialSku,
    String? initialWarehouse,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminAllocateToAgentModal(
        initialAgent: initialAgent,
        initialSku: initialSku,
        initialWarehouse: initialWarehouse,
      ),
    );
  }

  @override
  ConsumerState<AdminAllocateToAgentModal> createState() =>
      _AdminAllocateToAgentModalState();
}

class _AdminAllocateToAgentModalState
    extends ConsumerState<AdminAllocateToAgentModal> {
  final _formKey = GlobalKey<FormState>();
  final _unitsController = TextEditingController(text: '50');
  final _notesController = TextEditingController();

  AdminLogisticsAgent? _selectedAgent;
  String? _selectedSku;
  String _selectedWarehouse = 'Abuja Central DC';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedAgent = widget.initialAgent;
    _selectedSku = widget.initialSku;
    if (widget.initialWarehouse != null && widget.initialWarehouse!.isNotEmpty) {
      _selectedWarehouse = widget.initialWarehouse!;
    }
  }

  @override
  void dispose() {
    _unitsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final operatorName = currentUser?.fullName.isNotEmpty == true
        ? currentUser!.fullName
        : 'Damilare Ajani';

    // Auto-select agent if not set
    if (_selectedAgent == null && state.agents.isNotEmpty) {
      final nxFleet = state.agents.cast<AdminLogisticsAgent?>().firstWhere(
            (a) => a?.agentCode == 'NX-ABJ-01' || a?.id == 'agent-novaxpress-logistics',
            orElse: () => state.agents.first,
          );
      _selectedAgent = nxFleet;
    }

    // Auto-select SKU if not set
    if (_selectedSku == null && state.globalStock.isNotEmpty) {
      _selectedSku = state.globalStock.first.sku;
    }

    // Find current product
    final currentProduct = state.globalStock.cast<AdminGlobalStockItem?>().firstWhere(
          (p) => p?.sku.toLowerCase() == _selectedSku?.toLowerCase(),
          orElse: () => null,
        );

    final availableShelfStock = currentProduct != null
        ? (currentProduct.dcStockBreakdown[_selectedWarehouse] ?? currentProduct.totalWarehouseStock)
        : 0;

    final targetAgentCurrentQty = _selectedAgent != null && _selectedSku != null
        ? (_selectedAgent!.heldStock[_selectedSku!] ?? 0)
        : 0;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Color(0xFF0D9488),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allocate Stock to Agent',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Move inventory from DC shelves to agent custody ledger',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
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
              const SizedBox(height: 20),

              // Source Warehouse Picker
              Text(
                'Source Distribution Center / Warehouse *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final dcs = ['Abuja Central DC', 'Lagos Grand Hub'];
                  final picked = await NovaSearchablePickerModal.show<String>(
                    context,
                    title: 'Select Source DC',
                    subtitle: 'Choose warehouse holding source inventory',
                    titleIcon: Icons.warehouse_rounded,
                    options: dcs
                        .map((dc) => NovaPickerOption<String>(
                              value: dc,
                              title: dc,
                              subtitle: 'Active Regional Fulfillment Hub',
                              icon: Icons.storefront_rounded,
                            ))
                        .toList(),
                    selectedValue: _selectedWarehouse,
                  );
                  if (picked != null) {
                    setState(() => _selectedWarehouse = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warehouse_rounded, size: 20, color: Color(0xFF0D9488)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedWarehouse,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Destination Agent Picker
              Text(
                'Destination Delivery Agent / Fleet *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await NovaSearchablePickerModal.show<AdminLogisticsAgent>(
                    context,
                    title: 'Select Destination Agent',
                    subtitle: 'Choose agent or fleet receiving physical stock',
                    titleIcon: Icons.local_shipping_rounded,
                    options: state.agents
                        .map((a) => NovaPickerOption<AdminLogisticsAgent>(
                              value: a,
                              title: '${a.name} (${a.agentCode})',
                              subtitle: '${a.type == "internal_logistics" ? "Internal Fleet" : "3PL Partner"} • ${a.coverageStates.join(", ")}',
                              badgeText: a.agentCode == 'NX-ABJ-01' ? 'INTERNAL FLEET' : '3PL AGENT',
                              badgeColor: a.agentCode == 'NX-ABJ-01' ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
                              icon: a.agentCode == 'NX-ABJ-01' ? Icons.electric_moped_rounded : Icons.local_shipping_rounded,
                            ))
                        .toList(),
                    selectedValue: _selectedAgent,
                  );
                  if (picked != null) {
                    setState(() => _selectedAgent = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedAgent?.agentCode == 'NX-ABJ-01'
                            ? Icons.electric_moped_rounded
                            : Icons.local_shipping_rounded,
                        size: 20,
                        color: const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedAgent != null
                              ? '${_selectedAgent!.name} (${_selectedAgent!.agentCode})'
                              : 'Select receiving agent...',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Product SKU Picker
              Text(
                'Product SKU *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await NovaSearchablePickerModal.show<String>(
                    context,
                    title: 'Select Product SKU',
                    subtitle: 'Choose inventory item to allocate',
                    titleIcon: Icons.inventory_2_rounded,
                    options: state.globalStock
                        .map((p) => NovaPickerOption<String>(
                              value: p.sku,
                              title: p.productName,
                              subtitle: '${p.sku} • Merchant: ${p.merchantName}',
                              trailingText: '${p.totalWarehouseStock} in DC',
                              icon: Icons.check_circle_outline_rounded,
                            ))
                        .toList(),
                    selectedValue: _selectedSku,
                  );
                  if (picked != null) {
                    setState(() => _selectedSku = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFF0D9488)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProduct?.productName ?? _selectedSku ?? 'Select Product...',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            if (currentProduct != null)
                              Text(
                                '${currentProduct.sku} • ${currentProduct.merchantName}',
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quantity Input & Math Balancer Preview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDFA),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available on DC Shelf:',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        Text(
                          '$availableShelfStock units',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: availableShelfStock > 0 ? const Color(0xFF0D9488) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Agent Custody:',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        Text(
                          '$targetAgentCurrentQty units',
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Units to Allocate *',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _unitsController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (val) {
                              final n = int.tryParse(val?.trim() ?? '');
                              if (n == null || n <= 0) return 'Must be > 0';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Waybill / Reference Notes
              Text(
                'Waybill / Requisition Reference Notes',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'e.g. Inbound Waybill #WB-2026-901 / Abuja DC stock dispatch',
                  hintStyle: GoogleFonts.inter(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (!_formKey.currentState!.validate()) return;
                          if (_selectedAgent == null || _selectedSku == null) return;

                          final units = int.tryParse(_unitsController.text.trim()) ?? 0;
                          if (units <= 0) return;

                          // Prompt mandatory confirmation modal
                          final approved = await NovaCriticalActionConfirmationModal.show(
                            context: context,
                            title: 'Confirm Warehouse Stock Allocation',
                            actionName: 'Stock Replenishment to Agent',
                            promptMessage:
                                'You are about to transfer physical inventory from warehouse shelves to agent custody. Both stock balances and ledger records will be updated immediately.',
                            operatorAccount: operatorName,
                            valuesets: {
                              'Source Warehouse': _selectedWarehouse,
                              'Destination Agent': '${_selectedAgent!.name} (${_selectedAgent!.agentCode})',
                              'Product SKU': _selectedSku!,
                              'Units to Allocate': '$units units',
                              'Resulting Agent Custody': '${targetAgentCurrentQty + units} units',
                              'Authorized By': operatorName,
                            },
                            confirmLabel: 'Confirm & Allocate Stock',
                            brandColor: const Color(0xFF0D9488),
                          );

                          if (approved != true || !mounted) return;

                          setState(() => _isSubmitting = true);
                          try {
                            final ok = await notifier.allocateStockFromWarehouseToAgent(
                              agentId: _selectedAgent!.id,
                              sku: _selectedSku!,
                              units: units,
                              operatorName: operatorName,
                              sourceDcName: _selectedWarehouse,
                              notes: _notesController.text.trim(),
                            );

                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              if (ok) {
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF0D9488),
                                    content: Text(
                                      'Successfully allocated $units units of $_selectedSku to ${_selectedAgent!.name}!',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFFDC2626),
                                    content: Text('Allocation failed. Please check quantities.'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFDC2626),
                                  content: Text('Error: $e'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSubmitting ? 'Allocating Inventory...' : 'Allocate Stock to Agent',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
