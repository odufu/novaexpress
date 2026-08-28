import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/stock_provider.dart';

final processReturnsSelectedDCProvider = StateProvider.autoDispose<String>((ref) => 'Wuse Distribution Center');

class ProcessReturnsSelectedQuantitiesNotifier extends StateNotifier<Map<String, int>> {
  ProcessReturnsSelectedQuantitiesNotifier() : super({});

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      final newState = Map<String, int>.from(state)..remove(productId);
      state = newState;
    } else {
      state = {...state, productId: qty};
    }
  }

  void toggle(String productId, int maxQty) {
    if (state.containsKey(productId)) {
      final newState = Map<String, int>.from(state)..remove(productId);
      state = newState;
    } else {
      state = {...state, productId: 1};
    }
  }

  void clear() {
    state = {};
  }
}

final processReturnsSelectedQuantitiesProvider = StateNotifierProvider.autoDispose<
    ProcessReturnsSelectedQuantitiesNotifier, Map<String, int>>((ref) {
  return ProcessReturnsSelectedQuantitiesNotifier();
});

final processReturnsReasonProvider = StateProvider.autoDispose<String>((ref) => 'End of Day Unsold Hub Drop-off');
final processReturnsIsSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ProcessReturnsPage extends ConsumerStatefulWidget {
  const ProcessReturnsPage({super.key});

  @override
  ConsumerState<ProcessReturnsPage> createState() => _ProcessReturnsPageState();
}

class _ProcessReturnsPageState extends ConsumerState<ProcessReturnsPage> {
  final TextEditingController _notesController = TextEditingController();

  final List<String> _reasons = [
    'End of Day Unsold Hub Drop-off',
    'Customer Refusal / Cancelled Delivery',
    'Damaged / Leaking in Transit',
    'Expired / Stale Stock',
    'DC Recall / Excess Stock Rebalancing',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final stockState = ref.watch(stockProvider);
    final selectedDC = ref.watch(processReturnsSelectedDCProvider);
    final selectedQuantities = ref.watch(processReturnsSelectedQuantitiesProvider);
    final selectedReason = ref.watch(processReturnsReasonProvider);
    final isSubmitting = ref.watch(processReturnsIsSubmittingProvider);

    final user = authState.user;
    final agentId = user?.deliveryAgentId ?? user?.id ?? '';
    final agentName = user != null && user.firstName.isNotEmpty ? '${user.firstName} ${user.lastName}' : 'Rider';

    final availableItems = stockState.stockItems.where((i) => i.availableCount > 0).toList();

    final totalReturnUnits = selectedQuantities.values.fold(0, (sum, q) => sum + q);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Process DC Returns',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rider: $agentName',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Return Destination Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Return Destination Hub',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedDC,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.warehouse_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Wuse Distribution Center', child: Text('Wuse Distribution Center')),
                      DropdownMenuItem(value: 'Garki Distribution Center', child: Text('Garki Distribution Center')),
                      DropdownMenuItem(value: 'Kubwa Distribution Center', child: Text('Kubwa Distribution Center')),
                      DropdownMenuItem(value: 'Ikeja Distribution Center', child: Text('Ikeja Distribution Center')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(processReturnsSelectedDCProvider.notifier).state = val;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Return Reason Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primary Reason for Return',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.assignment_return_rounded, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _reasons.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(processReturnsReasonProvider.notifier).state = val;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Optional notes (e.g. Received by DC Hub Supervisor)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Return Items List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vehicle Stock on Hand (${availableItems.length})',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${stockState.stockItems.fold(0, (acc, item) => acc + item.availableCount)} units total',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (availableItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      'No Physical Stock on Vehicle',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You do not have any units in vehicle custody to return.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ...availableItems.map((item) {
                final qty = selectedQuantities[item.id] ?? 0;
                final isSelected = qty > 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFEA580C) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFFEA580C),
                      onChanged: (val) {
                        ref
                            .read(processReturnsSelectedQuantitiesProvider.notifier)
                            .toggle(item.id, item.availableCount);
                      },
                    ),
                    title: Text(
                      item.name,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'SKU: ${item.sku.isNotEmpty ? item.sku : "N/A"} • ₦${item.price.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              ref
                                  .read(processReturnsSelectedQuantitiesProvider.notifier)
                                  .setQty(item.id, qty - 1);
                            },
                          ),
                          Text(
                            '$qty',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: qty < item.availableCount
                                ? () {
                                    ref
                                        .read(processReturnsSelectedQuantitiesProvider.notifier)
                                        .setQty(item.id, qty + 1);
                                  }
                                : null,
                          ),
                        ] else
                          Text(
                            '${item.availableCount} available',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // Submit Return Handover
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (totalReturnUnits <= 0 || isSubmitting)
                    ? null
                    : () async {
                        ref.read(processReturnsIsSubmittingProvider.notifier).state = true;
                        final notifier = ref.read(stockProvider.notifier);

                        for (final entry in selectedQuantities.entries) {
                          await notifier.returnStockToDC(
                            productIdOrSku: entry.key,
                            riderId: agentId,
                            quantity: entry.value,
                            reason: selectedReason,
                            notes: _notesController.text.trim(),
                          );
                        }

                        if (context.mounted) {
                          ref.read(processReturnsIsSubmittingProvider.notifier).state = false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Successfully returned $totalReturnUnits units to $selectedDC.',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                          context.pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isSubmitting
                      ? 'Submitting Return...'
                      : 'Confirm Return to $selectedDC ($totalReturnUnits Units)',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
