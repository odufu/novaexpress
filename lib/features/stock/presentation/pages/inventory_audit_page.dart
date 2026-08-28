import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/stock_provider.dart';

class InventoryAuditPhysicalCountsNotifier extends StateNotifier<Map<String, int>> {
  InventoryAuditPhysicalCountsNotifier() : super({});

  void initialize(Map<String, int> counts) {
    if (state.isEmpty) {
      state = counts;
    }
  }

  void increment(String itemId) {
    final current = state[itemId] ?? 0;
    state = {...state, itemId: current + 1};
  }

  void decrement(String itemId) {
    final current = state[itemId] ?? 0;
    if (current > 0) {
      state = {...state, itemId: current - 1};
    }
  }
}

final inventoryAuditPhysicalCountsProvider = StateNotifierProvider.autoDispose<
    InventoryAuditPhysicalCountsNotifier, Map<String, int>>((ref) {
  return InventoryAuditPhysicalCountsNotifier();
});

class InventoryAuditVarianceReasonsNotifier extends StateNotifier<Map<String, String>> {
  InventoryAuditVarianceReasonsNotifier() : super({});

  void initialize(Map<String, String> reasons) {
    if (state.isEmpty) {
      state = reasons;
    }
  }

  void setReason(String itemId, String reason) {
    state = {...state, itemId: reason};
  }
}

final inventoryAuditVarianceReasonsProvider = StateNotifierProvider.autoDispose<
    InventoryAuditVarianceReasonsNotifier, Map<String, String>>((ref) {
  return InventoryAuditVarianceReasonsNotifier();
});

class InventoryAuditPage extends ConsumerStatefulWidget {
  const InventoryAuditPage({super.key});

  @override
  ConsumerState<InventoryAuditPage> createState() => _InventoryAuditPageState();
}

class _InventoryAuditPageState extends ConsumerState<InventoryAuditPage> {
  late Map<String, TextEditingController> _notesControllers;

  static const List<String> _reasonOptions = [
    'Damaged in Transit',
    'Missing Item',
    'Delivery not recorded',
    'Return not recorded',
    'Incorrect DC handover',
    'System error',
    'Other (Reason required)',
  ];

  @override
  void initState() {
    super.initState();
    final stockItems = ref.read(stockProvider).stockItems;
    _notesControllers = {for (var item in stockItems) item.id: TextEditingController()};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final items = ref.read(stockProvider).stockItems;
      ref.read(inventoryAuditPhysicalCountsProvider.notifier).initialize({
        for (var item in items) item.id: item.availableCount,
      });
      ref.read(inventoryAuditVarianceReasonsProvider.notifier).initialize({
        for (var item in items) item.id: 'Damaged in Transit',
      });
    });
  }

  @override
  void dispose() {
    for (var controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final physicalCounts = ref.watch(inventoryAuditPhysicalCountsProvider);
    final varianceReasons = ref.watch(inventoryAuditVarianceReasonsProvider);

    int totalSKUs = stockState.stockItems.length;
    int reconciledCount = 0;
    int varianceCount = 0;

    for (var item in stockState.stockItems) {
      final physical = physicalCounts[item.id] ?? item.availableCount;
      if (physical == item.availableCount) {
        reconciledCount++;
      } else {
        varianceCount++;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Stock Reconciliation',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audit Header Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'PHYSICAL STOCK AUDIT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'VEHICLE CUSTODY AUDIT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00A2D3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Reconcile physical stock in vehicle custody with system records.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric(
                          label: 'Total SKUs',
                          value: '$totalSKUs',
                          color: const Color(0xFF2563EB),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeaderMetric(
                          label: 'Reconciled',
                          value: '$reconciledCount',
                          color: const Color(0xFF16A34A),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeaderMetric(
                          label: 'Variances',
                          value: '$varianceCount',
                          color: varianceCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SKUs Audit List
            Text(
              'Count Active Custody SKUs',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ...stockState.stockItems.map((item) {
              final physical = physicalCounts[item.id] ?? item.availableCount;
              final isMatch = physical == item.availableCount;
              final variance = physical - item.availableCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMatch
                          ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A2D3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF00A2D3), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'System Expected: ${item.availableCount} units • SKU: ${item.sku}',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMatch ? 'MATCH ✓' : 'VARIANCE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMatch ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Physical Count Stepper
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Physical Count:',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE11D48)),
                                onPressed: () {
                                  ref.read(inventoryAuditPhysicalCountsProvider.notifier).decrement(item.id);
                                },
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 32),
                                alignment: Alignment.center,
                                child: Text(
                                  '$physical',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                                onPressed: () {
                                  ref.read(inventoryAuditPhysicalCountsProvider.notifier).increment(item.id);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Discrepancy & Reason Section
                      if (!isMatch) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE11D48)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Variance: ${variance > 0 ? "+$variance" : "$variance"} units (Physical: $physical vs System: ${item.availableCount})',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: varianceReasons[item.id] ?? _reasonOptions.first,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  labelText: 'Mandatory Variance Reason',
                                  labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFE11D48)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFFECDD3)),
                                  ),
                                ),
                                items: _reasonOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(inventoryAuditVarianceReasonsProvider.notifier).setReason(item.id, val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Submit Audit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final user = ref.read(authProvider).user;
                  final agentId = user?.deliveryAgentId ?? user?.id ?? '';
                  final physical = ref.read(inventoryAuditPhysicalCountsProvider);
                  final reasons = ref.read(inventoryAuditVarianceReasonsProvider);

                  ref.read(stockProvider.notifier).submitRiderStockAudit(
                        riderId: agentId,
                        physicalCounts: physical,
                        varianceReasons: reasons,
                      );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Stock Reconciliation Completed & Synced with DC Operations!',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );

                  if (context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Submit Stock Reconciliation',
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

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
