import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

/// Modal dialog allowing NovaXpress Master Stock Keeper (Damilare Ajani)
/// to transfer and re-allocate stock directly between agents (e.g. from 3PL partner to NovaXpress Logistics).
class AdminReallocateBetweenAgentsModal extends ConsumerStatefulWidget {
  final AdminLogisticsAgent? initialSourceAgent;
  final AdminLogisticsAgent? initialDestinationAgent;
  final String? initialSku;

  const AdminReallocateBetweenAgentsModal({
    super.key,
    this.initialSourceAgent,
    this.initialDestinationAgent,
    this.initialSku,
  });

  static Future<void> show({
    required BuildContext context,
    AdminLogisticsAgent? initialSourceAgent,
    AdminLogisticsAgent? initialDestinationAgent,
    String? initialSku,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminReallocateBetweenAgentsModal(
        initialSourceAgent: initialSourceAgent,
        initialDestinationAgent: initialDestinationAgent,
        initialSku: initialSku,
      ),
    );
  }

  @override
  ConsumerState<AdminReallocateBetweenAgentsModal> createState() =>
      _AdminReallocateBetweenAgentsModalState();
}

class _AdminReallocateBetweenAgentsModalState
    extends ConsumerState<AdminReallocateBetweenAgentsModal> {
  final _formKey = GlobalKey<FormState>();
  final _unitsController = TextEditingController(text: '20');
  final _reasonController =
      TextEditingController(text: 'Inter-agent territory inventory rebalancing');

  AdminLogisticsAgent? _sourceAgent;
  AdminLogisticsAgent? _destinationAgent;
  String? _selectedSku;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _sourceAgent = widget.initialSourceAgent;
    _destinationAgent = widget.initialDestinationAgent;
    _selectedSku = widget.initialSku;
  }

  @override
  void dispose() {
    _unitsController.dispose();
    _reasonController.dispose();
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

    // Source agents with positive stock
    final agentsWithStock = state.agents.where((a) => a.heldStock.values.any((q) => q > 0)).toList();

    // Auto-select source agent if not set
    if (_sourceAgent == null && agentsWithStock.isNotEmpty) {
      _sourceAgent = agentsWithStock.first;
    }

    // Auto-select destination agent if not set (default to NovaXpress Logistics if possible)
    if (_destinationAgent == null && state.agents.isNotEmpty) {
      final nxFleet = state.agents.cast<AdminLogisticsAgent?>().firstWhere(
            (a) => (a?.agentCode == 'NX-ABJ-01' || a?.id == 'agent-novaxpress-logistics') && a?.id != _sourceAgent?.id,
            orElse: () => state.agents.cast<AdminLogisticsAgent?>().firstWhere(
                  (a) => a?.id != _sourceAgent?.id,
                  orElse: () => null,
                ),
          );
      _destinationAgent = nxFleet;
    }

    // Available SKUs held by source agent
    final sourceAvailableSkus = _sourceAgent?.heldStock.keys.toList() ?? [];
    if (_selectedSku == null && sourceAvailableSkus.isNotEmpty) {
      _selectedSku = sourceAvailableSkus.first;
    } else if (_selectedSku != null && !sourceAvailableSkus.contains(_selectedSku) && sourceAvailableSkus.isNotEmpty) {
      _selectedSku = sourceAvailableSkus.first;
    }

    final sourceCurrentQty = _sourceAgent != null && _selectedSku != null
        ? (_sourceAgent!.heldStock[_selectedSku!] ?? 0)
        : 0;

    final destCurrentQty = _destinationAgent != null && _selectedSku != null
        ? (_destinationAgent!.heldStock[_selectedSku!] ?? 0)
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Re-allocate Stock Between Agents',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transfer custody units directly from one partner agent to another',
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

              // Source Agent Picker
              Text(
                'Source Agent (Transferring Custody From) *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await NovaSearchablePickerModal.show<AdminLogisticsAgent>(
                    context,
                    title: 'Select Source Agent',
                    subtitle: 'Choose agent with available stock to transfer',
                    titleIcon: Icons.upload_rounded,
                    options: agentsWithStock
                        .map((a) => NovaPickerOption<AdminLogisticsAgent>(
                              value: a,
                              title: '${a.name} (${a.agentCode})',
                              subtitle: 'Holding ${a.heldStock.values.fold(0, (sum, v) => sum + v)} total units',
                              badgeText: '${a.heldStock.length} SKUs',
                              badgeColor: const Color(0xFF3B82F6),
                              icon: Icons.storefront_rounded,
                            ))
                        .toList(),
                    selectedValue: _sourceAgent,
                  );
                  if (picked != null) {
                    setState(() {
                      _sourceAgent = picked;
                      if (_sourceAgent?.heldStock.keys.isNotEmpty == true) {
                        _selectedSku = _sourceAgent!.heldStock.keys.first;
                      }
                    });
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
                      const Icon(Icons.outbox_rounded, size: 20, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _sourceAgent != null
                              ? '${_sourceAgent!.name} (${_sourceAgent!.agentCode})'
                              : 'Select source agent...',
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
                'Destination Agent (Receiving Custody) *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final candidateDestAgents = state.agents.where((a) => a.id != _sourceAgent?.id).toList();
                  final picked = await NovaSearchablePickerModal.show<AdminLogisticsAgent>(
                    context,
                    title: 'Select Destination Agent',
                    subtitle: 'Choose agent receiving inventory (e.g. NovaXpress Logistics)',
                    titleIcon: Icons.download_rounded,
                    options: candidateDestAgents
                        .map((a) => NovaPickerOption<AdminLogisticsAgent>(
                              value: a,
                              title: '${a.name} (${a.agentCode})',
                              subtitle: '${a.type == "internal_logistics" ? "Internal Fleet" : "3PL Partner"} • ${a.coverageStates.join(", ")}',
                              badgeText: a.agentCode == 'NX-ABJ-01' ? 'INTERNAL FLEET' : '3PL AGENT',
                              badgeColor: a.agentCode == 'NX-ABJ-01' ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
                              icon: a.agentCode == 'NX-ABJ-01' ? Icons.electric_moped_rounded : Icons.local_shipping_rounded,
                            ))
                        .toList(),
                    selectedValue: _destinationAgent,
                  );
                  if (picked != null) {
                    setState(() => _destinationAgent = picked);
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
                        _destinationAgent?.agentCode == 'NX-ABJ-01'
                            ? Icons.electric_moped_rounded
                            : Icons.inbox_rounded,
                        size: 20,
                        color: const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _destinationAgent != null
                              ? '${_destinationAgent!.name} (${_destinationAgent!.agentCode})'
                              : 'Select destination agent...',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Product SKU Picker (from items held by source agent)
              Text(
                'Product SKU to Transfer *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (sourceAvailableSkus.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected source agent currently holds 0 units in custody.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    final picked = await NovaSearchablePickerModal.show<String>(
                      context,
                      title: 'Select Product SKU',
                      subtitle: 'Choose inventory item held by source agent',
                      titleIcon: Icons.inventory_2_rounded,
                      options: sourceAvailableSkus
                          .map((sku) => NovaPickerOption<String>(
                                value: sku,
                                title: sku,
                                subtitle: 'Current Custody: ${_sourceAgent?.heldStock[sku] ?? 0} units',
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
                        const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedSku ?? 'Select SKU...',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Quantity Balancer Preview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Source Agent Current Custody:',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        Text(
                          '$sourceCurrentQty units',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sourceCurrentQty > 0 ? const Color(0xFF3B82F6) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Destination Agent Current Custody:',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        Text(
                          '$destCurrentQty units',
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Units to Transfer *',
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
                              if (n > sourceCurrentQty) return 'Max $sourceCurrentQty';
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

              // Re-allocation Justification Reason
              Text(
                'Re-allocation Justification Reason *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'e.g. Stock transfer to NovaXpress Logistics fleet for high-velocity dispatch',
                  hintStyle: GoogleFonts.inter(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reason is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting || sourceAvailableSkus.isEmpty
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (!_formKey.currentState!.validate()) return;
                          if (_sourceAgent == null || _destinationAgent == null || _selectedSku == null) return;

                          final units = int.tryParse(_unitsController.text.trim()) ?? 0;
                          if (units <= 0 || units > sourceCurrentQty) return;

                          // Mandatory confirmation modal
                          final approved = await NovaCriticalActionConfirmationModal.show(
                            context: context,
                            title: 'Confirm Inter-Agent Stock Re-allocation',
                            actionName: 'Transfer Custody Between Agents',
                            promptMessage:
                                'You are about to transfer custody stock from one agent to another. This reallocates physical fulfillment capacity and updates ledger balances.',
                            operatorAccount: operatorName,
                            valuesets: {
                              'Source Agent': '${_sourceAgent!.name} (${_sourceAgent!.agentCode})',
                              'Destination Agent': '${_destinationAgent!.name} (${_destinationAgent!.agentCode})',
                              'Product SKU': _selectedSku!,
                              'Units Transferred': '$units units',
                              'Source Balance After': '${sourceCurrentQty - units} units',
                              'Destination Balance After': '${destCurrentQty + units} units',
                              'Reason': _reasonController.text.trim(),
                              'Authorized By': operatorName,
                            },
                            confirmLabel: 'Confirm & Transfer Stock',
                            brandColor: const Color(0xFF3B82F6),
                          );

                          if (approved != true || !mounted) return;

                          setState(() => _isSubmitting = true);
                          try {
                            final ok = await notifier.reallocateStockBetweenAgents(
                              sourceAgentId: _sourceAgent!.id,
                              destinationAgentId: _destinationAgent!.id,
                              sku: _selectedSku!,
                              units: units,
                              operatorName: operatorName,
                              reason: _reasonController.text.trim(),
                            );

                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              if (ok) {
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    content: Text(
                                      'Successfully transferred $units units of $_selectedSku from ${_sourceAgent!.name} to ${_destinationAgent!.name}!',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFFDC2626),
                                    content: Text('Re-allocation failed. Please verify quantities.'),
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
                    backgroundColor: const Color(0xFF3B82F6),
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
                      : const Icon(Icons.swap_horiz_rounded),
                  label: Text(
                    _isSubmitting ? 'Transferring Custody...' : 'Re-allocate Stock Between Agents',
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
